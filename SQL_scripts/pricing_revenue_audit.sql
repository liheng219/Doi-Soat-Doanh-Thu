WITH master_surcharges_window AS (
    -- Đảm bảo chỉ ra đúng 1 dòng cấu hình phụ phí
    SELECT 
        MAX(CASE WHEN fee_type_name = 'Phi chuyen tien COD' THEN fix_amount END) AS cod_fix_amount,
        MAX(CASE WHEN fee_type_name = 'Phu phi xang dau' THEN percentage_rate END) AS fuel_pct,
        MAX(CASE WHEN fee_type_name = 'Hoan tra hang noi tinh' THEN fix_amount END) AS return_intra_fix,
        MAX(CASE WHEN fee_type_name = 'Hoan tra cac tuyen khac' THEN percentage_rate END) AS return_inter_pct,
        MAX(CASE WHEN fee_type_name = 'Phi bao hiem hang hoa' AND min_condition_value >= 1000000.01 THEN percentage_rate END) AS insurance_high_pct,
        MAX(CASE WHEN fee_type_name = 'Noi tinh khac phuong huyen' THEN fix_amount END) AS addr_change_intra_fix,
        MAX(CASE WHEN fee_type_name = 'Tuyen lien tinh' THEN percentage_rate END) AS addr_change_inter_pct,
        MAX(CASE WHEN fee_type_name = 'Giao lai tu lan thu 4' THEN fix_amount END) AS redelivery_fix
    FROM Surcharges_config
    WHERE CURRENT_DATE >= effective_date
),
order_with_all_params AS (
    -- Gắn ma trận phụ phí vào từng đơn hàng và tạo biến thể tích vol_weight
    SELECT 
        o.order_id, o.customer_id, o.route_type, o.channel_type, o.order_status, o.declared_value,
        o.length, o.width, o.height, o.actual_weight, o.zone_type, o.is_special_city,
        o.actual_delivery_attempts,
        o.address_change_type,
        m.*,
        o.actual_base_rate, o.actual_fuel_fee, o.actual_return_fee, 
        o.actual_insurance_fee, o.actual_cod_fee, o.actual_extra_fee, o.actual_total_amount,
        (o.length * o.width * o.height / 5000.0) AS vol_weight
    FROM orders o
    CROSS JOIN master_surcharges_window m
),
final_billable_weight AS (
    -- Tính toán trọng lượng tính cước đúng 1 lần duy nhất
    SELECT 
        *,
        CEIL(CASE WHEN actual_weight >= vol_weight 
				  THEN actual_weight ELSE vol_weight END * 2) / 2.0 AS std_billable_weight,
        CEIL(CASE WHEN actual_weight >= vol_weight 
				  THEN actual_weight ELSE vol_weight END * 2) AS doubled_ceil_weight
    FROM order_with_all_params
),
unique_base_charge AS (
    -- Thu gọn bảng giá cước gốc, chỉ lấy 1 dòng duy nhất cho mỗi cặp tuyến đường 
    SELECT 
        route_type, 
        is_special_city,
        MAX(urban_rate) AS urban_rate,
        MAX(suburban_rate) AS suburban_rate,
        MAX(base_weight) AS base_weight,
        MAX(next_05kg_rate) AS next_05kg_rate
    FROM base_charge
    GROUP BY route_type, is_special_city
),
weight_and_base_rate AS (
    -- Thực hiện JOIN với bảng giá cước đã được làm sạch
    SELECT 
        w.*,
        CASE WHEN w.zone_type = 'urban' THEN c.urban_rate ELSE c.suburban_rate END + 
        CASE 
            WHEN w.std_billable_weight > c.base_weight 
			THEN (w.doubled_ceil_weight - (c.base_weight * 2)) * c.next_05kg_rate
            ELSE 0
        END AS std_base_rate
    FROM final_billable_weight w
    INNER JOIN unique_base_charge c 
        ON w.route_type = c.route_type AND w.is_special_city = c.is_special_city
),
final_calculated_sheet AS (
    SELECT 
        *,
        ROUND(std_base_rate * (fuel_pct / 100.0), 0) AS std_fuel_fee,
        CASE WHEN channel_type IN ('Shopee', 'Lazada', 'Tiki', 'Sendo') THEN 0 
			 ELSE cod_fix_amount END AS std_cod_fee,
        CASE WHEN declared_value <= 1000000 THEN 0 
			 ELSE ROUND(declared_value * (insurance_high_pct / 100.0), 0) END AS std_insurance_fee,
        CASE WHEN order_status = 'Returned' AND route_type = 'Noi Tinh' 
			 THEN return_intra_fix 
             WHEN order_status = 'Returned' AND route_type <> 'Noi Tinh' 
             THEN ROUND(std_base_rate * (return_inter_pct / 100.0), 0) 
             ELSE 0 
		END AS std_return_fee,
        
        (
            CASE 
                WHEN actual_delivery_attempts >= 4 THEN (actual_delivery_attempts - 3) * redelivery_fix 
                ELSE 0 
            END +
            CASE 
                WHEN address_change_type = 'DIFF_COMMUNE' THEN addr_change_intra_fix
                WHEN address_change_type = 'CROSS_PROVINCE' THEN ROUND(std_base_rate * (addr_change_inter_pct / 100.0), 0)
                ELSE 0 
            END
        ) AS std_extra_fee
    FROM weight_and_base_rate
)
SELECT 
    order_id, route_type, order_status, actual_delivery_attempts, address_change_type,
    std_base_rate, actual_base_rate,
    std_extra_fee, actual_extra_fee,
    std_fuel_fee, actual_fuel_fee,
    std_insurance_fee, actual_insurance_fee,
    (std_base_rate + std_fuel_fee + std_cod_fee + std_insurance_fee + std_return_fee + std_extra_fee) AS total_std_amount,
    actual_total_amount,
    ((std_base_rate + std_fuel_fee + std_cod_fee + std_insurance_fee + std_return_fee + std_extra_fee) - actual_total_amount) AS leakage_amount,
    
    CASE 
        WHEN actual_delivery_attempts >= 4 AND actual_extra_fee = 0 THEN 'THIEU_PHI_GIAO_LAI_LAN_4'
        WHEN address_change_type IN ('DIFF_COMMUNE', 'CROSS_PROVINCE') AND actual_extra_fee = 0 THEN 'THIEU_PHI_THAY_DOI_DIA_CHI'
        WHEN actual_base_rate <> std_base_rate THEN 'SAI_CUOC_GOC_LUI_TIEN'
        WHEN actual_fuel_fee <> std_fuel_fee THEN 'SAI_PHI_XANG_DAU_10_PHAN_TRAM'
        WHEN actual_total_amount < (std_base_rate + std_fuel_fee + std_cod_fee + std_insurance_fee + std_return_fee + std_extra_fee) THEN 'REVENUE_LEAKAGE_CRITICAL'
        ELSE 'KHOP_DU_LIEU'
    END AS audit_flag

FROM final_calculated_sheet
WHERE actual_total_amount <> (std_base_rate + std_fuel_fee + std_cod_fee + std_insurance_fee + std_return_fee + std_extra_fee);


