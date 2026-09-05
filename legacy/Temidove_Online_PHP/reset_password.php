<?php
/**
 * ADMIN PASSWORD RESET TOOL
 * Visit: http://localhost/temidove/reset_password.php
 * This will help you fix login issues
 */

require_once 'config.php';

$message = '';
$success = false;

// Check if form submitted
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    
    if ($action === 'reset_admin') {
        $new_password = 'admin123'; // Default password
        $hashed = password_hash($new_password, PASSWORD_BCRYPT);
        
        $stmt = $conn->prepare("UPDATE users SET password = ? WHERE username = 'admin'");
        $stmt->bind_param("s", $hashed);
        
        if ($stmt->execute()) {
            $success = true;
            $message = "✓ Admin password reset to: <strong>admin123</strong><br>You can now login!";
        } else {
            $message = "✗ Error resetting password: " . $conn->error;
        }
        $stmt->close();
    }
    
    if ($action === 'verify_users') {
        // Check if admin exists
        $result = $conn->query("SELECT id, username, email FROM users WHERE role='admin'");
        if ($result && $result->num_rows > 0) {
            $admin = $result->fetch_assoc();
            $message = "✓ Admin user exists:<br>Username: " . $admin['username'] . "<br>Email: " . $admin['email'];
        } else {
            $message = "✗ No admin user found! Will create one...";
            
            // Create admin user
            $admin_pass = password_hash('admin123', PASSWORD_BCRYPT);
            $stmt = $conn->prepare("INSERT INTO users (username, password, email, full_name, role) VALUES (?, ?, ?, ?, ?)");
            $username = 'admin';
            $email = 'admin@temidove.com';
            $full_name = 'Admin User';
            $role = 'admin';
            
            $stmt->bind_param("sssss", $username, $admin_pass, $email, $full_name, $role);
            
            if ($stmt->execute()) {
                $success = true;
                $message = "✓ Admin user created!<br>Username: admin<br>Password: admin123";
            } else {
                $message = "✗ Error creating admin: " . $conn->error;
            }
            $stmt->close();
        }
    }
    
    if ($action === 'test_login') {
        $username = sanitize($_POST['test_username'] ?? '');
        $password = $_POST['test_password'] ?? '';
        
        if (empty($username) || empty($password)) {
            $message = "✗ Please enter both username and password";
        } else {
            $stmt = $conn->prepare("SELECT id, password FROM users WHERE username = ?");
            $stmt->bind_param("s", $username);
            $stmt->execute();
            $result = $stmt->get_result();
            
            if ($result->num_rows === 1) {
                $user = $result->fetch_assoc();
                if (password_verify($password, $user['password'])) {
                    $success = true;
                    $message = "✓ Login test PASSED! Credentials are correct.";
                } else {
                    $message = "✗ Password is INCORRECT for user '$username'";
                }
            } else {
                $message = "✗ User '$username' not found in database";
            }
            $stmt->close();
        }
    }
}

// Get all users
$users_result = $conn->query("SELECT id, username, email, full_name, role FROM users");
$users = [];
if ($users_result) {
    while ($row = $users_result->fetch_assoc()) {
        $users[] = $row;
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Password Reset - Temidove</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #f0f4f8 0%, #e0e7ff 100%);
            min-height: 100vh;
            padding: 30px 20px;
        }

        .container {
            max-width: 900px;
            margin: 0 auto;
        }

        .header {
            background: linear-gradient(135deg, #1e3a8a 0%, #06b6d4 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            text-align: center;
        }

        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }

        .card {
            background: white;
            border-radius: 10px;
            padding: 25px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }

        .card h2 {
            color: #1e3a8a;
            font-size: 20px;
            margin-bottom: 15px;
            border-bottom: 2px solid #06b6d4;
            padding-bottom: 10px;
        }

        .message {
            padding: 15px;
            border-radius: 6px;
            margin-bottom: 20px;
            font-size: 14px;
            line-height: 1.6;
        }

        .message.success {
            background: #dcfce7;
            color: #166534;
            border-left: 4px solid #10b981;
        }

        .message.error {
            background: #fee2e2;
            color: #991b1b;
            border-left: 4px solid #dc2626;
        }

        .btn-group {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 10px;
            margin-bottom: 20px;
        }

        button {
            padding: 12px 20px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            transition: all 0.3s;
        }

        .btn-reset {
            background: linear-gradient(135deg, #1e3a8a 0%, #06b6d4 100%);
            color: white;
        }

        .btn-reset:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(6, 182, 212, 0.3);
        }

        .btn-verify {
            background: #f0f9ff;
            color: #0c4a6e;
            border: 2px solid #06b6d4;
        }

        .btn-verify:hover {
            background: #06b6d4;
            color: white;
        }

        .form-group {
            margin-bottom: 15px;
        }

        label {
            display: block;
            margin-bottom: 6px;
            color: #1e3a8a;
            font-weight: 600;
            font-size: 13px;
        }

        input {
            width: 100%;
            padding: 10px;
            border: 1px solid #e0e7ff;
            border-radius: 6px;
            font-size: 13px;
        }

        input:focus {
            outline: none;
            border-color: #06b6d4;
            box-shadow: 0 0 0 3px rgba(6, 182, 212, 0.1);
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }

        thead {
            background: #f1f5f9;
        }

        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #e0e7ff;
            font-size: 13px;
        }

        th {
            color: #1e3a8a;
            font-weight: 600;
        }

        .role-badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 600;
        }

        .role-admin {
            background: #fef3c7;
            color: #92400e;
        }

        .role-staff {
            background: #dbeafe;
            color: #1e40af;
        }

        .info-box {
            background: #f0f9ff;
            border-left: 4px solid #06b6d4;
            padding: 15px;
            border-radius: 6px;
            margin-bottom: 15px;
            font-size: 13px;
            color: #0c4a6e;
            line-height: 1.6;
        }

        .warning-box {
            background: #fffbeb;
            border-left: 4px solid #f59e0b;
            padding: 15px;
            border-radius: 6px;
            margin-bottom: 15px;
            font-size: 13px;
            color: #92400e;
            line-height: 1.6;
        }

        .section-title {
            font-size: 16px;
            color: #1e3a8a;
            font-weight: 600;
            margin: 20px 0 15px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔑 Admin Password Reset Tool</h1>
            <p>Fix login issues and reset credentials</p>
        </div>

        <?php if (!empty($message)): ?>
            <div class="message <?php echo $success ? 'success' : 'error'; ?>">
                <?php echo $message; ?>
            </div>
        <?php endif; ?>

        <!-- Quick Fix -->
        <div class="card">
            <h2>⚡ Quick Fix - Reset Admin Password</h2>
            <div class="warning-box">
                <strong>Having login problems?</strong><br>
                Click the button below to reset the admin password to: <strong>admin123</strong>
            </div>

            <form method="POST">
                <input type="hidden" name="action" value="reset_admin">
                <button type="submit" class="btn-reset" style="width: 100%;">✓ Reset Admin Password to admin123</button>
            </form>

            <p style="margin-top: 15px; color: #64748b; font-size: 13px;">
                After clicking, you'll be able to login with:<br>
                <strong>Username:</strong> admin<br>
                <strong>Password:</strong> admin123
            </p>
        </div>

        <!-- Test Login -->
        <div class="card">
            <h2>🧪 Test Login Credentials</h2>
            <div class="info-box">
                Want to verify if your login will work? Enter credentials below and we'll test them.
            </div>

            <form method="POST">
                <div class="form-group">
                    <label for="test_username">Username</label>
                    <input type="text" id="test_username" name="test_username" required>
                </div>

                <div class="form-group">
                    <label for="test_password">Password</label>
                    <input type="password" id="test_password" name="test_password" required>
                </div>

                <input type="hidden" name="action" value="test_login">
                <button type="submit" class="btn-reset" style="width: 100%;">🔍 Test These Credentials</button>
            </form>
        </div>

        <!-- Verify Users -->
        <div class="card">
            <h2>👥 Current Users in Database</h2>

            <?php if (empty($users)): ?>
                <div class="warning-box">
                    ⚠️ No users found in database!
                </div>

                <form method="POST">
                    <input type="hidden" name="action" value="verify_users">
                    <button type="submit" class="btn-reset" style="width: 100%;">✓ Create Default Admin User</button>
                </form>
            <?php else: ?>
                <table>
                    <thead>
                        <tr>
                            <th>Username</th>
                            <th>Email</th>
                            <th>Full Name</th>
                            <th>Role</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($users as $user): ?>
                            <tr>
                                <td><strong><?php echo htmlspecialchars($user['username']); ?></strong></td>
                                <td><?php echo htmlspecialchars($user['email']); ?></td>
                                <td><?php echo htmlspecialchars($user['full_name']); ?></td>
                                <td>
                                    <span class="role-badge role-<?php echo $user['role']; ?>">
                                        <?php echo ucfirst($user['role']); ?>
                                    </span>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>

                <p style="margin-top: 15px; color: #64748b; font-size: 13px;">
                    ✓ Users found in database. Try logging in with the default credentials above.
                </p>
            <?php endif; ?>
        </div>

        <!-- Troubleshooting -->
        <div class="card">
            <h2>🔧 Troubleshooting Steps</h2>

            <div class="section-title">If reset doesn't work:</div>

            <ol style="margin-left: 20px; color: #475569; font-size: 13px; line-height: 1.8;">
                <li><strong>Clear your browser cache:</strong>
                    <ul style="margin: 5px 0 0 20px;">
                        <li>Press Ctrl+Shift+Delete</li>
                        <li>Clear all cookies and cache</li>
                        <li>Try login again</li>
                    </ul>
                </li>
                <li><strong>Try a different browser:</strong> Chrome, Firefox, or Edge</li>
                <li><strong>Check browser console:</strong>
                    <ul style="margin: 5px 0 0 20px;">
                        <li>Press F12 to open Developer Tools</li>
                        <li>Click "Console" tab</li>
                        <li>Check for JavaScript errors</li>
                    </ul>
                </li>
                <li><strong>Verify database:</strong>
                    <ul style="margin: 5px 0 0 20px;">
                        <li>Go to http://localhost/phpmyadmin</li>
                        <li>Check temidove_db database exists</li>
                        <li>Check users table has records</li>
                    </ul>
                </li>
                <li><strong>Restart WAMP:</strong>
                    <ul style="margin: 5px 0 0 20px;">
                        <li>Click WAMP icon → Stop All Services</li>
                        <li>Wait 10 seconds</li>
                        <li>Click WAMP icon → Start All Services</li>
                        <li>Wait for green icon</li>
                    </ul>
                </li>
            </ol>
        </div>

        <!-- Login Instructions -->
        <div class="card">
            <h2>📝 Login Instructions</h2>

            <div class="info-box">
                <strong>After resetting password, go to:</strong><br>
                <code style="background: #f1f5f9; padding: 2px 6px; border-radius: 3px;">http://localhost/temidove/login.php</code>
                <br><br>
                <strong>Enter these credentials:</strong><br>
                Username: <code>admin</code><br>
                Password: <code>admin123</code>
                <br><br>
                <strong>You should see:</strong><br>
                ✓ "Welcome" message (if credentials are correct)<br>
                ✓ Redirect to dashboard<br>
                ✓ Access to all admin features
            </div>
        </div>

        <!-- Next Steps -->
        <div class="card" style="background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%); border-left: 4px solid #06b6d4;">
            <h2>✓ Next Steps</h2>

            <ol style="margin-left: 20px; color: #0c4a6e; font-size: 13px; line-height: 1.8;">
                <li>Click "Reset Admin Password" button above</li>
                <li>Wait for success message</li>
                <li>Go to <code>http://localhost/temidove/login.php</code></li>
                <li>Login with: admin / admin123</li>
                <li>You should see the dashboard</li>
                <li><strong>Important:</strong> Change admin password immediately!
                    <ul style="margin: 5px 0 0 20px;">
                        <li>In dashboard, edit the admin user</li>
                        <li>Set a new, secure password</li>
                        <li>Save changes</li>
                    </ul>
                </li>
            </ol>
        </div>

        <div style="text-align: center; margin-top: 30px; color: #64748b; font-size: 13px;">
            <p>Still having issues?</p>
            <p>
                <a href="login.php" style="color: #06b6d4; text-decoration: none; font-weight: 600;">← Back to Login</a> | 
                <a href="index.php" style="color: #06b6d4; text-decoration: none; font-weight: 600;">Go to Home →</a>
            </p>
        </div>
    </div>
</body>
</html>
