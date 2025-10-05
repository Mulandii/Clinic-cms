-- Clinic Management System Database Schema
-- Run this in Supabase SQL Editor. Enables RLS for security.

-- Enable RLS globally
ALTER DATABASE postgres SET row_security = on;

-- Users table (extends Supabase auth.users)
CREATE TABLE users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    hashed_password TEXT NOT NULL,  -- Hashed via bcrypt in backend
    role TEXT NOT NULL CHECK (role IN ('admin', 'doctor', 'receptionist', 'lab_technician', 'pharmacist', 'patient')),
    two_fa_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS on users
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admins can manage all users" ON users FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);

-- Patients table
CREATE TABLE patients (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,  -- Links to portal users
    name TEXT NOT NULL,
    dob DATE NOT NULL,
    insurance_details TEXT,
    encrypted_medical_history BYTEA  -- Encrypted for HIPAA
);

-- Enable RLS on patients
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Patients view own data" ON patients FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Doctors view assigned patients" ON patients FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'doctor')
);
CREATE POLICY "Receptionists manage patient details" ON patients FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'receptionist')
);

-- Appointments table
CREATE TABLE appointments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    doctor_id UUID REFERENCES users(id) ON DELETE CASCADE,
    date_time TIMESTAMP NOT NULL,
    status TEXT DEFAULT 'booked' CHECK (status IN ('booked', 'completed', 'cancelled')),
    notes TEXT
);

-- Enable RLS on appointments
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Patients view own appointments" ON appointments FOR SELECT USING (
    EXISTS (SELECT 1 FROM patients WHERE user_id = auth.uid() AND id = appointments.patient_id)
);
CREATE POLICY "Doctors manage own appointments" ON appointments FOR ALL USING (auth.uid() = doctor_id);
CREATE POLICY "Receptionists manage all appointments" ON appointments FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'receptionist')
);

-- Medical records table
CREATE TABLE medical_records (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    doctor_id UUID REFERENCES users(id) ON DELETE CASCADE,
    diagnosis TEXT,
    prescriptions TEXT,
    encrypted_lab_results BYTEA  -- Encrypted
);

-- Enable RLS on medical_records
ALTER TABLE medical_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Doctors view/edit own records" ON medical_records FOR ALL USING (auth.uid() = doctor_id);
CREATE POLICY "Patients view own records" ON medical_records FOR SELECT USING (
    EXISTS (SELECT 1 FROM patients WHERE user_id = auth.uid() AND id = medical_records.patient_id)
);

-- Inventory table
CREATE TABLE inventory (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    item_name TEXT NOT NULL,
    type TEXT CHECK (type IN ('medication', 'supply')),
    quantity INTEGER NOT NULL DEFAULT 0,
    expiration_date DATE,
    price DECIMAL(10,2),
    reorder_threshold INTEGER DEFAULT 10
);

-- Enable RLS on inventory
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Pharmacists manage inventory" ON inventory FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'pharmacist')
);

-- Audit logs table
CREATE TABLE audit_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    action TEXT NOT NULL,  -- e.g., 'login', 'password_reset'
    timestamp TIMESTAMP DEFAULT NOW(),
    ip_address INET
);

-- Enable RLS on audit_logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins view all logs" ON audit_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);

-- Notifications table
CREATE TABLE notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type TEXT CHECK (type IN ('reminder', 'alert')),
    message TEXT NOT NULL,
    sent_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS on notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);