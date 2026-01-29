# 📚 PANDUAN LENGKAP - SISTEM PAYROLL & ABSENSI

## 🎯 Overview

Sistem Payroll & Absensi dengan fitur:
- ✅ Login HRD dengan autentikasi aman
- ✅ CRUD data karyawan
- ✅ Manajemen gaji (set gaji, tunjangan, potongan)
- ✅ Upload & parsing data absensi dari Excel
- ✅ Perhitungan otomatis payroll
- ✅ Generate slip gaji PDF
- ✅ Dashboard analytics
- ✅ Row Level Security (RLS) di database

---

## 🗄️ DATABASE SETUP (SUPABASE)

### 1. Buat Project Supabase

1. Buka [supabase.com](https://supabase.com)
2. Sign up / Login
3. Klik "New Project"
4. Isi detail project:
   - Name: `payroll-system`
   - Database Password: (simpan dengan aman!)
   - Region: pilih yang terdekat (Southeast Asia)
5. Tunggu project selesai dibuat (~2 menit)

### 2. Setup Database Schema

1. Di dashboard Supabase, buka **SQL Editor**
2. Klik **New Query**
3. Copy-paste SEMUA isi file `supabase_schema.sql`
4. Klik **Run** atau tekan `Ctrl + Enter`
5. Pastikan semua query berhasil (✅ Success)

### 3. Dapatkan API Keys

1. Buka **Settings** > **API**
2. Copy nilai berikut:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon public key**: `eyJhbGc...`
   - **service_role key**: `eyJhbGc...` (untuk admin operations)

### 4. Setup Authentication

1. Buka **Authentication** > **Providers**
2. Enable **Email** provider
3. Disable "Confirm email" jika untuk internal saja
4. Buka **URL Configuration**
5. Set **Site URL** ke URL Streamlit Anda

### 5. Buat User HRD Pertama

Di SQL Editor, jalankan:

```sql
-- Hash password menggunakan bcrypt
-- Contoh: password "hrd123" 
-- PENTING: Ganti dengan password yang lebih kuat!

INSERT INTO users (email, password_hash, full_name, role) VALUES
('hrd@company.com', '$2b$10$YourHashedPasswordHere', 'HRD Manager', 'hrd');
```

**Cara generate password hash:**

```python
import bcrypt
password = "hrd123"
hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
print(hashed.decode('utf-8'))
```

---

## 💻 DEPLOYMENT KE STREAMLIT CLOUD

### 1. Persiapan Repository GitHub

```bash
# Clone repository atau buat baru
git init
git add .
git commit -m "Initial commit"

# Push ke GitHub
git remote add origin https://github.com/username/payroll-system.git
git push -u origin main
```

### 2. File yang Harus Ada

Pastikan struktur folder:
```
payroll-system/
├── streamlit_app.py          # Main app
├── requirements.txt           # Python dependencies
├── .env.example              # Template environment variables
├── README.md                 # Dokumentasi
└── supabase_schema.sql       # Database schema
```

### 3. Deploy ke Streamlit Cloud

1. Buka [share.streamlit.io](https://share.streamlit.io)
2. Login dengan GitHub
3. Klik **New app**
4. Pilih repository: `username/payroll-system`
5. Main file path: `streamlit_app.py`
6. Klik **Advanced settings**

### 4. Set Environment Variables

Di Advanced Settings > Secrets, tambahkan:

```toml
# .streamlit/secrets.toml

SUPABASE_URL = "https://xxxxx.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGc..."
SUPABASE_SERVICE_KEY = "eyJhbGc..."
APP_SECRET_KEY = "your-random-secret-key-here"
ENVIRONMENT = "production"
```

7. Klik **Deploy!**
8. Tunggu proses build (~2-3 menit)

---

## 🎨 DASHBOARD MODERN (React Version)

### Jika Ingin Dashboard React yang Lebih Modern

File `dashboard.jsx` adalah versi React dengan design yang lebih menarik.

**Setup:**

1. Install dependencies:
```bash
npm install @supabase/supabase-js lucide-react
```

2. Buat file `.env.local`:
```
REACT_APP_SUPABASE_URL=https://xxxxx.supabase.co
REACT_APP_SUPABASE_ANON_KEY=eyJhbGc...
```

3. Import di App.jsx:
```javascript
import PayrollDashboard from './dashboard.jsx';

function App() {
  return <PayrollDashboard />;
}
```

4. Deploy ke Vercel/Netlify untuk hosting gratis

---

## 🔐 STRUKTUR DATABASE

### Tables:

1. **users** - HRD login accounts
2. **employees** - Master data karyawan
3. **salary_settings** - Pengaturan gaji per karyawan
4. **attendance_records** - Data absensi harian
5. **payroll_periods** - Periode penggajian (bulanan)
6. **payroll_slips** - Slip gaji per karyawan per periode
7. **audit_logs** - Log aktivitas untuk audit

### Views:

1. **v_employees_with_salary** - Employee dengan info gaji aktif
2. **v_monthly_attendance_summary** - Summary absensi per bulan

### Stored Procedures:

1. **calculate_payroll(period_id)** - Hitung payroll otomatis untuk 1 periode

---

## 📝 CARA PAKAI

### A. Login HRD

1. Buka aplikasi
2. Login dengan email & password yang sudah dibuat
3. Dashboard akan muncul

### B. Tambah Karyawan

1. Klik menu **Karyawan**
2. Klik tombol **➕ Tambah Karyawan**
3. Isi form:
   - ID Karyawan (NIK)
   - Nama Lengkap
   - Email
   - Department
   - Posisi
   - Tanggal Masuk
4. Klik **💾 Simpan**

### C. Set Gaji Karyawan

1. Di halaman Karyawan, klik **💰 Set Gaji** pada karyawan
2. Isi:
   - Gaji Pokok
   - Tunjangan Transport
   - Tunjangan Makan
   - Tunjangan Jabatan
   - Rate Lembur per Jam
   - Potongan Telat per Menit
   - Potongan BPJS Kesehatan
   - Potongan BPJS Ketenagakerjaan
   - Potongan Pajak
3. Set tanggal efektif
4. Klik **💾 Simpan**

### D. Upload Absensi

1. Klik menu **Absensi**
2. Klik **📤 Upload Data Absensi**
3. Pilih file Excel dari mesin fingerprint
4. Preview data akan muncul
5. Klik **💾 Simpan ke Database**

### E. Proses Penggajian

1. Klik menu **Penggajian**
2. Klik **➕ Buat Periode Penggajian Baru**
3. Isi:
   - Nama Periode (contoh: "Januari 2025")
   - Tanggal Mulai
   - Tanggal Selesai
   - Tanggal Pembayaran
4. Klik **💾 Buat Periode**
5. Klik **🧮 Hitung Payroll** untuk otomatis menghitung gaji semua karyawan
6. Review slip gaji yang sudah dihitung
7. Klik **✅ Approve** jika sudah sesuai

### F. Download Slip Gaji

1. Di halaman Penggajian
2. Pilih periode
3. Pilih karyawan
4. Klik **📥 Download Slip Gaji (PDF)**

---

## 🔧 KONFIGURASI LANJUTAN

### Ubah Rate Lembur

Di SQL Editor:
```sql
UPDATE salary_settings 
SET overtime_rate_per_hour = 75000 
WHERE employee_id = 'EMP001' AND is_active = true;
```

### Ubah Potongan Telat

```sql
UPDATE salary_settings 
SET late_penalty_per_minute = 10000 
WHERE employee_id = 'EMP001' AND is_active = true;
```

### Manual Insert Absensi

```sql
INSERT INTO attendance_records (
    employee_id, 
    attendance_date, 
    check_in, 
    check_out, 
    status
) VALUES (
    '550e8400-e29b-41d4-a716-446655440000', -- employee UUID
    '2025-01-29',
    '08:00:00',
    '17:00:00',
    'hadir'
);
```

### Lihat Total Gaji per Department

```sql
SELECT 
    e.department,
    COUNT(*) as total_employees,
    SUM(s.basic_salary) as total_basic_salary,
    AVG(s.basic_salary) as avg_salary
FROM employees e
JOIN salary_settings s ON e.id = s.employee_id AND s.is_active = true
WHERE e.status = 'active'
GROUP BY e.department;
```

---

## 🚀 FITUR UNGGULAN

### 1. Row Level Security (RLS)
- Data aman dengan policy level database
- HRD hanya bisa akses data karyawan aktif
- User biasa tidak bisa akses data sensitif

### 2. Audit Trail
- Semua aktivitas tercatat di `audit_logs`
- Track siapa yang edit/hapus data
- Timestamp lengkap

### 3. Calculated Columns
- Gaji kotor, potongan, gaji bersih otomatis terhitung
- Menggunakan GENERATED ALWAYS AS STORED

### 4. Optimized Queries
- Index pada kolom yang sering di-query
- Views untuk query yang kompleks

### 5. Password Security
- Bcrypt hashing
- Salt per user
- Tidak pernah store plain password

---

## 🐛 TROUBLESHOOTING

### Error: "relation does not exist"
- Pastikan sudah run `supabase_schema.sql`
- Check di Table Editor apakah tables sudah ada

### Error: "new row violates row-level security policy"
- Check RLS policies di Authentication > Policies
- Pastikan user sudah login dengan benar

### Error: "Failed to fetch"
- Check SUPABASE_URL dan SUPABASE_ANON_KEY
- Pastikan tidak ada typo
- Check di Network tab browser untuk lihat error detail

### Upload Excel Gagal
- Pastikan format Excel sesuai
- Check column names
- Lihat console log untuk error detail

### Calculation Payroll Error
- Pastikan attendance data sudah ada untuk periode tersebut
- Check salary_settings sudah di-set untuk semua employee
- Run manual query untuk debug

---

## 📊 BEST PRACTICES

### 1. Backup Database
```bash
# Di Supabase Dashboard > Database > Backups
# Enable Point-in-time Recovery (PITR)
```

### 2. Regular Audit
```sql
-- Check aktivitas mencurigakan
SELECT * FROM audit_logs 
WHERE action IN ('DELETE', 'UPDATE') 
ORDER BY created_at DESC 
LIMIT 100;
```

### 3. Data Validation
- Validasi input di frontend
- Double check sebelum approve payroll
- Review attendance anomali (lembur >12 jam, etc)

### 4. Security
- Ganti password default
- Jangan share API keys
- Enable 2FA di Supabase account
- Regular password rotation

---

## 📞 SUPPORT

Jika ada kendala:
1. Check dokumentasi Supabase: [docs.supabase.com](https://docs.supabase.com)
2. Check Streamlit docs: [docs.streamlit.io](https://docs.streamlit.io)
3. Review logs di Streamlit Cloud > Logs
4. Check SQL logs di Supabase > Logs

---

## 🎓 NEXT STEPS

Fitur yang bisa ditambahkan:
- [ ] Export to Excel (bulk export)
- [ ] Email notification slip gaji
- [ ] Mobile app (React Native)
- [ ] WhatsApp integration
- [ ] Biometric integration langsung
- [ ] Dashboard analytics lebih detail
- [ ] Multi-company support
- [ ] Approval workflow multi-level
- [ ] Integration dengan accounting software

---

## 📄 LICENSE

MIT License - Feel free to modify and use for your company!

---

**Dibuat dengan ❤️ untuk mempermudah pekerjaan HRD**
