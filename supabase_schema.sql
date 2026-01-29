-- =====================================================
-- SUPABASE DATABASE SCHEMA
-- Sistem Payroll & Absensi
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. TABLE: users (untuk autentikasi HRD)
-- =====================================================
CREATE TABLE users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'hrd' CHECK (role IN ('hrd', 'admin', 'superadmin')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE
);

-- =====================================================
-- 2. TABLE: employees (data karyawan)
-- =====================================================
CREATE TABLE employees (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    employee_id VARCHAR(50) UNIQUE NOT NULL, -- ID Karyawan (NIK)
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    department VARCHAR(100),
    position VARCHAR(100),
    join_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'resigned')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3. TABLE: salary_settings (pengaturan gaji)
-- =====================================================
CREATE TABLE salary_settings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    basic_salary DECIMAL(15, 2) NOT NULL DEFAULT 0,
    transport_allowance DECIMAL(15, 2) DEFAULT 0,
    meal_allowance DECIMAL(15, 2) DEFAULT 0,
    position_allowance DECIMAL(15, 2) DEFAULT 0,
    other_allowance DECIMAL(15, 2) DEFAULT 0,
    
    -- Potongan tetap
    bpjs_health DECIMAL(15, 2) DEFAULT 0,
    bpjs_employment DECIMAL(15, 2) DEFAULT 0,
    tax_deduction DECIMAL(15, 2) DEFAULT 0,
    
    -- Pengaturan lembur
    overtime_rate_per_hour DECIMAL(15, 2) DEFAULT 0,
    
    -- Pengaturan potongan keterlambatan
    late_penalty_per_minute DECIMAL(15, 2) DEFAULT 0,
    absence_penalty_per_day DECIMAL(15, 2) DEFAULT 0,
    
    effective_from DATE NOT NULL,
    effective_until DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_active_salary UNIQUE (employee_id, is_active)
);

-- =====================================================
-- 4. TABLE: attendance_records (data absensi)
-- =====================================================
CREATE TABLE attendance_records (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    check_in TIME,
    check_out TIME,
    
    -- Status kehadiran
    status VARCHAR(50) DEFAULT 'hadir' CHECK (
        status IN ('hadir', 'telat', 'alpha', 'izin', 'sakit', 'cuti', 'lembur')
    ),
    
    -- Perhitungan
    late_minutes INTEGER DEFAULT 0,
    overtime_hours DECIMAL(5, 2) DEFAULT 0,
    late_penalty DECIMAL(15, 2) DEFAULT 0,
    overtime_pay DECIMAL(15, 2) DEFAULT 0,
    
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_attendance UNIQUE (employee_id, attendance_date)
);

-- =====================================================
-- 5. TABLE: payroll_periods (periode penggajian)
-- =====================================================
CREATE TABLE payroll_periods (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    period_name VARCHAR(100) NOT NULL, -- e.g., "Januari 2025"
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    payment_date DATE,
    status VARCHAR(50) DEFAULT 'draft' CHECK (
        status IN ('draft', 'calculated', 'approved', 'paid')
    ),
    created_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_period UNIQUE (period_start, period_end)
);

-- =====================================================
-- 6. TABLE: payroll_slips (slip gaji)
-- =====================================================
CREATE TABLE payroll_slips (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    payroll_period_id UUID REFERENCES payroll_periods(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Gaji & Tunjangan
    basic_salary DECIMAL(15, 2) NOT NULL,
    transport_allowance DECIMAL(15, 2) DEFAULT 0,
    meal_allowance DECIMAL(15, 2) DEFAULT 0,
    position_allowance DECIMAL(15, 2) DEFAULT 0,
    overtime_pay DECIMAL(15, 2) DEFAULT 0,
    other_allowance DECIMAL(15, 2) DEFAULT 0,
    
    gross_salary DECIMAL(15, 2) GENERATED ALWAYS AS (
        basic_salary + transport_allowance + meal_allowance + 
        position_allowance + overtime_pay + other_allowance
    ) STORED,
    
    -- Potongan
    bpjs_health DECIMAL(15, 2) DEFAULT 0,
    bpjs_employment DECIMAL(15, 2) DEFAULT 0,
    tax_deduction DECIMAL(15, 2) DEFAULT 0,
    late_penalty DECIMAL(15, 2) DEFAULT 0,
    absence_penalty DECIMAL(15, 2) DEFAULT 0,
    other_deduction DECIMAL(15, 2) DEFAULT 0,
    
    total_deduction DECIMAL(15, 2) GENERATED ALWAYS AS (
        bpjs_health + bpjs_employment + tax_deduction + 
        late_penalty + absence_penalty + other_deduction
    ) STORED,
    
    net_salary DECIMAL(15, 2) GENERATED ALWAYS AS (
        basic_salary + transport_allowance + meal_allowance + 
        position_allowance + overtime_pay + other_allowance -
        (bpjs_health + bpjs_employment + tax_deduction + 
         late_penalty + absence_penalty + other_deduction)
    ) STORED,
    
    -- Statistik kehadiran
    total_working_days INTEGER DEFAULT 0,
    total_present INTEGER DEFAULT 0,
    total_late INTEGER DEFAULT 0,
    total_absent INTEGER DEFAULT 0,
    total_overtime_hours DECIMAL(5, 2) DEFAULT 0,
    
    status VARCHAR(50) DEFAULT 'draft' CHECK (
        status IN ('draft', 'approved', 'paid')
    ),
    
    payment_method VARCHAR(50),
    payment_proof_url TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_payroll_slip UNIQUE (payroll_period_id, employee_id)
);

-- =====================================================
-- 7. TABLE: audit_logs (log aktivitas)
-- =====================================================
CREATE TABLE audit_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL, -- 'CREATE', 'UPDATE', 'DELETE', 'LOGIN', etc.
    table_name VARCHAR(100),
    record_id UUID,
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INDEXES untuk optimasi query
-- =====================================================
CREATE INDEX idx_employees_status ON employees(status);
CREATE INDEX idx_employees_employee_id ON employees(employee_id);
CREATE INDEX idx_attendance_employee_date ON attendance_records(employee_id, attendance_date);
CREATE INDEX idx_attendance_date ON attendance_records(attendance_date);
CREATE INDEX idx_salary_settings_employee ON salary_settings(employee_id, is_active);
CREATE INDEX idx_payroll_slips_period ON payroll_slips(payroll_period_id);
CREATE INDEX idx_payroll_slips_employee ON payroll_slips(employee_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, created_at);

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Function untuk update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger untuk auto-update updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_salary_settings_updated_at BEFORE UPDATE ON salary_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_attendance_updated_at BEFORE UPDATE ON attendance_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payroll_periods_updated_at BEFORE UPDATE ON payroll_periods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payroll_slips_updated_at BEFORE UPDATE ON payroll_slips
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE salary_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_slips ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Policies untuk users (hanya bisa lihat & edit diri sendiri, kecuali admin)
CREATE POLICY "Users can view their own data" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own data" ON users
    FOR UPDATE USING (auth.uid() = id);

-- Policies untuk employees (HRD bisa full access)
CREATE POLICY "HRD can view all employees" ON employees
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role IN ('hrd', 'admin', 'superadmin')
            AND users.is_active = true
        )
    );

CREATE POLICY "HRD can insert employees" ON employees
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role IN ('hrd', 'admin', 'superadmin')
        )
    );

CREATE POLICY "HRD can update employees" ON employees
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role IN ('hrd', 'admin', 'superadmin')
        )
    );

CREATE POLICY "HRD can delete employees" ON employees
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role IN ('hrd', 'admin', 'superadmin')
        )
    );

-- Policies untuk salary_settings (HRD bisa full access)
CREATE POLICY "HRD can manage salary settings" ON salary_settings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role IN ('hrd', 'admin', 'superadmin')
        )
    );

-- Policies untuk attendance_records (HRD bisa full access)
CREATE POLICY "HRD can manage attendance" ON attendance_records
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role IN ('hrd', 'admin', 'superadmin')
        )
    );

-- Policies untuk payroll_periods (HRD bisa full access)
CREATE POLICY "HRD can manage payroll periods" ON payroll_periods
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role IN ('hrd', 'admin', 'superadmin')
        )
    );

-- Policies untuk payroll_slips (HRD bisa full access)
CREATE POLICY "HRD can manage payroll slips" ON payroll_slips
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role IN ('hrd', 'admin', 'superadmin')
        )
    );

-- Policies untuk audit_logs (semua HRD bisa lihat)
CREATE POLICY "HRD can view audit logs" ON audit_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role IN ('hrd', 'admin', 'superadmin')
        )
    );

-- =====================================================
-- SAMPLE DATA (untuk testing)
-- =====================================================

-- Insert HRD user (password: "hrd123" - harus di-hash di aplikasi)
INSERT INTO users (email, password_hash, full_name, role) VALUES
('hrd@company.com', '$2b$10$EXAMPLE_HASH', 'HRD Manager', 'hrd'),
('admin@company.com', '$2b$10$EXAMPLE_HASH', 'Admin System', 'admin');

-- Insert sample employees
INSERT INTO employees (employee_id, full_name, email, department, position, join_date) VALUES
('EMP001', 'John Doe', 'john@company.com', 'IT', 'Developer', '2024-01-15'),
('EMP002', 'Jane Smith', 'jane@company.com', 'Finance', 'Accountant', '2024-02-01'),
('EMP003', 'Bob Johnson', 'bob@company.com', 'Marketing', 'Marketing Manager', '2024-03-10');

-- Insert salary settings
INSERT INTO salary_settings (
    employee_id, 
    basic_salary, 
    transport_allowance, 
    meal_allowance,
    overtime_rate_per_hour,
    late_penalty_per_minute,
    effective_from
)
SELECT 
    id,
    5000000, -- Rp 5 juta
    500000,  -- Rp 500 ribu
    400000,  -- Rp 400 ribu
    50000,   -- Rp 50 ribu per jam lembur
    5000,    -- Rp 5 ribu per menit telat
    '2024-01-01'
FROM employees;

-- =====================================================
-- VIEWS untuk kemudahan query
-- =====================================================

-- View: Employee dengan salary aktif
CREATE OR REPLACE VIEW v_employees_with_salary AS
SELECT 
    e.*,
    s.basic_salary,
    s.transport_allowance,
    s.meal_allowance,
    s.position_allowance,
    s.overtime_rate_per_hour,
    s.late_penalty_per_minute,
    s.absence_penalty_per_day,
    (s.basic_salary + s.transport_allowance + s.meal_allowance + s.position_allowance) as total_monthly_salary
FROM employees e
LEFT JOIN salary_settings s ON e.id = s.employee_id AND s.is_active = true
WHERE e.status = 'active';

-- View: Summary absensi per employee per bulan
CREATE OR REPLACE VIEW v_monthly_attendance_summary AS
SELECT 
    e.id as employee_id,
    e.employee_id as emp_id,
    e.full_name,
    e.department,
    DATE_TRUNC('month', a.attendance_date) as month,
    COUNT(*) as total_days,
    COUNT(*) FILTER (WHERE a.status = 'hadir') as present_days,
    COUNT(*) FILTER (WHERE a.status = 'telat') as late_days,
    COUNT(*) FILTER (WHERE a.status = 'alpha') as absent_days,
    SUM(a.late_minutes) as total_late_minutes,
    SUM(a.overtime_hours) as total_overtime_hours,
    SUM(a.late_penalty) as total_late_penalty,
    SUM(a.overtime_pay) as total_overtime_pay
FROM employees e
LEFT JOIN attendance_records a ON e.id = a.employee_id
GROUP BY e.id, e.employee_id, e.full_name, e.department, DATE_TRUNC('month', a.attendance_date);

-- =====================================================
-- STORED PROCEDURES
-- =====================================================

-- Procedure: Calculate payroll untuk periode tertentu
CREATE OR REPLACE FUNCTION calculate_payroll(p_period_id UUID)
RETURNS void AS $$
DECLARE
    v_period RECORD;
    v_employee RECORD;
    v_attendance RECORD;
BEGIN
    -- Get period details
    SELECT * INTO v_period FROM payroll_periods WHERE id = p_period_id;
    
    -- Loop through all active employees
    FOR v_employee IN 
        SELECT e.*, s.* 
        FROM employees e
        INNER JOIN salary_settings s ON e.id = s.employee_id AND s.is_active = true
        WHERE e.status = 'active'
    LOOP
        -- Calculate attendance summary
        SELECT 
            COUNT(*) FILTER (WHERE status IN ('hadir', 'telat')) as present_days,
            COUNT(*) FILTER (WHERE status = 'telat') as late_days,
            COUNT(*) FILTER (WHERE status = 'alpha') as absent_days,
            COALESCE(SUM(late_penalty), 0) as total_late_penalty,
            COALESCE(SUM(overtime_pay), 0) as total_overtime_pay,
            COALESCE(SUM(overtime_hours), 0) as total_overtime_hours
        INTO v_attendance
        FROM attendance_records
        WHERE employee_id = v_employee.id
        AND attendance_date BETWEEN v_period.period_start AND v_period.period_end;
        
        -- Insert or update payroll slip
        INSERT INTO payroll_slips (
            payroll_period_id,
            employee_id,
            basic_salary,
            transport_allowance,
            meal_allowance,
            position_allowance,
            overtime_pay,
            bpjs_health,
            bpjs_employment,
            tax_deduction,
            late_penalty,
            total_working_days,
            total_present,
            total_late,
            total_absent,
            total_overtime_hours
        ) VALUES (
            p_period_id,
            v_employee.id,
            v_employee.basic_salary,
            v_employee.transport_allowance,
            v_employee.meal_allowance,
            v_employee.position_allowance,
            v_attendance.total_overtime_pay,
            v_employee.bpjs_health,
            v_employee.bpjs_employment,
            v_employee.tax_deduction,
            v_attendance.total_late_penalty,
            EXTRACT(DAY FROM v_period.period_end - v_period.period_start),
            v_attendance.present_days,
            v_attendance.late_days,
            v_attendance.absent_days,
            v_attendance.total_overtime_hours
        )
        ON CONFLICT (payroll_period_id, employee_id) 
        DO UPDATE SET
            basic_salary = EXCLUDED.basic_salary,
            transport_allowance = EXCLUDED.transport_allowance,
            meal_allowance = EXCLUDED.meal_allowance,
            position_allowance = EXCLUDED.position_allowance,
            overtime_pay = EXCLUDED.overtime_pay,
            late_penalty = EXCLUDED.late_penalty,
            total_present = EXCLUDED.total_present,
            total_late = EXCLUDED.total_late,
            total_absent = EXCLUDED.total_absent,
            total_overtime_hours = EXCLUDED.total_overtime_hours,
            updated_at = NOW();
    END LOOP;
    
    -- Update period status
    UPDATE payroll_periods 
    SET status = 'calculated', updated_at = NOW()
    WHERE id = p_period_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON TABLE employees IS 'Master data karyawan';
COMMENT ON TABLE salary_settings IS 'Pengaturan gaji karyawan (bisa multiple dengan effective date)';
COMMENT ON TABLE attendance_records IS 'Data absensi harian karyawan';
COMMENT ON TABLE payroll_periods IS 'Periode penggajian (bulanan)';
COMMENT ON TABLE payroll_slips IS 'Slip gaji per karyawan per periode';
COMMENT ON TABLE audit_logs IS 'Log aktivitas user untuk audit trail';
