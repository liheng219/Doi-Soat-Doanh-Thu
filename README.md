# Dự Án Phân Tích Dữ Liệu & Quản Lý Vận Hành Logistics

## Tổng Quan Dự Án
Dự án này áp dụng các kỹ thuật SQL nâng cao và phân tích dữ liệu để giải quyết các bài toán thực tế trong ngành Logistics và Chuỗi cung ứng (E-commerce Fulfillment). Các luồng công việc và mô hình phân tích tại đây được thiết kế nhằm tối ưu hóa vận hành, đối soát hệ thống giá.

---

## 🛠️ Công Cụ & Kỹ Năng Sử Dụng
* **Hệ quản trị & Truy vấn:** SQL (MySQL) - Ứng dụng thành thạo Advanced Joins, Window Functions, CTEs, Conditional Aggregation (CASE WHEN).
* **Công cụ hỗ trợ:** Microsoft Excel (Nâng cao), Định hình luồng vận hành hệ thống (Workflow/eForm Mapping).
* **Nghiệp vụ (Domain Knowledge):** Kiểm soát rủi ro vận hành, Đối soát doanh thu (Revenue Auditing). 

---
* **Bối cảnh:** Việc duy trì chính xác bảng giá, phụ phí và các điều khoản hợp đồng trên hệ thống là rất quan trọng. Sự sai lệch giữa bảng giá chuẩn và dữ liệu phê duyệt thực tế trên eForm dễ dẫn đến thất thoát doanh thu (revenue leakage).
* **Giải pháp SQL:** Xây dựng script đối soát tự động, đối chiếu số tiền đã tính trên đơn hàng thực tế với bảng giá gốc trong hợp đồng. Hệ thống tự động gắn cờ (flag) những đơn hàng bị tính sai phụ phí hoặc áp sai khung khối lượng.
* *🔗 [Liên kết đến mã nguồn SQL](./scripts/pricing_revenue_audit.sql)*
