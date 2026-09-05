<?php
/**
 * TEMIDOVE - QUICK DIAGNOSTIC TEST
 * Run this file to see exactly what's wrong
 * Visit: http://localhost/temidove/test.php
 */

$tests = [];

// Test 1: PHP Version
$tests['php_version'] = [
    'name' => 'PHP Version',
    'result' => phpversion(),
    'required' => '7.4.0 or higher',
    'status' => version_compare(phpversion(), '7.4', '>=') ? '✓ PASS' : '✗ FAIL'
];

// Test 2: mysqli extension
$tests['mysqli'] = [
    'name' => 'MySQLi Extension',
    'result' => extension_loaded('mysqli') ? 'Loaded' : 'NOT LOADED',
    'required' => 'Must be enabled',
    'status' => extension_loaded('mysqli') ? '✓ PASS' : '✗ FAIL - See fix below'
];

// Test 3: File location
$tests['location'] = [
    'name' => 'File Location',
    'result' => getcwd(),
    'required' => 'C:\\wamp64\\www\\temidove',
    'status' => strpos(getcwd(), 'temidove') !== false ? '✓ CORRECT' : '✗ WRONG LOCATION'
];

// Test 4: config.php exists
$tests['config_file'] = [
    'name' => 'config.php File',
    'result' => file_exists('config.php') ? 'Found' : 'NOT FOUND',
    'required' => 'Must exist in root folder',
    'status' => file_exists('config.php') ? '✓ EXISTS' : '✗ MISSING'
];

// Test 5: Database connection
$tests['mysql_connect'] = [
    'name' => 'MySQL Connection',
    'result' => 'Testing...',
    'required' => 'Must connect to localhost',
    'status' => '...'
];

$mysql_error = '';
$conn = @mysqli_connect('localhost', 'root', '', '');
if ($conn) {
    $tests['mysql_connect']['result'] = 'Connected to MySQL';
    $tests['mysql_connect']['status'] = '✓ PASS';
} else {
    $mysql_error = mysqli_connect_error();
    $tests['mysql_connect']['result'] = 'Connection failed: ' . $mysql_error;
    $tests['mysql_connect']['status'] = '✗ FAIL - See fix below';
}

// Test 6: Database exists
if ($conn) {
    $db_check = mysqli_query($conn, "SHOW DATABASES LIKE 'temidove_db'");
    if ($db_check && mysqli_num_rows($db_check) > 0) {
        $tests['database_exists'] = [
            'name' => 'temidove_db Database',
            'result' => 'Database found',
            'required' => 'Must exist in MySQL',
            'status' => '✓ EXISTS'
        ];
        
        // Test 7: Check tables
        mysqli_select_db($conn, 'temidove_db');
        
        $tables_needed = ['users', 'courses', 'registrations'];
        $tables_found = [];
        $tables_missing = [];
        
        foreach ($tables_needed as $table) {
            $result = mysqli_query($conn, "SHOW TABLES LIKE '$table'");
            if (mysqli_num_rows($result) > 0) {
                $tables_found[] = $table;
            } else {
                $tables_missing[] = $table;
            }
        }
        
        $tests['tables'] = [
            'name' => 'Database Tables',
            'result' => count($tables_found) . ' tables found: ' . implode(', ', $tables_found),
            'required' => 'users, courses, registrations',
            'status' => count($tables_missing) === 0 ? '✓ ALL TABLES OK' : '✗ MISSING: ' . implode(', ', $tables_missing)
        ];
    } else {
        $tests['database_exists'] = [
            'name' => 'temidove_db Database',
            'result' => 'Database NOT FOUND',
            'required' => 'Must exist in MySQL',
            'status' => '✗ MISSING - See fix below'
        ];
    }
    
    mysqli_close($conn);
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Diagnostic Test - Temidove</title>
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
        
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }
        
        .summary-box {
            background: white;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        
        .summary-number {
            font-size: 24px;
            font-weight: 700;
            margin-bottom: 5px;
        }
        
        .summary-label {
            font-size: 12px;
            color: #64748b;
            text-transform: uppercase;
            font-weight: 600;
        }
        
        .pass { color: #10b981; }
        .fail { color: #dc2626; }
        .warn { color: #f59e0b; }
        
        .test-card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 15px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            border-left: 4px solid #e0e7ff;
        }
        
        .test-card.pass {
            border-left-color: #10b981;
            background: #f0fdf4;
        }
        
        .test-card.fail {
            border-left-color: #dc2626;
            background: #fef2f2;
        }
        
        .test-card.warn {
            border-left-color: #f59e0b;
            background: #fffbeb;
        }
        
        .test-name {
            font-weight: 600;
            font-size: 16px;
            margin-bottom: 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .test-details {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 10px;
        }
        
        .detail {
            font-size: 13px;
        }
        
        .detail-label {
            color: #64748b;
            font-weight: 600;
            margin-bottom: 3px;
            text-transform: uppercase;
            font-size: 11px;
        }
        
        .detail-value {
            color: #1e293b;
            font-family: monospace;
            word-break: break-all;
        }
        
        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .status-pass {
            background: #dcfce7;
            color: #166534;
        }
        
        .status-fail {
            background: #fee2e2;
            color: #991b1b;
        }
        
        .status-warn {
            background: #fef3c7;
            color: #92400e;
        }
        
        .solutions {
            background: #f0f9ff;
            border-left: 4px solid #06b6d4;
            padding: 20px;
            border-radius: 8px;
            margin-top: 30px;
        }
        
        .solutions h2 {
            color: #0c4a6e;
            margin-bottom: 15px;
            font-size: 18px;
        }
        
        .solution {
            background: white;
            padding: 15px;
            margin-bottom: 15px;
            border-radius: 6px;
            border-left: 4px solid #06b6d4;
        }
        
        .solution h3 {
            color: #1e3a8a;
            font-size: 14px;
            margin-bottom: 10px;
        }
        
        .solution ol, .solution ul {
            margin-left: 20px;
            color: #475569;
            font-size: 13px;
        }
        
        .solution li {
            margin-bottom: 8px;
        }
        
        code {
            background: #f1f5f9;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
        }
        
        .critical {
            background: #fee2e2 !important;
            border-left-color: #dc2626 !important;
            color: #991b1b;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Diagnostic Test</h1>
            <p>Checking your Temidove installation...</p>
        </div>
        
        <?php
        $passed = 0;
        $failed = 0;
        
        foreach ($tests as $test) {
            if (strpos($test['status'], 'PASS') !== false || strpos($test['status'], 'EXISTS') !== false || strpos($test['status'], 'OK') !== false || strpos($test['status'], 'CORRECT') !== false) {
                $passed++;
            } else {
                $failed++;
            }
        }
        ?>
        
        <div class="summary">
            <div class="summary-box">
                <div class="summary-number pass"><?php echo $passed; ?></div>
                <div class="summary-label">Passed</div>
            </div>
            <div class="summary-box">
                <div class="summary-number fail"><?php echo $failed; ?></div>
                <div class="summary-label">Failed</div>
            </div>
            <div class="summary-box">
                <div class="summary-number"><?php echo count($tests); ?></div>
                <div class="summary-label">Total Tests</div>
            </div>
        </div>
        
        <?php foreach ($tests as $key => $test): ?>
            <?php
            $class = 'pass';
            if (strpos($test['status'], '✗') !== false) {
                $class = 'fail';
            } elseif (strpos($test['status'], '⚠') !== false) {
                $class = 'warn';
            }
            
            $status_class = 'status-pass';
            if (strpos($test['status'], '✗') !== false) {
                $status_class = 'status-fail';
            } elseif (strpos($test['status'], '⚠') !== false) {
                $status_class = 'status-warn';
            }
            ?>
            <div class="test-card <?php echo $class; ?>">
                <div class="test-name">
                    <span><?php echo $test['name']; ?></span>
                    <span class="status-badge <?php echo $status_class; ?>"><?php echo $test['status']; ?></span>
                </div>
                <div class="test-details">
                    <div class="detail">
                        <div class="detail-label">Result</div>
                        <div class="detail-value"><?php echo $test['result']; ?></div>
                    </div>
                    <div class="detail">
                        <div class="detail-label">Required</div>
                        <div class="detail-value"><?php echo $test['required']; ?></div>
                    </div>
                </div>
            </div>
        <?php endforeach; ?>
        
        <?php if ($failed > 0): ?>
            <div class="solutions">
                <h2>🔧 How to Fix These Issues</h2>
                
                <?php if (isset($tests['mysql_connect']) && strpos($tests['mysql_connect']['status'], '✗') !== false): ?>
                    <div class="solution critical">
                        <h3>❌ MySQL Connection Failed</h3>
                        <p><strong>Problem:</strong> Cannot connect to MySQL server</p>
                        <p><strong>Error:</strong> <?php echo $mysql_error; ?></p>
                        <p><strong>Solutions (try in order):</strong></p>
                        <ol>
                            <li>Make sure WAMP icon is <span style="color: green; font-weight: bold;">GREEN</span> (not orange/red)</li>
                            <li>Click WAMP icon → "Start All Services"</li>
                            <li>Wait 10-15 seconds for all services to start</li>
                            <li>If still red, right-click WAMP → "Run as Administrator"</li>
                            <li>If services won't start, restart your computer and try again</li>
                            <li>Check Task Manager (Ctrl+Shift+Esc) → Services tab to verify MySQL/Apache running</li>
                        </ol>
                    </div>
                <?php endif; ?>
                
                <?php if (isset($tests['database_exists']) && strpos($tests['database_exists']['status'], '✗') !== false): ?>
                    <div class="solution critical">
                        <h3>❌ Database Not Found</h3>
                        <p><strong>Problem:</strong> The <code>temidove_db</code> database doesn't exist</p>
                        <p><strong>How to create it:</strong></p>
                        <ol>
                            <li>Open your browser</li>
                            <li>Go to <code>http://localhost/phpmyadmin</code></li>
                            <li>Click "Databases" tab at the top</li>
                            <li>Type <code>temidove_db</code> in the "Database name" field</li>
                            <li>Click <span style="background: #1e3a8a; color: white; padding: 3px 8px; border-radius: 3px;">Create</span></li>
                            <li>Click on the new <code>temidove_db</code> database</li>
                            <li>Click the "Import" tab</li>
                            <li>Click "Choose File" button</li>
                            <li>Select: <code>temidove_database.sql</code></li>
                            <li>Click "Import" button</li>
                            <li>Wait for success message</li>
                            <li>Refresh this test page</li>
                        </ol>
                    </div>
                <?php endif; ?>
                
                <?php if (isset($tests['mysqli']) && strpos($tests['mysqli']['status'], '✗') !== false): ?>
                    <div class="solution">
                        <h3>⚠️ MySQLi Extension Not Loaded</h3>
                        <p><strong>Problem:</strong> PHP cannot connect to MySQL</p>
                        <p><strong>How to fix:</strong></p>
                        <ol>
                            <li>Right-click WAMP icon</li>
                            <li>Click "PHP" → "Extensions"</li>
                            <li>Look for <code>php_mysqli.dll</code> (should have checkmark)</li>
                            <li>Click to enable it if not checked</li>
                            <li>WAMP will restart automatically</li>
                            <li>Wait for icon to turn green again</li>
                            <li>Refresh this test page</li>
                        </ol>
                    </div>
                <?php endif; ?>
                
                <?php if (isset($tests['location']) && strpos($tests['location']['status'], '✗') !== false): ?>
                    <div class="solution critical">
                        <h3>❌ Files in Wrong Location</h3>
                        <p><strong>Problem:</strong> Files must be in <code>C:\wamp64\www\temidove\</code></p>
                        <p><strong>Current location:</strong> <code><?php echo getcwd(); ?></code></p>
                        <p><strong>How to fix:</strong></p>
                        <ol>
                            <li>Open File Explorer</li>
                            <li>Navigate to <code>C:\wamp64\www</code></li>
                            <li>Create a folder named <code>temidove</code></li>
                            <li>Move ALL PHP files there (config.php, index.php, etc.)</li>
                            <li>After moving, refresh this test page</li>
                        </ol>
                    </div>
                <?php endif; ?>
            </div>
        <?php else: ?>
            <div style="background: #dcfce7; border-left: 4px solid #10b981; padding: 20px; border-radius: 8px; text-align: center; margin-top: 30px;">
                <h2 style="color: #166534; font-size: 24px; margin-bottom: 10px;">✓ All Tests Passed!</h2>
                <p style="color: #166534; font-size: 16px;">Your installation looks good. Try accessing:</p>
                <p style="margin-top: 15px;">
                    <a href="index.php" style="background: #10b981; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; font-weight: 600; display: inline-block;">→ Go to Home Page</a>
                </p>
            </div>
        <?php endif; ?>
        
        <div style="text-align: center; margin-top: 30px; color: #64748b; font-size: 13px;">
            <p>Still having issues? Read: <code>TROUBLESHOOTING.txt</code> or <code>QUICKSTART.txt</code></p>
        </div>
    </div>
</body>
</html>
