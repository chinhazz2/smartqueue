# SmartQueue Requirements Specification

## 1. Purpose

SmartQueue là hệ thống web hỗ trợ phòng khám nhỏ quản lý lịch hẹn
và hàng đợi khám bệnh.

Tài liệu này mô tả actor, yêu cầu chức năng, yêu cầu phi chức năng,
use case, user story, acceptance criteria và khả năng truy vết yêu cầu.

## 2. Scope

### In scope

- Đăng ký và đăng nhập.
- Phân quyền Patient, Receptionist, Doctor và Administrator.
- Quản lý bác sĩ và lịch làm việc.
- Xem slot trống.
- Đặt, hủy và đổi lịch.
- Check-in và cấp số thứ tự.
- Gọi bệnh nhân tiếp theo.
- Hoàn tất lượt khám.
- Theo dõi trạng thái lịch hẹn.
- Ghi audit log.

### Out of scope

- Bệnh án điện tử.
- Chẩn đoán.
- Toa thuốc.
- Thanh toán.
- Bảo hiểm.
- Quản lý thuốc.
- Tư vấn y tế trực tuyến.

## 3. Actors

| Actor | Description |
|---|---|
| Patient | Xem lịch trống, đặt lịch, đổi lịch, hủy lịch và check-in |
| Receptionist | Hỗ trợ bệnh nhân đặt lịch, hủy, đổi và check-in |
| Doctor | Xem hàng đợi, gọi lượt tiếp theo và hoàn tất lượt |
| Administrator | Quản lý người dùng, bác sĩ, lịch làm việc và audit log |
| Notification Service | Nhận sự kiện và gửi thông báo trạng thái |

## 4. Functional requirements

### FR-01 Patient registration

Hệ thống phải cho phép bệnh nhân đăng ký bằng email duy nhất,
mật khẩu, họ tên và số điện thoại tùy chọn.

### FR-02 Authentication

Hệ thống phải cho phép người dùng đăng nhập bằng thông tin xác thực
hợp lệ và từ chối tài khoản không hợp lệ hoặc bị khóa.

### FR-03 Available slot lookup

Hệ thống phải cho phép Patient và Receptionist xem slot còn trống
của một bác sĩ trong một ngày xác định.

Hệ thống không được trả về slot:

- Thuộc quá khứ.
- Ngoài lịch làm việc.
- Nằm trong thời gian nghỉ.
- Đã có appointment còn hiệu lực.

### FR-04 Book appointment

Hệ thống phải cho phép Patient hoặc Receptionist đặt một slot hợp lệ.

Hệ thống phải bảo đảm chỉ một appointment còn hiệu lực được chiếm
một slot của bác sĩ.

### FR-05 Cancel appointment

Hệ thống phải cho phép người có quyền hủy appointment khi trạng thái
hiện tại cho phép hủy.

### FR-06 Reschedule appointment

Hệ thống phải cho phép đổi appointment sang một slot khác trong
một thao tác nguyên tử.

Nếu slot mới không hợp lệ, appointment cũ phải được giữ nguyên.

### FR-07 Check in

Hệ thống phải cho phép Patient hoặc Receptionist check-in một
appointment trong đúng ngày hẹn.

Check-in thành công phải:

- Chuyển appointment sang CHECKED_IN.
- Tạo một QueueTicket ở trạng thái WAITING.
- Cấp queue number hợp lệ cho bác sĩ trong ngày.

### FR-08 Call next patient

Hệ thống phải cho phép Doctor gọi QueueTicket WAITING có queue number
nhỏ nhất trong hàng đợi của mình.

Hai request đồng thời không được gọi cùng một QueueTicket.

### FR-09 Complete queue ticket

Hệ thống phải cho phép Doctor hoàn tất lượt đang phục vụ.

Kết quả:

- QueueTicket chuyển thành COMPLETED.
- Appointment chuyển thành COMPLETED.

### FR-10 Audit log

Hệ thống phải ghi lại actor, action, entity, thời điểm và thông tin
thay đổi đối với các thao tác quan trọng.

## 5. Non-functional requirements

### NFR-01 Security

- Mật khẩu phải được băm.
- Endpoint phải kiểm tra authentication và role.
- API không được trả password hash.
- Input phải được validate ở backend.

### NFR-02 Data integrity

Database phải ngăn hai appointment còn hiệu lực cùng chiếm một slot
của bác sĩ.

### NFR-03 Reliability

Đặt lịch, đổi lịch, check-in và gọi lượt phải được xử lý nguyên tử.

Khi thao tác thất bại, hệ thống không được lưu trạng thái một phần.

### NFR-04 Performance

Các API đọc thông thường phải phản hồi dưới khoảng 500 ms trong
môi trường demo, không tính độ trễ mạng bên ngoài.

### NFR-05 Traceability

Các thay đổi trạng thái quan trọng phải có audit log.

### NFR-06 Portability

PostgreSQL phải có thể chạy bằng Docker Compose.

### NFR-07 Maintainability

Controller không được chứa business rule phức tạp.

Business rule phải được đặt trong service hoặc domain layer.

## 6. Detailed use cases

### UC-04 Book appointment

**Goal:** Tạo một appointment hợp lệ cho Patient.

**Primary actor:** Patient.

**Supporting actor:** Receptionist, Notification Service.

**Trigger:** Actor chọn một slot và gửi yêu cầu đặt lịch.

**Preconditions:**

1. Actor đã đăng nhập.
2. Actor có quyền đặt lịch.
3. Doctor tồn tại và đang hoạt động.
4. Ngày và giờ yêu cầu không thuộc quá khứ.

**Success postconditions:**

1. Một Appointment mới được tạo.
2. Appointment có trạng thái BOOKED.
3. Slot không còn được xem là available.
4. Audit log được ghi.
5. Hệ thống trả HTTP 201.

**Failure guarantee:**

Nếu thao tác thất bại, hệ thống không được tạo appointment không hoàn chỉnh
và không được chiếm slot.

**Main flow:**

1. Actor xem các slot còn trống.
2. Actor chọn doctor, date và start time.
3. Actor gửi yêu cầu đặt lịch.
4. Hệ thống kiểm tra authentication và authorization.
5. Hệ thống validate dữ liệu đầu vào.
6. Hệ thống kiểm tra doctor schedule.
7. Hệ thống kiểm tra slot còn trống.
8. Hệ thống kiểm tra Patient không có lịch trùng thời gian.
9. Hệ thống tạo Appointment với trạng thái BOOKED.
10. Hệ thống ghi audit log.
11. Hệ thống trả thông tin appointment vừa tạo.
12. Notification Service có thể gửi thông báo xác nhận.

**Alternative and exception flows:**

- A1: Dữ liệu không hợp lệ  
  Hệ thống trả HTTP 400 và không tạo appointment.

- A2: Actor chưa đăng nhập  
  Hệ thống trả HTTP 401.

- A3: Actor không có quyền  
  Hệ thống trả HTTP 403.

- A4: Doctor hoặc slot không tồn tại  
  Hệ thống trả HTTP 404.

- A5: Slot đã bị người khác đặt  
  Hệ thống trả HTTP 409.

- A6: Patient có lịch khác trùng thời gian  
  Hệ thống trả HTTP 409.

- A7: Có lỗi trong lúc lưu  
  Toàn bộ thao tác bị rollback và hệ thống trả lỗi server phù hợp.

**Business rules:**

- BR-APPT-01: Một doctor-slot chỉ có tối đa một appointment còn hiệu lực.
- BR-APPT-02: Không được đặt ngày hoặc giờ trong quá khứ.
- BR-APPT-03: Patient không được có hai appointment trùng thời gian.
- BR-APPT-04: Thời gian appointment phải thuộc doctor schedule.

---

### UC-07 Check in

**Goal:** Xác nhận Patient đã đến và đưa Patient vào hàng đợi.

**Primary actor:** Patient hoặc Receptionist.

**Trigger:** Actor gửi yêu cầu check-in cho một appointment.

**Preconditions:**

1. Actor đã đăng nhập.
2. Appointment tồn tại.
3. Appointment thuộc đúng ngày hiện tại.
4. Appointment đang ở trạng thái BOOKED.
5. Appointment chưa có QueueTicket.

**Success postconditions:**

1. Appointment chuyển thành CHECKED_IN.
2. QueueTicket được tạo với trạng thái WAITING.
3. QueueTicket có queue number hợp lệ.
4. Hệ thống trả HTTP 201.

**Failure guarantee:**

Không được có trường hợp Appointment đã CHECKED_IN nhưng QueueTicket
chưa được tạo, hoặc ngược lại.

**Main flow:**

1. Actor chọn appointment cần check-in.
2. Actor gửi yêu cầu check-in.
3. Hệ thống kiểm tra authentication và authorization.
4. Hệ thống tìm appointment.
5. Hệ thống kiểm tra ngày hẹn.
6. Hệ thống kiểm tra trạng thái appointment.
7. Hệ thống xác định queue number tiếp theo.
8. Hệ thống chuyển appointment thành CHECKED_IN.
9. Hệ thống tạo QueueTicket ở trạng thái WAITING.
10. Hệ thống ghi audit log.
11. Hệ thống trả thông tin QueueTicket.

**Alternative and exception flows:**

- A1: Appointment không tồn tại  
  Hệ thống trả HTTP 404.

- A2: Actor không sở hữu appointment và không phải Receptionist  
  Hệ thống trả HTTP 403.

- A3: Appointment không thuộc ngày hiện tại  
  Hệ thống trả HTTP 409.

- A4: Appointment đã bị hủy  
  Hệ thống trả HTTP 409.

- A5: Appointment đã được check-in  
  Hệ thống trả HTTP 409.

- A6: Hai request cùng check-in  
  Chỉ một request được tạo QueueTicket; request còn lại nhận HTTP 409.

**Business rules:**

- BR-QUEUE-01: Mỗi appointment có tối đa một QueueTicket.
- BR-QUEUE-02: Queue number phải duy nhất trong hàng đợi của doctor theo ngày.
- BR-QUEUE-03: QueueTicket mới phải có trạng thái WAITING.

---

### UC-08 Call next patient

**Goal:** Chọn và gọi Patient tiếp theo trong hàng đợi của Doctor.

**Primary actor:** Doctor.

**Trigger:** Doctor gửi yêu cầu gọi lượt tiếp theo.

**Preconditions:**

1. Doctor đã đăng nhập.
2. Doctor chỉ được truy cập hàng đợi thuộc mình.
3. Doctor không có lượt khác đang được phục vụ.
4. Hàng đợi được xác định theo ngày hiện tại.

**Success postconditions:**

1. QueueTicket được chọn chuyển từ WAITING sang CALLED.
2. Appointment tương ứng chuyển sang IN_SERVICE.
3. Hệ thống trả thông tin QueueTicket được gọi.

**Failure guarantee:**

Một QueueTicket không được gọi bởi hai request khác nhau.

**Main flow:**

1. Doctor gửi yêu cầu gọi lượt tiếp theo.
2. Hệ thống kiểm tra authentication và role.
3. Hệ thống xác định hàng đợi của Doctor trong ngày.
4. Hệ thống tìm QueueTicket WAITING có queue number nhỏ nhất.
5. Hệ thống khóa hoặc cập nhật có điều kiện QueueTicket đó.
6. Hệ thống chuyển QueueTicket thành CALLED.
7. Hệ thống chuyển Appointment thành IN_SERVICE.
8. Hệ thống ghi thời điểm gọi.
9. Hệ thống ghi audit log.
10. Hệ thống trả QueueTicket được gọi.

**Alternative and exception flows:**

- A1: Người dùng không phải Doctor  
  Hệ thống trả HTTP 403.

- A2: Doctor truy cập hàng đợi của Doctor khác  
  Hệ thống trả HTTP 403.

- A3: Không có QueueTicket WAITING  
  Hệ thống trả HTTP 200 với kết quả rỗng rõ ràng.

- A4: Doctor đang phục vụ một Patient khác  
  Hệ thống trả HTTP 409.

- A5: Hai request gọi cùng lúc  
  Hai request không được nhận cùng một QueueTicket.

**Business rules:**

- BR-CALL-01: Ticket được chọn theo queue number tăng dần.
- BR-CALL-02: Chỉ QueueTicket WAITING mới được gọi.
- BR-CALL-03: Một QueueTicket chỉ được chuyển sang CALLED một lần.
- BR-CALL-04: Việc cập nhật QueueTicket và Appointment phải nguyên tử.

## 7. User stories and acceptance criteria

### US-04 Book appointment

As a Patient,  
I want to book an available slot,  
so that I have a confirmed appointment.

#### Acceptance criteria

1. Given an available slot,  
   when the Patient submits a valid booking request,  
   then the system returns HTTP 201 and status BOOKED.

2. Given two requests for the same slot,  
   when they are processed concurrently,  
   then only one request succeeds.

3. Given a slot in the past,  
   when the Patient submits a booking request,  
   then the system rejects it with HTTP 400.

4. Given the Patient has another appointment at the same time,  
   when a booking request is submitted,  
   then the system returns HTTP 409.

### US-07 Check in

As a Patient,  
I want to check in for today's appointment,  
so that I can enter the Doctor's queue.

#### Acceptance criteria

1. Given a BOOKED appointment for today,  
   when check-in succeeds,  
   then the Appointment becomes CHECKED_IN.

2. Given a successful check-in,  
   then exactly one WAITING QueueTicket is created.

3. Given an appointment that has already been checked in,  
   when check-in is requested again,  
   then the system returns HTTP 409.

4. Given a cancelled appointment,  
   when check-in is requested,  
   then the system returns HTTP 409.

### US-08 Call next patient

As a Doctor,  
I want to call the next waiting Patient,  
so that the queue is processed in order.

#### Acceptance criteria

1. Given multiple WAITING tickets,  
   when the Doctor calls next,  
   then the ticket with the smallest queue number is selected.

2. Given a selected ticket,  
   when the operation succeeds,  
   then the ticket becomes CALLED and the appointment becomes IN_SERVICE.

3. Given two concurrent call-next requests,  
   then they must not return the same QueueTicket.

4. Given no WAITING ticket,  
   when call-next is requested,  
   then the API returns HTTP 200 with an empty result.

## 8. Traceability matrix

| Requirement | Use case | API | Planned test |
|---|---|---|---|
| FR-03 | UC-03 | GET /api/doctors/{doctorId}/available-slots | AvailableSlotApiTest |
| FR-04 | UC-04 | POST /api/appointments | AppointmentApiTest.shouldBookAvailableSlot |
| FR-04, NFR-02 | UC-04 | POST /api/appointments | AppointmentConcurrencyTest.onlyOneRequestBooksSlot |
| FR-05 | UC-05 | PATCH /api/appointments/{id}/cancel | AppointmentApiTest.shouldCancelBookedAppointment |
| FR-06 | UC-06 | PATCH /api/appointments/{id}/reschedule | AppointmentApiTest.shouldRescheduleAtomically |
| FR-07 | UC-07 | POST /api/appointments/{id}/check-in | CheckInApiTest.shouldCreateWaitingTicket |
| FR-07, NFR-03 | UC-07 | POST /api/appointments/{id}/check-in | CheckInConcurrencyTest.shouldCreateOnlyOneTicket |
| FR-08 | UC-08 | POST /api/doctors/{id}/queue/call-next | QueueApiTest.shouldCallEarliestWaitingTicket |
| FR-08, NFR-03 | UC-08 | POST /api/doctors/{id}/queue/call-next | QueueConcurrencyTest.shouldNotCallSameTicketTwice |
| FR-09 | UC-09 | POST /api/queue-tickets/{id}/complete | QueueApiTest.shouldCompleteCurrentTicket |
| FR-10 | UC-04, UC-07, UC-08 | Internal audit operation | AuditLogIntegrationTest |

## 9. Requirement validation checklist

- Mỗi requirement có mã duy nhất.
- Requirement không chứa từ mơ hồ như nhanh, dễ dùng hoặc phù hợp.
- Requirement có thể kiểm thử.
- Actor có quyền rõ ràng.
- Main flow mô tả trường hợp thành công.
- Alternative flow mô tả lỗi nghiệp vụ.
- Postcondition mô tả trạng thái dữ liệu sau thao tác.
- Acceptance criteria dùng Given, When và Then.
- Requirement quan trọng được ánh xạ sang API và test.