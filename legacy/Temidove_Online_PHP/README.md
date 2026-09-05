# Temidove Smart Solutions - Online Training Management System

A complete full-stack PHP application for managing course inquiries and student enrollments with a professional dashboard for staff and administrators.

## Features

✅ **Public Registration System** - Clients can submit course inquiries online  
✅ **Professional Dashboard** - Staff and admin interface for managing registrations  
✅ **Status Tracking** - Track students as "Waiting" or "Started"  
✅ **Multi-course Support** - 11 different courses available  
✅ **Staff Assignment** - Assign students to instructors  
✅ **Search & Filters** - Powerful filtering by course, status, and student name  
✅ **Responsive Design** - Works on desktop, tablet, and mobile  
✅ **Professional Branding** - Integrated with Temidove brand colors (blue & cyan)  

---

## System Requirements

- **Server**: Apache (included with WAMP)
- **PHP**: 7.4 or higher
- **Database**: MySQL 5.7 or higher (included with WAMP)
- **Browser**: Chrome, Firefox, Safari, Edge (modern versions)

---

## Installation Guide for WAMP

### Step 1: Download WAMP (if not already installed)

1. Visit https://www.wampserver.com/
2. Download the latest WAMP64 or WAMP32 version
3. Install WAMP to your preferred location (e.g., `C:\wamp64`)

### Step 2: Extract Project Files

1. Navigate to your WAMP installation folder
2. Go to: `C:\wamp64\www` (or wherever you installed WAMP)
3. Create a new folder called `temidove`
4. Extract all the project files into this folder

Your folder structure should look like:
```
C:\wamp64\www\temidove\
├── config.php
├── index.php
├── login.php
├── register.php
├── dashboard.php
├── logout.php
├── temidove_database.sql
└── README.md
```

### Step 3: Start WAMP

1. Click the **WAMP icon** in your system tray
2. Click **Start All Services**
3. Wait for the WAMP icon to turn green (all services running)

### Step 4: Create Database

#### Option A: Using phpMyAdmin (Easiest)

1. Open your browser and go to: `http://localhost/phpmyadmin`
2. Click on the **Databases** tab
3. Under "Create new database", enter: `temidove_db`
4. Click **Create**
5. Click on the newly created `temidove_db` database
6. Click the **Import** tab
7. Click **Choose File** and select `temidove_database.sql`
8. Click **Import**

#### Option B: Using MySQL Command Line

1. Open Command Prompt and navigate to your MySQL bin folder:
   ```
   cd C:\wamp64\bin\mysql\mysql5.7.31\bin
   ```
   (version number may differ)

2. Log in to MySQL:
   ```
   mysql -u root -p
   ```
   (Just press Enter when asked for password - WAMP has no password by default)

3. Create the database:
   ```sql
   CREATE DATABASE temidove_db;
   USE temidove_db;
   SOURCE C:/wamp64/www/temidove/temidove_database.sql;
   ```

### Step 5: Access the Application

1. Open your web browser
2. Go to: `http://localhost/temidove`
3. You should see the home page

---

## Default Login Credentials

**Username:** `admin`  
**Password:** `admin123`

⚠️ **IMPORTANT:** Change these credentials immediately after first login!

---

## First-Time Setup Guide

### 1. Log In as Admin
- Go to `http://localhost/temidove/login.php`
- Enter username: `admin`
- Enter password: `admin123`

### 2. Dashboard Overview
You'll see:
- **Statistics Cards** - Total inquiries, waiting, started, completed counts
- **Filter Section** - Search by name, filter by status and course
- **Registration Table** - All student inquiries with status indicators

### 3. Managing Student Registrations

#### View Details
- Click the **👁️ eye icon** to see full student details
- Shows contact info, course, status, notes, and assignment

#### Update Status
- Select status from the dropdown in the table
- Options: Waiting → Started → Completed/Cancelled

#### Assign to Staff
- Click the **✏️ pencil icon** to open edit form
- Select staff member from dropdown
- Add notes about the student
- Set start date if applicable
- Click "Save Changes"

### 4. Client Inquiry Form
- Direct clients to: `http://localhost/temidove/register.php`
- They can submit course inquiries
- You'll see new inquiries in the dashboard immediately

---

## Customization Guide

### Change Admin Password

1. Log in to phpMyAdmin
2. Go to database `temidove_db` → table `users`
3. Click Edit on the admin user
4. For the password field, use this PHP code to generate a hash:

```php
<?php
echo password_hash('your_new_password_here', PASSWORD_BCRYPT);
?>
```

5. Copy the hash and paste it in the password field
6. Click Save

### Add More Staff Members

1. In the dashboard, go to phpMyAdmin
2. In database `temidove_db` → table `users`
3. Click **Insert**
4. Fill in the details:
   - username: (unique username)
   - password: (use hash from above)
   - email: (their email)
   - full_name: (their name)
   - role: select "staff"

### Add or Edit Courses

1. In phpMyAdmin → `temidove_db` → table `courses`
2. To edit: Click Edit on the course row
3. To add: Click **Insert** and fill in details:
   - course_name: (e.g., "Advanced Python Programming")
   - description: (course details)
   - price: (in UGX currency)
   - duration_weeks: (number of weeks)

---

## File Descriptions

| File | Purpose |
|------|---------|
| `config.php` | Database connection and configuration |
| `index.php` | Public home page |
| `login.php` | Staff/Admin login page |
| `register.php` | Public course inquiry form |
| `dashboard.php` | Main admin/staff dashboard |
| `logout.php` | Logout functionality |
| `temidove_database.sql` | Database structure and initial data |

---

## Troubleshooting

### Issue: Can't access the website
**Solution:**
1. Check if WAMP is running (icon should be green)
2. Ensure PHP is enabled
3. Check folder is in correct location: `C:\wamp64\www\temidove`
4. Clear browser cache and try again

### Issue: Database connection error
**Solution:**
1. Ensure MySQL service is running
2. Verify `temidove_db` database exists
3. Check that the database import was successful
4. Restart WAMP services

### Issue: Login doesn't work
**Solution:**
1. Verify `admin` user exists in phpMyAdmin
2. Check password is correct (case-sensitive)
3. Clear browser cookies
4. Try in private/incognito browser window

### Issue: Students can't submit inquiries
**Solution:**
1. Check courses are in database
2. Ensure `register.php` is in the correct folder
3. Check database permissions
4. Look for PHP error logs in WAMP folder

---

## Security Notes

⚠️ **For Production Use:**
1. Change all default passwords
2. Use HTTPS (SSL certificate)
3. Set up regular database backups
4. Move sensitive files outside web root
5. Implement rate limiting on forms
6. Set up user authentication logging
7. Use environment variables for database credentials

---

## Database Schema

### users table
- Stores admin and staff login credentials
- Fields: id, username, password (hashed), email, full_name, role

### courses table
- All available courses
- Fields: id, course_name, description, price, duration_weeks

### registrations table
- Student inquiry and enrollment records
- Fields: id, first_name, last_name, email, phone, course_id, status, assigned_to, notes, start_date

---

## Support & Maintenance

### Backup Your Data
Regularly backup your database:
1. In phpMyAdmin, select `temidove_db`
2. Click **Export**
3. Choose "SQL" format
4. Click **Go**

### Check Logs
WAMP logs are located in:
- `C:\wamp64\logs\apache\access.log`
- `C:\wamp64\logs\mysql\error.log`

---

## Advanced Configuration

### Change Application URL
If you want to access it as `http://localhost:8080/temidove`:
1. In WAMP menu → Apache → Apache modules → Toggle `mod_rewrite`
2. Restart WAMP

### Increase Upload Limits
In `php.ini`:
1. Find `upload_max_filesize` and `post_max_size`
2. Increase values as needed
3. Restart WAMP

---

## Version History

**Version 1.0** - Initial Release
- Core registration and dashboard functionality
- Staff assignment system
- Status tracking
- Responsive design

---

## Contact & Support

For issues or questions about this application, contact your development team.

**Built with:** PHP, MySQL, HTML5, CSS3, JavaScript  
**Framework:** Vanilla PHP (No external dependencies)

---

**Last Updated:** January 2024  
**Compatibility:** Windows, Mac, Linux (with WAMP equivalents)

