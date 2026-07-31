# SmartQueue Domain Model

## 1. Purpose

Tài liệu này chuyển các requirement và use case của SmartQueue
thành một mô hình nghiệp vụ thống nhất.

Domain model là cơ sở cho:

- Thiết kế database.
- Thiết kế REST API.
- Thiết kế Java entity và service.
- State transition.
- Transaction boundary.
- Integration test.

## 2. Ubiquitous language

| Term | Meaning |
|---|---|
| User | Tài khoản có thể xác thực và được gán role |
| Patient | User có role PATIENT |
| Doctor | User có DoctorProfile và role DOCTOR |
| DoctorSchedule | Khoảng làm việc lặp lại của Doctor |
| DoctorTimeOff | Khoảng Doctor nghỉ hoặc không nhận lịch |
| Appointment | Lịch hẹn giữa Patient và Doctor |
| QueueTicket | Vị trí của Appointment trong hàng đợi |
| Check-in | Xác nhận Patient đã đến phòng khám |
| Call next | Chọn WAITING ticket có queue number nhỏ nhất |
| AuditLog | Bản ghi một hành động quan trọng |

## 3. Entities

### 3.1 User

Identity:

- id

Attributes:

- email
- passwordHash
- fullName
- phone
- role
- status
- createdAt
- updatedAt

Rules:

- Email phải duy nhất.
- Password không được lưu ở dạng plain text.
- User bị LOCKED hoặc DISABLED không được đăng nhập.

### 3.2 DoctorProfile

Identity:

- id

Attributes:

- userId
- specialty
- active
- createdAt
- updatedAt

Rules:

- Mỗi User có tối đa một DoctorProfile.
- DoctorProfile chỉ thuộc User có role DOCTOR.

### 3.3 DoctorSchedule

Identity:

- id

Attributes:

- doctorId
- dayOfWeek
- startTime
- endTime
- slotDurationMinutes
- active

Rules:

- startTime phải trước endTime.
- slotDurationMinutes phải lớn hơn 0.
- Schedule đang hoạt động của cùng Doctor không được chồng nhau.

### 3.4 DoctorTimeOff

Identity:

- id

Attributes:

- doctorId
- startAt
- endAt
- reason

Rules:

- startAt phải trước endAt.
- Không được sinh slot trong khoảng DoctorTimeOff.

### 3.5 Appointment

Identity:

- id

Attributes:

- patientId
- doctorId
- startAt
- endAt
- status
- createdAt
- updatedAt
- cancelledAt

States:

- BOOKED
- CHECKED_IN
- IN_SERVICE
- COMPLETED
- CANCELLED

Rules:

- Patient phải có role PATIENT.
- Doctor phải đang hoạt động.
- startAt phải trước endAt.
- Appointment phải thuộc DoctorSchedule.
- Appointment không được nằm trong DoctorTimeOff.
- Doctor không được có appointment còn hiệu lực trùng thời gian.
- Patient không được có appointment còn hiệu lực trùng thời gian.
- Chỉ appointment BOOKED mới được reschedule.
- Chỉ appointment BOOKED mới được check-in.

### 3.6 QueueTicket

Identity:

- id

Attributes:

- appointmentId
- doctorId
- queueDate
- queueNumber
- status
- checkedInAt
- calledAt
- completedAt

States:

- WAITING
- CALLED
- COMPLETED

Rules:

- Mỗi Appointment có tối đa một QueueTicket.
- queueNumber phải lớn hơn 0.
- queueNumber phải duy nhất theo Doctor và queueDate.
- QueueTicket mới phải có trạng thái WAITING.
- Chỉ QueueTicket WAITING mới được gọi.
- Ticket được gọi tiếp theo phải có queueNumber nhỏ nhất.

### 3.7 AuditLog

Identity:

- id

Attributes:

- actorUserId
- action
- entityType
- entityId
- occurredAt
- details

Rules:

- AuditLog đã tạo không được chỉnh sửa.
- Các thao tác quan trọng phải tạo AuditLog.

## 4. Relationships

- Một User có thể có tối đa một DoctorProfile.
- Một DoctorProfile có thể có nhiều DoctorSchedule.
- Một DoctorProfile có thể có nhiều DoctorTimeOff.
- Một Patient User có thể có nhiều Appointment.
- Một DoctorProfile có thể có nhiều Appointment.
- Một Appointment có thể có tối đa một QueueTicket.
- Một DoctorProfile có thể có nhiều QueueTicket.
- Một User có thể tạo nhiều AuditLog.

## 5. Core invariants

### INV-01 Unique user email

Hai User không được có cùng email chuẩn hóa.

### INV-02 No doctor appointment overlap

Một Doctor không được có hai appointment còn hiệu lực
chồng lấn thời gian.

### INV-03 No patient appointment overlap

Một Patient không được có hai appointment còn hiệu lực
chồng lấn thời gian.

### INV-04 Valid doctor availability

Appointment phải nằm trong DoctorSchedule và không nằm
trong DoctorTimeOff.

### INV-05 One queue ticket per appointment

Một Appointment có tối đa một QueueTicket.

### INV-06 Unique queue number

queueNumber phải duy nhất theo Doctor và queueDate.

### INV-07 Valid state transition

Entity chỉ được chuyển trạng thái theo state machine đã định nghĩa.

### INV-08 Earliest waiting ticket

Call-next phải chọn WAITING ticket có queueNumber nhỏ nhất.

## 6. Transaction boundaries

### Book appointment

Các bước kiểm tra slot, tạo Appointment và ghi AuditLog
phải được xử lý trong một transaction nghiệp vụ.

### Reschedule appointment

Kiểm tra slot mới và cập nhật Appointment phải nguyên tử.

Nếu slot mới không hợp lệ, slot cũ phải được giữ nguyên.

### Check in

Cập nhật Appointment sang CHECKED_IN và tạo QueueTicket WAITING
phải nằm trong cùng một transaction.

### Call next patient

Chọn QueueTicket tiếp theo, đổi nó sang CALLED và đổi Appointment
sang IN_SERVICE phải nằm trong cùng một transaction.

### Complete queue ticket

Đổi QueueTicket sang COMPLETED và Appointment sang COMPLETED
phải nằm trong cùng một transaction.

## 7. Concurrency-sensitive operations

Các thao tác cần xử lý concurrent access:

- Book appointment.
- Reschedule appointment.
- Check in.
- Generate queue number.
- Call next patient.

Database constraints và transaction vẫn phải bảo vệ invariant
ngay cả khi hai request chạy đồng thời.

## 8. Requirement mapping

| Requirement | Domain concept | Rule |
|---|---|---|
| FR-03 | DoctorSchedule, DoctorTimeOff, Appointment | Chỉ trả slot hợp lệ |
| FR-04 | Appointment | Không đặt trùng slot |
| FR-05 | Appointment | Chỉ trạng thái hợp lệ được cancel |
| FR-06 | Appointment | Reschedule phải nguyên tử |
| FR-07 | Appointment, QueueTicket | Check-in tạo đúng một ticket |
| FR-08 | QueueTicket | Chọn WAITING ticket nhỏ nhất |
| FR-09 | Appointment, QueueTicket | Hai entity hoàn tất cùng nhau |
| FR-10 | AuditLog | Ghi lại thao tác quan trọng |
| NFR-02 | Appointment, QueueTicket | Database bảo vệ invariant |
| NFR-03 | Transaction boundary | Không lưu trạng thái một phần |

## 9. Non-goals

Domain model hiện tại không bao gồm:

- Medical record.
- Diagnosis.
- Prescription.
- Payment.
- Insurance.
- Pharmacy inventory.