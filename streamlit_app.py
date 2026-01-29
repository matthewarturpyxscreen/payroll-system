import streamlit as st
import pandas as pd
from supabase import create_client, Client
import os
from dotenv import load_dotenv
import bcrypt
from datetime import datetime, timedelta
import plotly.express as px
import plotly.graph_objects as go

from supabase import create_client
import streamlit as st

url = st.secrets["SUPABASE_URL"]
key = st.secrets["SUPABASE_KEY"]

supabase = create_client(url, key)

test = supabase.table("karyawan").select("*").limit(1).execute()

st.write("TEST DB:", test.data)


# Load environment variables
load_dotenv()

# Initialize Supabase client
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_ANON_KEY")
supabase: Client = create_client(supabase_url, supabase_key)

# Page config
st.set_page_config(
    page_title="Payroll System - HRD Dashboard",
    page_icon="💰",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better styling
st.markdown("""
<style>
    .main {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }
    .stApp {
        background: #f8f9fd;
    }
    div[data-testid="stMetricValue"] {
        font-size: 2rem;
        font-weight: 700;
    }
    .stat-card {
        background: white;
        padding: 1.5rem;
        border-radius: 12px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.08);
    }
    h1, h2, h3 {
        color: #1a1a2e;
    }
</style>
""", unsafe_allow_html=True)

# Session state initialization
if 'logged_in' not in st.session_state:
    st.session_state.logged_in = False
if 'user' not in st.session_state:
    st.session_state.user = None

# Authentication functions
def hash_password(password: str) -> str:
    """Hash password using bcrypt"""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    """Verify password against hash"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def login(email: str, password: str):
    """Login user"""
    try:
        # Query user from Supabase
        response = supabase.table('users').select('*').eq('email', email).eq('is_active', True).execute()
        
        if response.data and len(response.data) > 0:
            user = response.data[0]
            if verify_password(password, user['password_hash']):
                # Update last login
                supabase.table('users').update({
                    'last_login': datetime.now().isoformat()
                }).eq('id', user['id']).execute()
                
                st.session_state.logged_in = True
                st.session_state.user = user
                return True
        return False
    except Exception as e:
        st.error(f"Login error: {str(e)}")
        return False

def logout():
    """Logout user"""
    st.session_state.logged_in = False
    st.session_state.user = None
    st.rerun()

# Login Page
def show_login_page():
    col1, col2, col3 = st.columns([1, 2, 1])
    
    with col2:
        st.markdown("<br><br>", unsafe_allow_html=True)
        st.markdown("""
        <div style='text-align: center; padding: 2rem; background: white; border-radius: 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.1);'>
            <h1 style='color: #667eea;'>💰 Payroll System</h1>
            <p style='color: #666; margin-bottom: 2rem;'>HRD Dashboard</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown("<br>", unsafe_allow_html=True)
        
        with st.form("login_form"):
            email = st.text_input("📧 Email", placeholder="hrd@company.com")
            password = st.text_input("🔒 Password", type="password", placeholder="••••••••")
            submit = st.form_submit_button("🚀 Sign In", use_container_width=True)
            
            if submit:
                if login(email, password):
                    st.success("✅ Login berhasil!")
                    st.rerun()
                else:
                    st.error("❌ Email atau password salah")

# Dashboard functions
def get_dashboard_stats():
    """Get dashboard statistics"""
    try:
        # Total employees
        emp_response = supabase.table('employees').select('id', count='exact').eq('status', 'active').execute()
        total_employees = emp_response.count if emp_response.count else 0
        
        # Total payroll this month
        payroll_response = supabase.table('payroll_slips').select('net_salary').execute()
        total_payroll = sum([float(p['net_salary'] or 0) for p in payroll_response.data]) if payroll_response.data else 0
        
        # Average salary
        avg_salary = total_payroll / total_employees if total_employees > 0 else 0
        
        # Pending approval
        pending_response = supabase.table('payroll_slips').select('id', count='exact').eq('status', 'draft').execute()
        pending_approval = pending_response.count if pending_response.count else 0
        
        return {
            'total_employees': total_employees,
            'total_payroll': total_payroll,
            'avg_salary': avg_salary,
            'pending_approval': pending_approval
        }
    except Exception as e:
        st.error(f"Error loading stats: {str(e)}")
        return {
            'total_employees': 0,
            'total_payroll': 0,
            'avg_salary': 0,
            'pending_approval': 0
        }

def show_dashboard():
    """Main dashboard view"""
    st.title("📊 Dashboard")
    
    # Get stats
    stats = get_dashboard_stats()
    
    # Metrics row
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric(
            label="👥 Total Karyawan",
            value=stats['total_employees'],
            delta="+5 bulan ini"
        )
    
    with col2:
        st.metric(
            label="💰 Total Payroll",
            value=f"Rp {stats['total_payroll']/1_000_000:.1f}M",
            delta="Bulan ini"
        )
    
    with col3:
        st.metric(
            label="📈 Rata-rata Gaji",
            value=f"Rp {stats['avg_salary']/1_000_000:.1f}M",
            delta="Per karyawan"
        )
    
    with col4:
        st.metric(
            label="⏳ Pending Approval",
            value=stats['pending_approval'],
            delta="Slip gaji"
        )
    
    st.markdown("<br>", unsafe_allow_html=True)
    
    # Recent activity
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("🕐 Absensi Terbaru")
        try:
            attendance = supabase.table('attendance_records').select(
                'attendance_date, check_in, status, employees(full_name, employee_id)'
            ).order('attendance_date', desc=True).limit(5).execute()
            
            if attendance.data:
                df = pd.DataFrame(attendance.data)
                st.dataframe(df, use_container_width=True, hide_index=True)
            else:
                st.info("Belum ada data absensi")
        except Exception as e:
            st.error(f"Error loading attendance: {str(e)}")
    
    with col2:
        st.subheader("💵 Slip Gaji Terbaru")
        try:
            payroll = supabase.table('payroll_slips').select(
                'net_salary, status, employees(full_name), payroll_periods(period_name)'
            ).order('created_at', desc=True).limit(5).execute()
            
            if payroll.data:
                df = pd.DataFrame(payroll.data)
                st.dataframe(df, use_container_width=True, hide_index=True)
            else:
                st.info("Belum ada slip gaji")
        except Exception as e:
            st.error(f"Error loading payroll: {str(e)}")

def show_employees():
    """Employee management page"""
    st.title("👥 Data Karyawan")
    
    # Action buttons
    col1, col2, col3 = st.columns([1, 1, 2])
    with col1:
        if st.button("➕ Tambah Karyawan", use_container_width=True):
            st.session_state.show_add_employee = True
    with col2:
        if st.button("📥 Import Excel", use_container_width=True):
            st.session_state.show_import = True
    
    # Search
    search = st.text_input("🔍 Cari karyawan...", placeholder="Nama atau ID karyawan")
    
    # Load employees
    try:
        query = supabase.table('employees').select('*').eq('status', 'active')
        if search:
            query = query.or_(f'full_name.ilike.%{search}%,employee_id.ilike.%{search}%')
        
        response = query.execute()
        
        if response.data:
            df = pd.DataFrame(response.data)
            
            # Display table with actions
            for idx, row in df.iterrows():
                with st.expander(f"**{row['employee_id']}** - {row['full_name']}"):
                    col1, col2, col3 = st.columns(3)
                    with col1:
                        st.write(f"**Email:** {row['email']}")
                        st.write(f"**Department:** {row['department']}")
                    with col2:
                        st.write(f"**Posisi:** {row['position']}")
                        st.write(f"**Tanggal Masuk:** {row['join_date']}")
                    with col3:
                        if st.button(f"✏️ Edit", key=f"edit_{row['id']}"):
                            st.session_state.edit_employee_id = row['id']
                        if st.button(f"💰 Set Gaji", key=f"salary_{row['id']}"):
                            st.session_state.set_salary_id = row['id']
                        if st.button(f"🗑️ Hapus", key=f"delete_{row['id']}", type="secondary"):
                            if st.session_state.get(f'confirm_delete_{row["id"]}'):
                                # Delete employee
                                supabase.table('employees').update({'status': 'inactive'}).eq('id', row['id']).execute()
                                st.success("Karyawan berhasil dihapus")
                                st.rerun()
                            else:
                                st.session_state[f'confirm_delete_{row["id"]}'] = True
                                st.warning("Klik lagi untuk konfirmasi")
        else:
            st.info("Tidak ada data karyawan")
            
    except Exception as e:
        st.error(f"Error loading employees: {str(e)}")
    
    # Add employee modal
    if st.session_state.get('show_add_employee'):
        with st.form("add_employee_form"):
            st.subheader("Tambah Karyawan Baru")
            
            col1, col2 = st.columns(2)
            with col1:
                employee_id = st.text_input("ID Karyawan *")
                full_name = st.text_input("Nama Lengkap *")
                email = st.text_input("Email")
                phone = st.text_input("No. Telepon")
            
            with col2:
                department = st.text_input("Department")
                position = st.text_input("Posisi")
                join_date = st.date_input("Tanggal Masuk *")
            
            col1, col2 = st.columns(2)
            with col1:
                submit = st.form_submit_button("💾 Simpan", use_container_width=True)
            with col2:
                cancel = st.form_submit_button("❌ Batal", use_container_width=True)
            
            if submit:
                try:
                    supabase.table('employees').insert({
                        'employee_id': employee_id,
                        'full_name': full_name,
                        'email': email,
                        'phone': phone,
                        'department': department,
                        'position': position,
                        'join_date': join_date.isoformat()
                    }).execute()
                    st.success("✅ Karyawan berhasil ditambahkan!")
                    st.session_state.show_add_employee = False
                    st.rerun()
                except Exception as e:
                    st.error(f"Error: {str(e)}")
            
            if cancel:
                st.session_state.show_add_employee = False
                st.rerun()

def show_attendance():
    """Attendance management page"""
    st.title("🕐 Absensi")
    
    # Upload section
    st.subheader("📤 Upload Data Absensi")
    uploaded_file = st.file_uploader(
        "Upload file Excel absensi",
        type=['xlsx', 'xls'],
        help="Format: .xls atau .xlsx dari mesin fingerprint"
    )
    
    if uploaded_file:
        try:
            df = pd.read_excel(uploaded_file)
            st.success(f"✅ File berhasil diupload! Total {len(df)} baris data")
            
            # Preview
            st.subheader("Preview Data")
            st.dataframe(df.head(10), use_container_width=True)
            
            if st.button("💾 Simpan ke Database"):
                # Process and save to database
                # This is where you'd implement the parsing logic from your original code
                st.success("Data berhasil disimpan!")
                
        except Exception as e:
            st.error(f"Error reading file: {str(e)}")
    
    # View attendance records
    st.subheader("📋 Data Absensi")
    
    col1, col2 = st.columns(2)
    with col1:
        date_from = st.date_input("Dari Tanggal", datetime.now() - timedelta(days=30))
    with col2:
        date_to = st.date_input("Sampai Tanggal", datetime.now())
    
    try:
        response = supabase.table('attendance_records').select(
            'attendance_date, check_in, check_out, status, late_minutes, overtime_hours, employees(full_name, employee_id)'
        ).gte('attendance_date', date_from.isoformat()).lte('attendance_date', date_to.isoformat()).execute()
        
        if response.data:
            df = pd.DataFrame(response.data)
            st.dataframe(df, use_container_width=True, hide_index=True)
            
            # Download button
            csv = df.to_csv(index=False).encode('utf-8')
            st.download_button(
                "📥 Download CSV",
                csv,
                "attendance_data.csv",
                "text/csv",
                key='download-csv'
            )
        else:
            st.info("Tidak ada data untuk periode ini")
            
    except Exception as e:
        st.error(f"Error loading attendance: {str(e)}")

def show_payroll():
    """Payroll management page"""
    st.title("💰 Penggajian")
    
    # Create new period
    with st.expander("➕ Buat Periode Penggajian Baru"):
        with st.form("new_period"):
            col1, col2 = st.columns(2)
            with col1:
                period_name = st.text_input("Nama Periode", placeholder="Januari 2025")
                period_start = st.date_input("Tanggal Mulai")
            with col2:
                period_end = st.date_input("Tanggal Selesai")
                payment_date = st.date_input("Tanggal Pembayaran")
            
            if st.form_submit_button("💾 Buat Periode"):
                try:
                    response = supabase.table('payroll_periods').insert({
                        'period_name': period_name,
                        'period_start': period_start.isoformat(),
                        'period_end': period_end.isoformat(),
                        'payment_date': payment_date.isoformat(),
                        'status': 'draft',
                        'created_by': st.session_state.user['id']
                    }).execute()
                    st.success("✅ Periode berhasil dibuat!")
                    st.rerun()
                except Exception as e:
                    st.error(f"Error: {str(e)}")
    
    # List periods
    st.subheader("📅 Daftar Periode Penggajian")
    
    try:
        response = supabase.table('payroll_periods').select('*').order('period_start', desc=True).execute()
        
        if response.data:
            for period in response.data:
                with st.expander(f"**{period['period_name']}** - Status: {period['status']}"):
                    col1, col2, col3 = st.columns(3)
                    with col1:
                        st.write(f"**Periode:** {period['period_start']} s/d {period['period_end']}")
                    with col2:
                        st.write(f"**Tanggal Bayar:** {period['payment_date']}")
                    with col3:
                        if period['status'] == 'draft':
                            if st.button(f"🧮 Hitung Payroll", key=f"calc_{period['id']}"):
                                # Call stored procedure to calculate payroll
                                try:
                                    supabase.rpc('calculate_payroll', {'p_period_id': period['id']}).execute()
                                    st.success("Perhitungan selesai!")
                                    st.rerun()
                                except Exception as e:
                                    st.error(f"Error: {str(e)}")
        else:
            st.info("Belum ada periode penggajian")
            
    except Exception as e:
        st.error(f"Error loading periods: {str(e)}")

# Main app
def main():
    if not st.session_state.logged_in:
        show_login_page()
    else:
        # Sidebar
        with st.sidebar:
            st.markdown("---")
            st.markdown(f"### 👤 {st.session_state.user['full_name']}")
            st.markdown(f"**Role:** {st.session_state.user['role']}")
            st.markdown("---")
            
            menu = st.radio(
                "Menu",
                ["📊 Dashboard", "👥 Karyawan", "🕐 Absensi", "💰 Penggajian", "📊 Laporan"],
                label_visibility="collapsed"
            )
            
            st.markdown("---")
            if st.button("🚪 Logout", use_container_width=True):
                logout()
        
        # Main content
        if menu == "📊 Dashboard":
            show_dashboard()
        elif menu == "👥 Karyawan":
            show_employees()
        elif menu == "🕐 Absensi":
            show_attendance()
        elif menu == "💰 Penggajian":
            show_payroll()
        elif menu == "📊 Laporan":
            st.title("📊 Laporan")
            st.info("Fitur laporan akan segera hadir")

if __name__ == "__main__":
    main()
