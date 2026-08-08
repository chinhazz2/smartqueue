-- SmartQueue core relational schema.
--
-- Domain model:
-- User, DoctorProfile, DoctorSchedule, DoctorTimeOff,
-- Appointment, QueueTicket and AuditLog.

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- =========================================================
-- Users
-- =========================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    email VARCHAR(320) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    phone VARCHAR(30),

    role VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_users_email_not_blank
        CHECK (btrim(email) <> ''),

    CONSTRAINT ck_users_password_hash_not_blank
        CHECK (btrim(password_hash) <> ''),

    CONSTRAINT ck_users_full_name_not_blank
        CHECK (btrim(full_name) <> ''),

    CONSTRAINT ck_users_phone_not_blank
        CHECK (phone IS NULL OR btrim(phone) <> ''),

    CONSTRAINT ck_users_role
        CHECK (
            role IN (
                'PATIENT',
                'RECEPTIONIST',
                'DOCTOR',
                'ADMINISTRATOR'
            )
        ),

    CONSTRAINT ck_users_status
        CHECK (
            status IN (
                'ACTIVE',
                'LOCKED',
                'DISABLED'
            )
        )
);

CREATE UNIQUE INDEX uq_users_email_normalized
    ON users (lower(email));

-- =========================================================
-- Doctor profiles
-- =========================================================

CREATE TABLE doctor_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL,
    specialty VARCHAR(120) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_doctor_profiles_user
        UNIQUE (user_id),

    CONSTRAINT fk_doctor_profiles_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_doctor_profiles_specialty_not_blank
        CHECK (btrim(specialty) <> '')
);

-- =========================================================
-- Recurring doctor schedules
-- ISO day-of-week: Monday = 1, Sunday = 7.
-- =========================================================

CREATE TABLE doctor_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    doctor_id UUID NOT NULL,
    day_of_week SMALLINT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    slot_duration_minutes SMALLINT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_doctor_schedules_doctor
        FOREIGN KEY (doctor_id)
        REFERENCES doctor_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_doctor_schedules_day_of_week
        CHECK (day_of_week BETWEEN 1 AND 7),

    CONSTRAINT ck_doctor_schedules_time_range
        CHECK (start_time < end_time),

    CONSTRAINT ck_doctor_schedules_slot_duration
        CHECK (
            slot_duration_minutes > 0
            AND slot_duration_minutes <= 480
        ),

    CONSTRAINT uq_doctor_schedules_exact
        UNIQUE (
            doctor_id,
            day_of_week,
            start_time,
            end_time
        )
);

-- Prevent overlapping active recurring schedules
-- for the same doctor and day of week.
ALTER TABLE doctor_schedules
    ADD CONSTRAINT ex_doctor_schedules_no_overlap
    EXCLUDE USING gist (
        doctor_id WITH =,
        day_of_week WITH =,
        tsrange(
            DATE '2000-01-03' + start_time,
            DATE '2000-01-03' + end_time,
            '[)'
        ) WITH &&
    )
    WHERE (active);

CREATE INDEX idx_doctor_schedules_lookup
    ON doctor_schedules (
        doctor_id,
        day_of_week,
        active
    );

-- =========================================================
-- Doctor time off
-- =========================================================

CREATE TABLE doctor_time_off (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    doctor_id UUID NOT NULL,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    reason VARCHAR(500),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_doctor_time_off_doctor
        FOREIGN KEY (doctor_id)
        REFERENCES doctor_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_doctor_time_off_time_range
        CHECK (start_at < end_at),

    CONSTRAINT ck_doctor_time_off_reason_not_blank
        CHECK (reason IS NULL OR btrim(reason) <> '')
);

CREATE INDEX idx_doctor_time_off_lookup
    ON doctor_time_off (
        doctor_id,
        start_at,
        end_at
    );

-- =========================================================
-- Appointments
-- =========================================================

CREATE TABLE appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL,
    doctor_id UUID NOT NULL,

    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'BOOKED',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancelled_at TIMESTAMPTZ,

    CONSTRAINT fk_appointments_patient
        FOREIGN KEY (patient_id)
        REFERENCES users(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_appointments_doctor
        FOREIGN KEY (doctor_id)
        REFERENCES doctor_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_appointments_time_range
        CHECK (start_at < end_at),

    CONSTRAINT ck_appointments_status
        CHECK (
            status IN (
                'BOOKED',
                'CHECKED_IN',
                'IN_SERVICE',
                'COMPLETED',
                'CANCELLED'
            )
        ),

    CONSTRAINT ck_appointments_cancelled_at
        CHECK (
            (
                status = 'CANCELLED'
                AND cancelled_at IS NOT NULL
            )
            OR
            (
                status <> 'CANCELLED'
                AND cancelled_at IS NULL
            )
        ),

    -- Used by QueueTicket's composite foreign key so that
    -- its doctor_id must match the Appointment's doctor_id.
    CONSTRAINT uq_appointments_id_doctor
        UNIQUE (id, doctor_id)
);

-- No active Appointment may overlap another active
-- Appointment for the same Doctor.
ALTER TABLE appointments
    ADD CONSTRAINT ex_appointments_doctor_overlap
    EXCLUDE USING gist (
        doctor_id WITH =,
        tstzrange(start_at, end_at, '[)') WITH &&
    )
    WHERE (
        status IN (
            'BOOKED',
            'CHECKED_IN',
            'IN_SERVICE'
        )
    );

-- No Patient may have two active overlapping Appointments.
ALTER TABLE appointments
    ADD CONSTRAINT ex_appointments_patient_overlap
    EXCLUDE USING gist (
        patient_id WITH =,
        tstzrange(start_at, end_at, '[)') WITH &&
    )
    WHERE (
        status IN (
            'BOOKED',
            'CHECKED_IN',
            'IN_SERVICE'
        )
    );

CREATE INDEX idx_appointments_patient_time
    ON appointments (
        patient_id,
        start_at
    );

CREATE INDEX idx_appointments_doctor_time
    ON appointments (
        doctor_id,
        start_at
    );

CREATE INDEX idx_appointments_status
    ON appointments (status);

-- =========================================================
-- Queue tickets
-- =========================================================

CREATE TABLE queue_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    appointment_id UUID NOT NULL,
    doctor_id UUID NOT NULL,

    queue_date DATE NOT NULL,
    queue_number INTEGER NOT NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'WAITING',

    checked_in_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    called_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,

    CONSTRAINT uq_queue_tickets_appointment
        UNIQUE (appointment_id),

    CONSTRAINT uq_queue_tickets_number
        UNIQUE (
            doctor_id,
            queue_date,
            queue_number
        ),

    -- This also guarantees that queue_tickets.doctor_id
    -- equals the Doctor assigned to the Appointment.
    CONSTRAINT fk_queue_tickets_appointment_doctor
        FOREIGN KEY (
            appointment_id,
            doctor_id
        )
        REFERENCES appointments (
            id,
            doctor_id
        )
        ON DELETE RESTRICT,

    CONSTRAINT ck_queue_tickets_queue_number
        CHECK (queue_number > 0),

    CONSTRAINT ck_queue_tickets_status
        CHECK (
            status IN (
                'WAITING',
                'CALLED',
                'COMPLETED'
            )
        ),

    CONSTRAINT ck_queue_tickets_status_timestamps
        CHECK (
            (
                status = 'WAITING'
                AND called_at IS NULL
                AND completed_at IS NULL
            )
            OR
            (
                status = 'CALLED'
                AND called_at IS NOT NULL
                AND completed_at IS NULL
            )
            OR
            (
                status = 'COMPLETED'
                AND called_at IS NOT NULL
                AND completed_at IS NOT NULL
            )
        ),

    CONSTRAINT ck_queue_tickets_called_after_check_in
        CHECK (
            called_at IS NULL
            OR called_at >= checked_in_at
        ),

    CONSTRAINT ck_queue_tickets_completed_after_called
        CHECK (
            completed_at IS NULL
            OR completed_at >= called_at
        )
);

-- Supports:
-- SELECT the smallest WAITING queue number for a Doctor/day.
CREATE INDEX idx_queue_tickets_waiting_next
    ON queue_tickets (
        doctor_id,
        queue_date,
        queue_number
    )
    WHERE status = 'WAITING';

CREATE INDEX idx_queue_tickets_appointment
    ON queue_tickets (appointment_id);

-- =========================================================
-- Audit logs
-- =========================================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    actor_user_id UUID,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,

    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    details JSONB NOT NULL DEFAULT '{}'::JSONB,

    CONSTRAINT fk_audit_logs_actor
        FOREIGN KEY (actor_user_id)
        REFERENCES users(id)
        ON DELETE SET NULL,

    CONSTRAINT ck_audit_logs_action_not_blank
        CHECK (btrim(action) <> ''),

    CONSTRAINT ck_audit_logs_entity_type_not_blank
        CHECK (btrim(entity_type) <> '')
);

CREATE INDEX idx_audit_logs_entity
    ON audit_logs (
        entity_type,
        entity_id,
        occurred_at
    );

CREATE INDEX idx_audit_logs_actor
    ON audit_logs (
        actor_user_id,
        occurred_at
    );