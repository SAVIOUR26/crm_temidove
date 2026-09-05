<?php
require_once 'config.php';
requireLogin();

// Get all courses (departments) with a count of how many registrations/inquiries belong to each
$query = "SELECT c.id, c.course_name, c.description, COUNT(r.id) as total_inquiries
          FROM courses c
          LEFT JOIN registrations r ON r.course_id = c.id
          GROUP BY c.id, c.course_name, c.description
          ORDER BY c.course_name ASC";

$departments = [];
$result = $conn->query($query);
if ($result) {
    while ($row = $result->fetch_assoc()) {
        $departments[] = $row;
    }
}

// Overall total, for the header
$grand_total = 0;
foreach ($departments as $d) {
    $grand_total += (int) $d['total_inquiries'];
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Departments - Temidove Smart Solutions</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f0f4f8;
            line-height: 1.6;
        }

        .navbar {
            background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%);
            color: white;
            padding: 15px 0;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            position: sticky;
            top: 0;
            z-index: 100;
        }

        .navbar-content {
            max-width: 1400px;
            margin: 0 auto;
            padding: 0 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .navbar h2 { font-size: 22px; font-weight: 600; }

        .user-section { display: flex; align-items: center; gap: 15px; }

        .btn-nav {
            background: rgba(255,255,255,0.15);
            color: white;
            padding: 8px 16px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 13px;
            text-decoration: none;
            transition: background 0.3s;
        }

        .btn-nav:hover { background: rgba(255,255,255,0.28); }

        .btn-logout {
            background: #dc2626;
            color: white;
            padding: 8px 16px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 13px;
            text-decoration: none;
        }

        .btn-logout:hover { background: #b91c1c; }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 30px 20px;
        }

        .breadcrumb {
            font-size: 13px;
            color: #475569;
            margin-bottom: 20px;
        }

        .breadcrumb a { color: #06b6d4; text-decoration: none; }
        .breadcrumb a:hover { text-decoration: underline; }

        .page-header {
            background: linear-gradient(135deg, #06b6d4 0%, #0891b2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
        }

        .page-header h1 { font-size: 26px; margin-bottom: 8px; }
        .page-header p { opacity: 0.9; font-size: 14px; }

        .dept-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 22px;
        }

        .dept-card {
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            overflow: hidden;
            cursor: pointer;
            transition: all 0.3s;
            text-decoration: none;
            color: inherit;
            display: block;
            border-top: 4px solid #06b6d4;
        }

        .dept-card:hover {
            transform: translateY(-6px);
            box-shadow: 0 10px 24px rgba(0, 0, 0, 0.14);
        }

        .dept-card-body { padding: 22px; }

        .dept-icon { font-size: 30px; margin-bottom: 10px; }

        .dept-name {
            font-size: 17px;
            font-weight: 700;
            color: #1e3a8a;
            margin-bottom: 8px;
        }

        .dept-desc {
            font-size: 13px;
            color: #64748b;
            margin-bottom: 15px;
            min-height: 36px;
        }

        .dept-count {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-top: 1px solid #e0e7ff;
            padding-top: 12px;
        }

        .dept-count .num {
            font-size: 24px;
            font-weight: 700;
            color: #06b6d4;
        }

        .dept-count .label {
            font-size: 11px;
            color: #94a3b8;
            text-transform: uppercase;
            font-weight: 600;
        }

        .dept-arrow { color: #06b6d4; font-size: 20px; }

        .empty-message {
            text-align: center;
            padding: 50px;
            color: #64748b;
            background: white;
            border-radius: 10px;
        }
    </style>
</head>
<body>
    <div class="navbar">
        <div class="navbar-content">
            <h2>📂 Departments</h2>
            <div class="user-section">
                <a href="dashboard.php" class="btn-nav">← Dashboard</a>
                <a href="logout.php" class="btn-logout">Logout</a>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="breadcrumb">
            <a href="dashboard.php">Dashboard</a> &nbsp;›&nbsp; Departments
        </div>

        <div class="page-header">
            <h1>Departments (Courses)</h1>
            <p><?php echo count($departments); ?> departments &middot; <?php echo $grand_total; ?> total inquiries. Select a department to view its offers.</p>
        </div>

        <?php if (empty($departments)): ?>
            <div class="empty-message">No departments found. Add courses via phpMyAdmin.</div>
        <?php else: ?>
            <div class="dept-grid">
                <?php foreach ($departments as $dept): ?>
                    <a class="dept-card" href="offers.php?course_id=<?php echo (int) $dept['id']; ?>">
                        <div class="dept-card-body">
                            <div class="dept-icon">🎓</div>
                            <div class="dept-name"><?php echo htmlspecialchars($dept['course_name']); ?></div>
                            <div class="dept-desc"><?php echo htmlspecialchars(mb_strimwidth($dept['description'] ?? 'Comprehensive training program', 0, 80, '...')); ?></div>
                            <div class="dept-count">
                                <div>
                                    <div class="num"><?php echo (int) $dept['total_inquiries']; ?></div>
                                    <div class="label">Inquiries</div>
                                </div>
                                <div class="dept-arrow">→</div>
                            </div>
                        </div>
                    </a>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </div>
</body>
</html>
