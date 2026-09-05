<?php
require_once 'config.php';
requireLogin();

$course_id = intval($_GET['course_id'] ?? 0);

if ($course_id <= 0) {
    header('Location: departments.php');
    exit();
}

// Fetch the department (course)
$stmt = $conn->prepare("SELECT id, course_name, description FROM courses WHERE id = ?");
$stmt->bind_param("i", $course_id);
$stmt->execute();
$course_result = $stmt->get_result();

if ($course_result->num_rows === 0) {
    $stmt->close();
    header('Location: departments.php');
    exit();
}

$course = $course_result->fetch_assoc();
$stmt->close();

// The three fixed offers
$offer_values = ['offer 1', 'offer 2', 'offer 3'];
$offer_labels = ['offer 1' => 'Offer 1', 'offer 2' => 'Offer 2', 'offer 3' => 'Offer 3'];
$offers = [];

foreach ($offer_values as $offer_value) {
    $count_stmt = $conn->prepare("SELECT COUNT(*) as total FROM registrations WHERE course_id = ? AND offer = ?");
    $count_stmt->bind_param("is", $course_id, $offer_value);
    $count_stmt->execute();
    $count_result = $count_stmt->get_result();
    $count_row = $count_result->fetch_assoc();
    $offers[] = [
        'value' => $offer_value,
        'label' => $offer_labels[$offer_value],
        'total' => (int) $count_row['total']
    ];
    $count_stmt->close();
}

$department_total = array_sum(array_column($offers, 'total'));
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($course['course_name']); ?> Offers - Temidove Smart Solutions</title>
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
            background: linear-gradient(135deg, #1e3a8a 0%, #06b6d4 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
        }

        .page-header h1 { font-size: 26px; margin-bottom: 8px; }
        .page-header p { opacity: 0.9; font-size: 14px; }

        .offer-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 22px;
        }

        .offer-card {
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            padding: 30px;
            cursor: pointer;
            transition: all 0.3s;
            text-decoration: none;
            color: inherit;
            text-align: center;
            border-top: 4px solid #1e3a8a;
        }

        .offer-card:hover {
            transform: translateY(-6px);
            box-shadow: 0 10px 24px rgba(0, 0, 0, 0.14);
        }

        .offer-icon { font-size: 38px; margin-bottom: 12px; }

        .offer-name {
            font-size: 19px;
            font-weight: 700;
            color: #1e3a8a;
            margin-bottom: 12px;
        }

        .offer-count {
            font-size: 32px;
            font-weight: 700;
            color: #06b6d4;
        }

        .offer-label {
            font-size: 11px;
            color: #94a3b8;
            text-transform: uppercase;
            font-weight: 600;
            margin-top: 4px;
        }
    </style>
</head>
<body>
    <div class="navbar">
        <div class="navbar-content">
            <h2>🎯 Offers</h2>
            <div class="user-section">
                <a href="departments.php" class="btn-nav">← Departments</a>
                <a href="dashboard.php" class="btn-nav">Dashboard</a>
                <a href="logout.php" class="btn-logout">Logout</a>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="breadcrumb">
            <a href="dashboard.php">Dashboard</a> &nbsp;›&nbsp;
            <a href="departments.php">Departments</a> &nbsp;›&nbsp;
            <?php echo htmlspecialchars($course['course_name']); ?>
        </div>

        <div class="page-header">
            <h1><?php echo htmlspecialchars($course['course_name']); ?></h1>
            <p><?php echo $department_total; ?> total inquiries in this department. Select an offer to view the clients.</p>
        </div>

        <div class="offer-grid">
            <?php foreach ($offers as $offer): ?>
                <a class="offer-card" href="clients.php?course_id=<?php echo $course_id; ?>&offer=<?php echo urlencode($offer['value']); ?>">
                    <div class="offer-icon">🏷️</div>
                    <div class="offer-name"><?php echo htmlspecialchars($offer['label']); ?></div>
                    <div class="offer-count"><?php echo $offer['total']; ?></div>
                    <div class="offer-label">Clients</div>
                </a>
            <?php endforeach; ?>
        </div>
    </div>
</body>
</html>
