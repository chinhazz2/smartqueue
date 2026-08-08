# SmartQueue Database Design

## 1. Purpose

Tài liệu này ánh xạ SmartQueue domain model sang PostgreSQL schema.

Schema được quản lý bằng Flyway và phải bảo vệ các invariant quan trọng
ngay cả khi application nhận nhiều request đồng thời.

## 2. Mapping rules

| Domain concept | Relational representation |
|---|---|
| Entity | Table |
| Entity identity | UUID primary key |
| Attribute | Column |
| Required value | NOT NULL |
| Relationship | Foreign key |
| One-to-zero-or-one | UNIQUE foreign key |
| Allowed values | CHECK constraint |
| Uniqueness rule | UNIQUE constraint/index |
| Time overlap rule | Exclusion constraint |
| Frequent query | Index |

## 3. Tables

### users

Lưu tài khoản và role của Patient, Receptionist, Doctor
và Administrator.

### doctor_profiles

Lưu dữ liệu riêng của Doctor.

Một User có tối đa một DoctorProfile.

### doctor_schedules

Lưu lịch làm việc lặp lại theo ngày trong tuần.

### doctor_time_off

Lưu các khoảng nghỉ hoặc vắng mặt cụ thể.

### appointments

Lưu lịch hẹn giữa Patient và Doctor.

Các Appointment còn hiệu lực của cùng Doctor hoặc Patient
không được chồng lấn thời gian.

### queue_tickets

Lưu vị trí Appointment trong hàng đợi của Doctor theo ngày.

Mỗi Appointment có tối đa một QueueTicket.

### audit_logs

Lưu actor, action, entity và thời điểm của thao tác quan trọng.

## 4. Core constraints

### Unique normalized email

Email được so sánh bằng giá trị chữ thường:

```sql
UNIQUE INDEX ON users (lower(email))