<?php
/**
 * Temidove Smart Solutions - System Check
 * Run this file to verify your installation: http://localhost/temidove/check.php
 */

$errors = [];
$warnings = [];
$success = [];

// Check PHP version
$php_version = phpversion();
if (version_compare($php_version, '7.4', '<')) {
    $errors[] = "PHP version is $php_version. Minimum required: 7.4.0";
} else {
    $success[] = "PHP version: $php_version ✓";
}

// Check required PHP extensions
$required_extensions = ['mysqli', 'json', 'session'];
foreach ($required_extensions as $ext) {
    if (!extension_loaded($ext)) {
        $errors[] = "Required extension '$ext' is not loaded";
    } else {
        $success[] = "PHP extension '$ext' is loaded ✓";
    }
}

// Check file permissions
$files_to_check = [
    'config.php',
    'index.php',
    'login.php',
    'register.php',
    'dashboard.php',
    'logout.php'
];

foreach ($files_to_check as $file) {
    if (!file_exists($file)) {
        $errors[] = "File '$file' not found";
    } else {
        if (!is_readable($file)) {
            $warnings[] = "File '$file' is not readable";
        } else {
            $success[] = "File '$file' found and readable ✓";
        }
    }
}

// Check database connection
$db_host = 'localhost';
$db_user = 'root';
$db_pass = '';
$db_name = 'temidove_db';

$conn = @mysqli_connect($db_host, $db_user, $db_pass, $db_name);

if ($conn === false) {
    $conn = @mysqli_connect($db_host, $db_user, $db_pass);
    if ($conn === false) {
        $errors[] = "Cannot connect to MySQL server. Error: " . mysqli_connect_error();
    } else {
        $errors[] = "Database '$db_name' not found. Import temidove_database.sql to create it.";
        mysqli_close($conn);
    }
} else {
    // Check tables
    $tables = ['users', 'courses', 'registrations'];
    foreach ($tables as $table) {
        $result = mysqli_query($conn, "SHOW TABLES LIKE '$table'");
        if (mysqli_num_rows($result) === 0) {
            $errors[] = "Table '$table' not found in database";
        } else {
            $success[] = "Database table '$table' exists ✓";
        }
    }
    
    // Check if we can read data
    $result = mysqli_query($conn, "SELECT COUNT(*) as count FROM users");
    if ($result) {
        $row = mysqli_fetch_assoc($result);
        $success[] = "Database connection successful ✓";
        $success[] = "Users table has {$row['count']} record(s)";
    }
    
    mysqli_close($conn);
}

// Check session support
if (function_exists('session_start')) {
    $success[] = "PHP sessions are supported ✓";
} else {
    $errors[] = "PHP sessions are not supported";
}

// Check directory structure
$directories = [
    getcwd() => 'Main directory'
];

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Check - Temidove Smart Solutions</title>
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
            max-width: 800px;
            margin: 0 auto;
        }

        .header {
            background: linear-gradient(135deg, #1e3a8a 0%, #06b6d4 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            text-align: center;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
        }

        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }

        .check-card {
            background: white;
            border-radius: 10px;
            padding: 25px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }

        .check-section h2 {
            color: #1e3a8a;
            font-size: 18px;
            margin-bottom: 15px;
            border-bottom: 2px solid #06b6d4;
            padding-bottom: 10px;
        }

        .check-item {
            padding: 10px 0;
            display: flex;
            align-items: flex-start;
            gap: 10px;
        }

        .check-icon {
            font-size: 20px;
            min-width: 25px;
        }

        .check-text {
            flex: 1;
        }

        .success-message {
            color: #16a34a;
            font-weight: 600;
        }

        .error-message {
            color: #dc2626;
            font-weight: 600;
        }

        .warning-message {
            color: #f59e0b;
            font-weight: 600;
        }

        .summary {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 15px;
            margin-bottom: 20px;
        }

        .summary-box {
            background: white;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
        }

        .summary-number {
            font-size: 28px;
            font-weight: 700;
            margin-bottom: 5px;
        }

        .summary-label {
            font-size: 12px;
            color: #64748b;
            text-transform: uppercase;
            font-weight: 600;
        }

        .success-box .summary-number { color: #10b981; }
        .error-box .summary-number { color: #dc2626; }
        .warning-box .summary-number { color: #f59e0b; }

        .status-banner {
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            font-weight: 600;
            text-align: center;
        }

        .status-good {
            background: #dcfce7;
            color: #166534;
            border-left: 4px solid #10b981;
        }

        .status-bad {
            background: #fee2e2;
            color: #991b1b;
            border-left: 4px solid #dc2626;
        }

        .next-steps {
            background: #f0f9ff;
            border-left: 4px solid #06b6d4;
            padding: 15px;
            border-radius: 6px;
            margin-top: 20px;
        }

        .next-steps h3 {
            color: #0c4a6e;
            margin-bottom: 10px;
            font-size: 14px;
        }

        .next-steps ol {
            margin-left: 20px;
            color: #0c4a6e;
            font-size: 13px;
        }

        .next-steps li {
            margin-bottom: 8px;
        }

        a {
            color: #06b6d4;
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        @media (max-width: 600px) {
            .summary {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 System Check</h1>
            <p>Verifying Temidove Smart Solutions Installation</p>
        </div>

        <!-- Summary -->
        <div class="summary">
            <div class="summary-box success-box">
                <div class="summary-number"><?php echo count($success); ?></div>
                <div class="summary-label">Checks Passed</div>
            </div>
            <div class="summary-box warning-box">
                <div class="summary-number"><?php echo count($warnings); ?></div>
                <div class="summary-label">Warnings</div>
            </div>
            <div class="summary-box error-box">
                <div class="summary-number"><?php echo count($errors); ?></div>
                <div class="summary-label">Errors</div>
            </div>
        </div>

        <!-- Status Banner -->
        <?php if (empty($errors)): ?>
            <div class="status-banner status-good">
                ✓ All systems operational! Your installation is ready.
                <br><a href="index.php">→ Go to homepage</a>
            </div>
        <?php else: ?>
            <div class="status-banner status-bad">
                ✗ Installation incomplete. Fix the errors below before using the system.
            </div>
        <?php endif; ?>

        <!-- Success Checks -->
        <?php if (!empty($success)): ?>
            <div class="check-card">
                <div class="check-section">
                    <h2>✓ Passed Checks</h2>
                    <?php foreach ($success as $item): ?>
                        <div class="check-item">
                            <div class="check-icon">✓</div>
                            <div class="check-text success-message"><?php echo $item; ?></div>
                        </div>
                    <?php endforeach; ?>
                </div>
            </div>
        <?php endif; ?>

        <!-- Errors -->
        <?php if (!empty($errors)): ?>
            <div class="check-card">
                <div class="check-section">
                    <h2>✗ Critical Errors</h2>
                    <?php foreach ($errors as $error): ?>
                        <div class="check-item">
                            <div class="check-icon">✗</div>
                            <div class="check-text error-message"><?php echo $error; ?></div>
                        </div>
                    <?php endforeach; ?>
                </div>
                <div class="next-steps">
                    <h3>How to Fix:</h3>
                    <ol>
                        <li>Review the errors above</li>
                        <li>Follow the steps in QUICKSTART.txt or README.md</li>
                        <li>Refresh this page to verify fixes</li>
                        <li>If problems persist, check WAMP is running and database exists</li>
                    </ol>
                </div>
            </div>
        <?php endif; ?>

        <!-- Warnings -->
        <?php if (!empty($warnings)): ?>
            <div class="check-card">
                <div class="check-section">
                    <h2>⚠ Warnings</h2>
                    <?php foreach ($warnings as $warning): ?>
                        <div class="check-item">
                            <div class="check-icon">⚠</div>
                            <div class="check-text warning-message"><?php echo $warning; ?></div>
                        </div>
                    <?php endforeach; ?>
                </div>
            </div>
        <?php endif; ?>

        <!-- Information -->
        <div class="check-card">
            <div class="check-section">
                <h2>ℹ System Information</h2>
                <div class="check-item">
                    <div class="check-text">
                        <strong>PHP Version:</strong> <?php echo phpversion(); ?><br>
                        <strong>Server OS:</strong> <?php echo php_uname(); ?><br>
                        <strong>Document Root:</strong> <?php echo getcwd(); ?><br>
                        <strong>Session Support:</strong> <?php echo function_exists('session_start') ? 'Yes' : 'No'; ?>
                    </div>
                </div>
            </div>
        </div>

        <!-- Quick Links -->
        <div class="check-card">
            <div class="check-section">
                <h2>🔗 Quick Links</h2>
                <div class="check-item">
                    <div class="check-text">
                        <a href="index.php">→ Home Page</a><br>
                        <a href="register.php">→ Student Registration Form</a><br>
                        <a href="login.php">→ Staff Login</a><br>
                        <a href="http://localhost/phpmyadmin">→ phpMyAdmin (Database Management)</a><br>
                    </div>
                </div>
            </div>
        </div>

        <p style="text-align: center; margin-top: 30px; color: #64748b; font-size: 13px;">
            For detailed instructions, see README.md or QUICKSTART.txt
        </p>
    </div>
</body>
</html>
