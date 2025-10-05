-- Sample Data for Clinic Management System
-- Run this in Supabase SQL Editor after creating users in Auth.
-- Replace <real_uuid> with actual UUIDs from Supabase Auth > Users.

-- Insert sample users (link to auth.users; no password needed here)
INSERT INTO users (id, email, role, two_fa_enabled) VALUES
('d5b6a7e5-1ee4-4433-9d04-411497116b72', 'admin@example.com', 'admin', true),
('fbb3d489-2a76-4185-aea8-ae4cae820ce0', 'doctor@example.com', 'doctor', true),
('083bc677-f34f-4f53-a30d-f93e657654a7', 'receptionist@example.com', 'receptionist', false),
('a5d6370b-8d66-487a-8d36-e990f9a13864', 'labtech@example.com', 'lab_technician', false),
('51a9ff10-6ec9-4eaf-8e2a-5c03a2ba5634', 'pharmacist@example.com', 'pharmacist', true),
('d2e76406-699c-425b-89df-47bb4837bd0d', 'patient@example.com', 'patient', false);

-- Insert sample patients (link to patient user)
INSERT INTO patients (user_id, name, dob, insurance_details, encrypted_medical_history) VALUES
('d2e76406-699c-425b-89df-47bb4837bd0d', 'John Doe', '1985-05-15', 'Insurance ID: 12345', pgp_sym_encrypt('Past: Hypertension', 'ed9ef520fa3e606d3f4893ae34c00eb231e6de9d109306b47dac1dc5f42cf520'));

-- Insert sample appointments
INSERT INTO appointments (patient_id, doctor_id, date_time, status, notes) VALUES
((SELECT id FROM patients WHERE name = 'John Doe'), 'fbb3d489-2a76-4185-aea8-ae4cae820ce0', '2023-10-01 10:00:00', 'booked', 'Initial checkup');

-- Insert sample medical records
INSERT INTO medical_records (patient_id, doctor_id, diagnosis, prescriptions, encrypted_lab_results) VALUES
((SELECT id FROM patients WHERE name = 'John Doe'), 'fbb3d489-2a76-4185-aea8-ae4cae820ce0', 'Hypertension', 'Medication A', pgp_sym_encrypt('Blood test: Normal', 'ed9ef520fa3e606d3f4893ae34c00eb231e6de9d109306b47dac1dc5f42cf520'));

-- Insert sample inventory
INSERT INTO inventory (item_name, type, quantity, expiration_date, price, reorder_threshold) VALUES
('Aspirin', 'medication', 100, '2025-12-31', 5.00, 20),
('Syringes', 'supply', 200, '2024-06-30', 0.50, 50);

-- Insert sample audit logs
INSERT INTO audit_logs (user_id, action, ip_address) VALUES
('d5b6a7e5-1ee4-4433-9d04-411497116b72', 'login', '127.0.0.1');

-- Insert sample notifications
INSERT INTO notifications (user_id, type, message) VALUES
('d2e76406-699c-425b-89df-47bb4837bd0d', 'reminder', 'Appointment tomorrow at 10 AM');