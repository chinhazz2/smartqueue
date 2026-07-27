# SmartQueue Project Charter

## 1. Product vision

SmartQueue là hệ thống web giúp phòng khám nhỏ quản lý lịch hẹn
và hàng đợi của bệnh nhân trên một nền tảng thống nhất.

## 2. Vấn đề cần giải quyết

Phòng khám đang quản lý lịch bằng điện thoại, giấy hoặc bảng tính.
Điều này dễ gây trùng lịch, khó theo dõi bệnh nhân đã đến và không
xác định rõ người tiếp theo trong hàng đợi.

## 3. Stakeholders

- Bệnh nhân
- Lễ tân
- Bác sĩ
- Quản trị viên phòng khám
- Nhóm phát triển và vận hành hệ thống

## 4. MVP

- Đăng ký và đăng nhập
- Phân quyền người dùng
- Quản lý bác sĩ và lịch làm việc
- Xem slot trống
- Đặt, hủy và đổi lịch
- Check-in
- Cấp số thứ tự
- Gọi lượt tiếp theo
- Hoàn tất hoặc bỏ lượt
- Audit log
- API documentation
- Automated tests
- Docker và CI

## 5. Ngoài phạm vi

- Hồ sơ bệnh án
- Chẩn đoán
- Kê đơn
- Thanh toán
- Bảo hiểm
- Video call
- Nhiều chi nhánh
- Email/SMS thật
- Microservices

## 6. Tiêu chí thành công

- Không thể có hai lịch còn hiệu lực cho cùng bác sĩ và cùng slot.
- Một bệnh nhân có thể hoàn thành luồng đặt lịch.
- Lễ tân có thể check-in bệnh nhân.
- Bác sĩ có thể gọi và hoàn tất lượt.
- Hệ thống chạy được từ repository mới bằng hướng dẫn trong README.
- Các test quan trọng chạy thành công.

## 7. Rủi ro

| Rủi ro | Ảnh hưởng | Biện pháp |
|---|---|---|
| Phạm vi quá lớn | Không hoàn thành MVP | Giữ danh sách ngoài phạm vi |
| Lỗi môi trường | Mất thời gian setup | Cố định phiên bản và dùng Docker |
| Thiếu thời gian frontend | Demo không hoàn chỉnh | Ưu tiên luồng chính |
| Lỗi đặt trùng slot | Sai dữ liệu | DB unique constraint và transaction |
| Thêm công nghệ không cần thiết | Tăng độ phức tạp | Không thêm nếu không giải quyết yêu cầu cụ thể |