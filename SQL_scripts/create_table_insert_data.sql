CREATE TABLE base_charge (
    route_type VARCHAR(50),       -- 'Noi Tinh', 'Noi Vung', 'Noi Vung Tinh', 'Lien Vung Dac Biet', 'Lien Vung', 'Lien Tinh'
    is_special_city INT,          -- 1: Hà Nội & TP.HCM, 0: Các tỉnh khác
    base_weight DECIMAL(5,2),     -- Khối lượng nấc gốc (3.00 kg hoặc 0.50 kg)
    urban_rate DECIMAL(10,2),     -- Giá nội thành
    suburban_rate DECIMAL(10,2),  -- Giá ngoại thành
    next_05kg_rate DECIMAL(10,2)  -- Giá cộng thêm cho mỗi 0.5kg tiếp theo
);

INSERT INTO base_charge VALUES 
('Noi Tinh',           0, 3.00, 15500, 29000, 2500), -- Nội tỉnh thường
('Noi Tinh',           1, 3.00, 21000, 29000, 2500), -- Nội tỉnh (HN & HCM)
('Noi Vung',           0, 0.50, 29000, 34000, 2500),
('Noi Vung Tinh',      0, 0.50, 29000, 34000, 2500),
('Lien Vung Dac Biet', 0, 0.50, 29000, 39000, 5000),
('Lien Vung',          0, 0.50, 29000, 39000, 5000),
('Lien Tinh',          0, 0.50, 29000, 36000, 5000);

SELECT *
FROM base_charge;


CREATE TABLE Surcharges_config (
    surcharge_id INT PRIMARY KEY,
    category_name VARCHAR(100),     -- Danh mục (Chuyển tiền COD, Phụ phí xăng dầu, Hoàn trả...)
    fee_type_name VARCHAR(100),     -- Tên loại phí (Phí chuyển tiền COD, Phí bảo hiểm...)
    route_scope VARCHAR(50),        -- Phạm vi tuyến ('Noi Tinh', 'Tuyen Khac', 'All')
    min_condition_value DECIMAL(15,2), -- Điều kiện giá trị tối thiểu (Ví dụ: 1000000)
    max_condition_value DECIMAL(15,2), -- Điều kiện giá trị tối đa
    fix_amount DECIMAL(10,2),       -- Mức phí cố định (VND)
    percentage_rate DECIMAL(5,2),   -- Mức phí tính theo tỷ lệ phần trăm (%)
    effective_date DATE             -- Ngày bắt đầu áp dụng hiệu lực
);

INSERT INTO Surcharges_config (
    surcharge_id, category_name, fee_type_name, route_scope, 
    min_condition_value, max_condition_value, fix_amount, percentage_rate, effective_date
) VALUES 
-- 1. Danh mục Chuyển tiền COD
(1, 'Chuyen tien COD', 'Phi chuyen tien COD', 'All', 0, NULL, 5500.00, 0.00, '2021-08-01'),

-- 2. Danh mục Phụ phí xăng dầu (Áp dụng từ 20/03/2026)
(3, 'Phu Phi Xang Dau', 'Phu phi xang dau', 'All', 0, NULL, 0.00, 10.00, '2026-03-20'),

-- 3. Danh mục Hoàn Trả Hàng
(4, 'Hoan Tra Hang', 'Hoan tra hang noi tinh', 'Noi Tinh', 0, NULL, 5000.00, 0.00, '2025-07-01'),
(5, 'Hoan Tra Hang', 'Hoan tra cac tuyen khac', 'Tuyen Khac', 0, NULL, 0.00, 50.00, '2025-07-01'),

-- 4. Danh mục Khai báo giá trị (Phí bảo hiểm)
(6, 'Khai bao gia tri', 'Phi bao hiem hang hoa', 'All', 0, 1000000.00, 0.00, 0.00, '2025-07-01'),
(7, 'Khai bao gia tri', 'Phi bao hiem hang hoa', 'All', 1000000.01, NULL, 0.00, 0.50, '2025-07-01');
  INSERT INTO Surcharges_config (
    surcharge_id, category_name, fee_type_name, route_scope, 
    min_condition_value, max_condition_value, fix_amount, percentage_rate, effective_date
) VALUES 
-- Phụ phí thay đổi địa chỉ (Cùng Tỉnh: Khác Phường/Huyện = 11.000đ | Liên tỉnh = 100% cước)
(8, 'Thay doi dia chi', 'Noi tinh khac phuong huyen', 'Noi Tinh', 0, NULL, 11000.00, 0.00, '2025-07-01'),
(9, 'Thay doi dia chi', 'Tuyen lien tinh', 'Lien Tinh', 0, NULL, 0.00, 100.00, '2025-07-01'),

-- Phụ phí giao lại hàng (Từ lần thứ 4 trở đi = 11.000đ/lần)
(10, 'Giao lai hang', 'Giao lai tu lan thu 4', 'All', 4, NULL, 11000.00, 0.00, '2025-07-01');

  select *
  from Surcharges_config;
  
  CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,      -- Mã đơn hàng độc nhất
    customer_id VARCHAR(50) NOT NULL,      -- Mã khách hàng/đối tác ký hợp đồng
    order_date DATE NOT NULL,              -- Ngày tạo đơn hàng (để dò giá xăng dầu theo tuần/tháng)
    channel_type VARCHAR(50),              -- Kênh bán: 'Shopee', 'Lazada', 'Khach Ngoai' (để tính phí COD)
    order_status VARCHAR(50),              -- Trạng thái đơn hàng: 'Delivered' (Thành công), 'Returned' (Chuyển hoàn)
    
    -- Thông số hàng hóa để tính khối lượng quy đổi chuẩn GHN (Dài x Rộng x Cao / 5000)
    actual_weight DECIMAL(10,2),           -- Khối lượng cân thực tế (kg)
    length DECIMAL(10,2),                  -- Chiều dài (cm)
    width DECIMAL(10,2),                   -- Chiều rộng (cm)
    height DECIMAL(10,2),                  -- Chiều cao (cm)
    declared_value DECIMAL(15,2),          -- Giá trị khai báo hàng hóa (để tính phí bảo hiểm)
    
    -- Thông tin tuyến đường phục vụ tra cứu bảng giá gốc
    route_type VARCHAR(50),                -- Tuyến: 'Noi Tinh', 'Noi Vung', 'Lien Tinh'...
    zone_type VARCHAR(20),                 -- Vùng: 'urban' (Nội thành) hoặc 'suburban' (Ngoại thành)
    is_special_city INT,                   -- 1: Hà Nội/TP.HCM (Tuyến Nội tỉnh giá cao), 0: Tỉnh khác
    
    -- Thông tin biến động nghiệp vụ (2 phụ phí vừa bổ sung theo ảnh)
    actual_delivery_attempts INT DEFAULT 1,-- Tổng số lần bưu tá đi giao thực tế (để tính phí từ lần 4)
    address_change_type VARCHAR(50),       -- Trạng thái đổi địa chỉ: 'NONE', 'DIFF_COMMUNE' (Khác phường/huyện), 'CROSS_PROVINCE' (Liên tỉnh)
    is_partially_returned INT DEFAULT 0,   -- 1: Có giao 1 phần - trả 1 phần, 0: Giao toàn bộ
    
    -- DỮ LIỆU TÀI CHÍNH THỰC TẾ Hệ thống eForm ghi nhận (Đối tượng cần đối soát)
    actual_base_rate DECIMAL(10,2),        -- Cước gốc thực tế đang tính
    actual_fuel_fee DECIMAL(10,2),         -- Phụ phí xăng dầu thực tế đang tính
    actual_cod_fee DECIMAL(10,2),          -- Phí thu hộ COD thực tế đang tính
    actual_insurance_fee DECIMAL(10,2),    -- Phí bảo hiểm thực tế đang tính
    actual_return_fee DECIMAL(10,2),       -- Phí chuyển hoàn thực tế đang tính
    actual_extra_fee DECIMAL(10,2),        -- Phụ phí dịch vụ cộng thêm thực tế đang tính (Giao lại, Đổi địa chỉ...)
    actual_total_amount DECIMAL(10,2)      -- Tổng số tiền hệ thống eForm đã chốt thu của khách
);
INSERT INTO orders VALUES 
-- ĐƠN 1: Bị tính SAI cước gốc do cồng kềnh (Hệ thống quên không tính khối lượng quy đổi thể tích)
-- Thể tích: 50x40x30/5000 = 12kg > Cân nặng 2kg. Đáng lẽ phải tính cước nấc 12kg nhưng eForm vẫn tính nấc 2kg.
('ORD001', 'KH_VIP_01', '2026-03-25', 'Khach Ngoai', 'Delivered', 
 2.00, 50.00, 40.00, 30.00, 500000.00, 
 'Noi Tinh', 'urban', 1, 
 1, 'NONE', 0, 
 21000.00, 2100.00, 5500.00, 0.00, 0.00, 0.00, 28600.00),

-- ĐƠN 2: Thất thoát PHÍ GIAO LẠI (Giao tới 4 lần nhưng bưu cục không thu thêm 11.000đ theo ảnh)
('ORD002', 'KH_SHOP_ONLINE', '2026-03-26', 'Khach Ngoai', 'Delivered', 
 1.50, 10.00, 10.00, 10.00, 200000.00, 
 'Noi Tinh', 'suburban', 0, 
 4, 'NONE', 0, -- Giao 4 lần
 29000.00, 2900.00, 5500.00, 0.00, 0.00, 0.00, 37400.00), -- actual_extra_fee đang bằng 0 -> LỖI

-- ĐƠN 3: Thất thoát PHÍ ĐỔI ĐỊA CHỈ LIÊN TỈNH (Đổi tỉnh nhưng không tính phụ phí bằng 100% cước tuyến mới)
('ORD003', 'KH_LE', '2026-03-27', 'Khach Ngoai', 'Delivered', 
 0.40, 10.00, 10.00, 10.00, 1500000.00, 
 'Lien Tinh', 'urban', 0, 
 1, 'CROSS_PROVINCE', 0, -- Đổi địa chỉ liên tỉnh
 29000.00, 2900.00, 5500.00, 7500.00, 0.00, 0.00, 44900.00); -- actual_extra_fee bằng 0 -> LỖI

   select *
  from orders;
  
  