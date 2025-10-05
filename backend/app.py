from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, jwt_required, create_access_token, get_jwt_identity
from flask_cors import CORS
import bcrypt
import pyotp
import smtplib
from email.mime.text import MIMEText
from supabase import create_client, Client
import os
from dotenv import load_dotenv
import uuid
from datetime import datetime, timedelta

load_dotenv()

app = Flask(__name__)
CORS(app)
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=1)
jwt = JWTManager(app)

supabase: Client = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_KEY'))

# Helper: Encrypt/Decrypt data
def encrypt_data(data):
    return supabase.table('dummy').rpc('pgp_sym_encrypt', {'data': data, 'key': os.getenv('JWT_SECRET_KEY')}).execute()

def decrypt_data(encrypted_data):
    return supabase.table('dummy').rpc('pgp_sym_decrypt', {'data': encrypted_data, 'key': os.getenv('JWT_SECRET_KEY')}).execute()

# Helper: Send email
def send_email(to, subject, body):
    msg = MIMEText(body)
    msg['Subject'] = subject
    msg['From'] = os.getenv('GMAIL_USER')
    msg['To'] = to
    with smtplib.SMTP_SSL('smtp.gmail.com', 465) as server:
        server.login(os.getenv('GMAIL_USER'), os.getenv('GMAIL_PASSWORD'))
        server.sendmail(os.getenv('GMAIL_USER'), to, msg.as_string())

# Audit log helper
def log_audit(user_id, action, ip):
    supabase.table('audit_logs').insert({'user_id': user_id, 'action': action, 'ip_address': ip}).execute()

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    ip = request.remote_addr

    try:
        # Use Supabase Auth for secure login
        auth_response = supabase.auth.sign_in_with_password({"email": email, "password": password})
        user_id = auth_response.user.id
        user = supabase.table('users').select('role, two_fa_enabled').eq('id', user_id).execute().data[0]

        if user['role'] in ['admin', 'doctor', 'pharmacist'] and user['two_fa_enabled']:
            totp = pyotp.TOTP(pyotp.random_base32())  # In production, store secret per user
            otp_code = totp.now()
            send_email(email, '2FA Code', f'Your code: {otp_code}')
            return jsonify({'message': '2FA required', 'temp_token': create_access_token(identity=user_id)}), 200

        token = create_access_token(identity=user_id)
        log_audit(user_id, 'login', ip)
        return jsonify({'token': token, 'role': user['role']}), 200
    except Exception as e:
        log_audit(None, 'failed_login', ip)
        return jsonify({'error': 'Invalid credentials'}), 401

@app.route('/verify-2fa', methods=['POST'])
def verify_2fa():
    data = request.json
    temp_token = data.get('temp_token')
    otp = data.get('otp')
    # Verify OTP (simplified)
    if otp == '123456':
        user_id = get_jwt_identity()  # From temp_token
        token = create_access_token(identity=user_id)
        return jsonify({'token': token}), 200
    return jsonify({'error': 'Invalid OTP'}), 401

@app.route('/reset-password', methods=['POST'])
@jwt_required()
def reset_password():
    user_id = get_jwt_identity()
    user = supabase.table('users').select('role').eq('id', user_id).execute().data[0]
    if user['role'] != 'admin':
        return jsonify({'error': 'Unauthorized'}), 403
    send_email('target@example.com', 'Password Reset', 'Reset link: https://your-app.com/reset')
    log_audit(user_id, 'password_reset_request', request.remote_addr)
    return jsonify({'message': 'Reset link sent'}), 200

@app.route('/users', methods=['GET', 'POST', 'PUT', 'DELETE'])
@jwt_required()
def manage_users():
    user_id = get_jwt_identity()
    user = supabase.table('users').select('role').eq('id', user_id).execute().data[0]
    if user['role'] != 'admin':
        return jsonify({'error': 'Unauthorized'}), 403
    if request.method == 'GET':
        users = supabase.table('users').select('*').execute()
        return jsonify(users.data), 200
    # Add POST/PUT/DELETE logic similarly

@app.route('/appointments', methods=['GET', 'POST'])
@jwt_required()
def manage_appointments():
    user_id = get_jwt_identity()
    user = supabase.table('users').select('role').eq('id', user_id).execute().data[0]
    if request.method == 'GET':
        if user['role'] == 'patient':
            apps = supabase.table('appointments').select('*').eq('patient_id', user_id).execute()
        elif user['role'] in ['doctor', 'receptionist']:
            apps = supabase.table('appointments').select('*').execute()
        return jsonify(apps.data), 200
    # POST: Book appointment

@app.route('/records', methods=['GET', 'POST'])
@jwt_required()
def manage_records():
    user_id = get_jwt_identity()
    user = supabase.table('users').select('role').eq('id', user_id).execute().data[0]
    if user['role'] not in ['doctor', 'patient']:
        return jsonify({'error': 'Unauthorized'}), 403
    records = supabase.table('medical_records').select('*').eq('patient_id' if user['role'] == 'patient' else 'doctor_id', user_id).execute()
    for r in records.data:
        r['lab_results'] = decrypt_data(r['encrypted_lab_results'])
    return jsonify(records.data), 200

@app.route('/inventory', methods=['GET', 'POST'])
@jwt_required()
def manage_inventory():
    user_id = get_jwt_identity()
    user = supabase.table('users').select('role').eq('id', user_id).execute().data[0]
    if user['role'] != 'pharmacist':
        return jsonify({'error': 'Unauthorized'}), 403
    if request.method == 'GET':
        inv = supabase.table('inventory').select('*').execute()
        return jsonify(inv.data), 200
    # POST: Update stock

@app.route('/notifications', methods=['GET'])
@jwt_required()
def get_notifications():
    user_id = get_jwt_identity()
    notifs = supabase.table('notifications').select('*').eq('user_id', user_id).execute()
    return jsonify(notifs.data), 200

if __name__ == '__main__':
    app.run(debug=True)