<?php
require_once 'config.php';
requireLogin();

$filter_status = $_GET['status'] ?? '';
$filter_course = $_GET['course'] ?? '';
$search = $_GET['search'] ?? '';

// Get statistics
$stats = [
    'total' => 0,
    'waiting' => 0,
    'started' => 0,
    'completed' => 0,
    'cancelled' => 0
];

$stat_result = $conn->query(
    "SELECT status, COUNT(*) as count FROM registrations GROUP BY status"
);

if ($stat_result) {
    while ($row = $stat_result->fetch_assoc()) {
        $stats[$row['status']] = $row['count'];
        $stats['total'] += $row['count'];
    }
}

// Build query for registrations
$query = "SELECT r.*, c.course_name, u.full_name as assigned_staff 
          FROM registrations r 
          LEFT JOIN courses c ON r.course_id = c.id 
          LEFT JOIN users u ON r.assigned_to = u.id
          WHERE 1=1";

$params = [];
$types = '';

if (!empty($filter_status)) {
    $query .= " AND r.status = ?";
    $params[] = $filter_status;
    $types .= 's';
}

if (!empty($filter_course)) {
    $query .= " AND r.course_id = ?";
    $params[] = intval($filter_course);
    $types .= 'i';
}

if (!empty($search)) {
    $query .= " AND (r.first_name LIKE ? OR r.last_name LIKE ? OR r.email LIKE ? OR r.phone LIKE ?)";
    $search_term = '%' . $search . '%';
    $params = array_merge($params, [$search_term, $search_term, $search_term, $search_term]);
    $types .= 'ssss';
}

$query .= " ORDER BY r.inquiry_date DESC";

$stmt = $conn->prepare($query);

if (!empty($params)) {
    $stmt->bind_param($types, ...$params);
}

$stmt->execute();
$registrations_result = $stmt->get_result();
$registrations = [];

while ($row = $registrations_result->fetch_assoc()) {
    $registrations[] = $row;
}

$stmt->close();

// Get all courses for filter dropdown
$courses_result = $conn->query("SELECT id, course_name FROM courses ORDER BY course_name ASC");
$courses = [];
while ($row = $courses_result->fetch_assoc()) {
    $courses[] = $row;
}

// Get staff for assignment
$staff_result = $conn->query("SELECT id, full_name FROM users WHERE role = 'staff' OR role = 'admin' ORDER BY full_name ASC");
$staff = [];
while ($row = $staff_result->fetch_assoc()) {
    $staff[] = $row;
}

// Handle status and assignment updates via AJAX
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    header('Content-Type: application/json');
    
    $registration_id = intval($_POST['id'] ?? 0);
    
    if ($_POST['action'] === 'update_status') {
        $new_status = sanitize($_POST['status'] ?? '');
        $allowed_statuses = ['waiting', 'started', 'completed', 'cancelled'];
        
        if (in_array($new_status, $allowed_statuses)) {
            $update_stmt = $conn->prepare("UPDATE registrations SET status = ? WHERE id = ?");
            $update_stmt->bind_param("si", $new_status, $registration_id);
            
            if ($update_stmt->execute()) {
                echo json_encode(['success' => true, 'message' => 'Status updated successfully']);
            } else {
                echo json_encode(['success' => false, 'message' => 'Error updating status']);
            }
            $update_stmt->close();
        }
        exit();
    }
    
    if ($_POST['action'] === 'assign_staff') {
        $staff_id = intval($_POST['staff_id'] ?? 0);
        if ($staff_id > 0 || $staff_id === 0) {
            $assign_staff = $staff_id > 0 ? $staff_id : null;
            $update_stmt = $conn->prepare("UPDATE registrations SET assigned_to = ? WHERE id = ?");
            $update_stmt->bind_param("ii", $assign_staff, $registration_id);
            
            if ($update_stmt->execute()) {
                echo json_encode(['success' => true, 'message' => 'Staff assigned successfully']);
            } else {
                echo json_encode(['success' => false, 'message' => 'Error assigning staff']);
            }
            $update_stmt->close();
        }
        exit();
    }
    
    if ($_POST['action'] === 'add_note') {
        $note = sanitize($_POST['note'] ?? '');
        $update_stmt = $conn->prepare("UPDATE registrations SET notes = ? WHERE id = ?");
        $update_stmt->bind_param("si", $note, $registration_id);
        
        if ($update_stmt->execute()) {
            echo json_encode(['success' => true, 'message' => 'Note added successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Error adding note']);
        }
        $update_stmt->close();
        exit();
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Temidove Smart Solutions</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

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

        .navbar h2 {
            font-size: 22px;
            font-weight: 600;
        }

        .user-section {
            display: flex;
            align-items: center;
            gap: 20px;
        }

        .user-info {
            text-align: right;
            font-size: 13px;
        }

        .user-info strong {
            display: block;
            font-size: 14px;
        }

        .btn-logout {
            background: #dc2626;
            color: white;
            padding: 8px 16px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 13px;
            transition: background 0.3s;
        }

        .btn-logout:hover {
            background: #b91c1c;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 30px 20px;
        }

        .welcome-section {
            background: linear-gradient(135deg, #06b6d4 0%, #0891b2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
        }

        .welcome-section h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            text-align: center;
            cursor: pointer;
            transition: all 0.3s;
            border-left: 4px solid #06b6d4;
        }

        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 15px rgba(0, 0, 0, 0.12);
        }

        .stat-card h3 {
            color: #475569;
            font-size: 14px;
            font-weight: 500;
            margin-bottom: 10px;
            text-transform: uppercase;
        }

        .stat-number {
            font-size: 36px;
            font-weight: 700;
            color: #1e3a8a;
        }

        .stat-card.waiting { border-left-color: #f59e0b; }
        .stat-card.waiting .stat-number { color: #f59e0b; }

        .stat-card.started { border-left-color: #3b82f6; }
        .stat-card.started .stat-number { color: #3b82f6; }

        .stat-card.completed { border-left-color: #10b981; }
        .stat-card.completed .stat-number { color: #10b981; }

        .stat-hint {
            margin-top: 8px;
            font-size: 11px;
            color: #06b6d4;
            font-weight: 600;
        }

        .filters {
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 25px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
        }

        .filter-group {
            display: flex;
            flex-direction: column;
        }

        .filter-group label {
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 6px;
            color: #1e3a8a;
        }

        .filter-group input,
        .filter-group select {
            padding: 10px;
            border: 1px solid #e0e7ff;
            border-radius: 6px;
            font-size: 13px;
        }

        .filter-group input:focus,
        .filter-group select:focus {
            outline: none;
            border-color: #06b6d4;
            box-shadow: 0 0 0 2px rgba(6, 182, 212, 0.1);
        }

        .filter-actions {
            display: flex;
            gap: 10px;
            align-items: flex-end;
        }

        .btn-filter {
            background: linear-gradient(135deg, #1e3a8a 0%, #06b6d4 100%);
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 13px;
            font-weight: 600;
            transition: transform 0.2s;
        }

        .btn-filter:hover {
            transform: translateY(-2px);
        }

        .btn-clear {
            background: #e0e7ff;
            color: #1e3a8a;
            padding: 10px 20px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 13px;
            font-weight: 600;
        }

        .btn-clear:hover {
            background: #c7d2fe;
        }

        .table-container {
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            overflow: hidden;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        thead {
            background: #f1f5f9;
            border-bottom: 2px solid #e0e7ff;
        }

        th {
            padding: 15px;
            text-align: left;
            font-size: 13px;
            font-weight: 600;
            color: #1e3a8a;
            text-transform: uppercase;
        }

        td {
            padding: 15px;
            border-bottom: 1px solid #e0e7ff;
            font-size: 13px;
        }

        tbody tr {
            transition: background 0.2s;
        }

        tbody tr:hover {
            background: #f8fafc;
        }

        .status-badge {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }

        .status-waiting {
            background: #fef3c7;
            color: #92400e;
        }

        .status-started {
            background: #dbeafe;
            color: #1e40af;
        }

        .status-completed {
            background: #dcfce7;
            color: #166534;
        }

        .status-cancelled {
            background: #fee2e2;
            color: #7f1d1d;
        }

        select.status-select {
            padding: 6px 10px;
            border: 1px solid #e0e7ff;
            border-radius: 4px;
            font-size: 12px;
            cursor: pointer;
        }

        .action-icons {
            display: flex;
            gap: 8px;
        }

        .action-btn {
            background: none;
            border: none;
            cursor: pointer;
            padding: 5px;
            color: #1e3a8a;
            font-size: 14px;
            transition: color 0.2s;
        }

        .action-btn:hover {
            color: #06b6d4;
        }

        .empty-message {
            text-align: center;
            padding: 40px;
            color: #94a3b8;
        }

        .modal {
            display: none;
            position: fixed;
            z-index: 1000;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0, 0, 0, 0.5);
        }

        .modal.active {
            display: flex;
            justify-content: center;
            align-items: center;
        }

        .modal-content {
            background: white;
            border-radius: 10px;
            max-width: 600px;
            width: 95%;
            max-height: 90vh;
            overflow-y: auto;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
        }

        .modal-header {
            background: linear-gradient(135deg, #06b6d4 0%, #0891b2 100%);
            color: white;
            padding: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .modal-header h2 {
            font-size: 20px;
        }

        .close-btn {
            background: none;
            border: none;
            color: white;
            font-size: 28px;
            cursor: pointer;
        }

        .modal-body {
            padding: 25px;
        }

        .detail-row {
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 1px solid #e0e7ff;
        }

        .detail-row:last-child {
            border-bottom: none;
        }

        .detail-label {
            color: #1e3a8a;
            font-weight: 600;
            font-size: 13px;
            text-transform: uppercase;
            margin-bottom: 5px;
        }

        .detail-value {
            color: #475569;
            font-size: 14px;
        }

        .form-group {
            margin-bottom: 15px;
        }

        .form-group label {
            display: block;
            color: #1e3a8a;
            font-weight: 600;
            font-size: 13px;
            margin-bottom: 6px;
        }

        .form-group input,
        .form-group select,
        .form-group textarea {
            width: 100%;
            padding: 10px;
            border: 1px solid #e0e7ff;
            border-radius: 6px;
            font-size: 13px;
            font-family: inherit;
        }

        .form-group textarea {
            resize: vertical;
            min-height: 80px;
        }

        .form-group input:focus,
        .form-group select:focus,
        .form-group textarea:focus {
            outline: none;
            border-color: #06b6d4;
            box-shadow: 0 0 0 2px rgba(6, 182, 212, 0.1);
        }

        .modal-actions {
            display: flex;
            gap: 10px;
            padding: 20px;
            border-top: 1px solid #e0e7ff;
        }

        .btn-save {
            background: linear-gradient(135deg, #1e3a8a 0%, #06b6d4 100%);
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 600;
            flex: 1;
        }

        .btn-save:hover {
            opacity: 0.9;
        }

        .btn-cancel {
            background: #e0e7ff;
            color: #1e3a8a;
            padding: 10px 20px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 600;
            flex: 1;
        }

        .message {
            padding: 12px;
            border-radius: 6px;
            margin-bottom: 15px;
            font-size: 13px;
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

        @media (max-width: 1024px) {
            .stats-grid {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        @media (max-width: 768px) {
            .stats-grid {
                grid-template-columns: 1fr;
            }

            .filters {
                grid-template-columns: 1fr;
            }

            .filter-actions {
                flex-direction: column;
            }

            table {
                font-size: 12px;
            }

            th, td {
                padding: 10px;
            }
        }
    </style>
</head>
<body>
    <div class="navbar">
        <div class="navbar-content">
            <h2>📊 Temidove Smart Solutions</h2>
            <div class="user-section">
                <a href="departments.php" class="btn-logout" style="background: linear-gradient(135deg, #06b6d4 0%, #0891b2 100%);">📂 By Department</a>
                <div class="user-info">
                    <strong><?php echo htmlspecialchars($_SESSION['full_name']); ?></strong>
                    <small><?php echo ucfirst($_SESSION['role']); ?></small>
                </div>
                <a href="logout.php" class="btn-logout">Logout</a>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="welcome-section">
            <h1>Welcome, <?php echo htmlspecialchars($_SESSION['full_name']); ?>! 👋</h1>
            <p>Manage course inquiries and track student enrollment status</p>
        </div>

        <!-- Statistics Cards -->
        <div class="stats-grid">
            <div class="stat-card" onclick="window.location.href='departments.php'" title="Browse by department">
                <h3>Total Inquiries</h3>
                <div class="stat-number"><?php echo $stats['total']; ?></div>
                <div class="stat-hint">📂 View by Department →</div>
            </div>
            <div class="stat-card waiting" onclick="filterByStatus('waiting')">
                <h3>Waiting</h3>
                <div class="stat-number"><?php echo $stats['waiting']; ?></div>
            </div>
            <div class="stat-card started" onclick="filterByStatus('started')">
                <h3>Started</h3>
                <div class="stat-number"><?php echo $stats['started']; ?></div>
            </div>
            <div class="stat-card completed" onclick="filterByStatus('completed')">
                <h3>Completed</h3>
                <div class="stat-number"><?php echo $stats['completed']; ?></div>
            </div>
        </div>

        <!-- Filters -->
        <div class="filters">
            <form id="filterForm" method="GET" style="display: contents;">
                <div class="filter-group">
                    <label>Search</label>
                    <input type="text" name="search" placeholder="Name, email, or phone..." value="<?php echo htmlspecialchars($search); ?>">
                </div>

                <div class="filter-group">
                    <label>Status</label>
                    <select name="status">
                        <option value="">All Statuses</option>
                        <option value="waiting" <?php echo $filter_status === 'waiting' ? 'selected' : ''; ?>>Waiting</option>
                        <option value="started" <?php echo $filter_status === 'started' ? 'selected' : ''; ?>>Started</option>
                        <option value="completed" <?php echo $filter_status === 'completed' ? 'selected' : ''; ?>>Completed</option>
                        <option value="cancelled" <?php echo $filter_status === 'cancelled' ? 'selected' : ''; ?>>Cancelled</option>
                    </select>
                </div>

                <div class="filter-group">
                    <label>Course</label>
                    <select name="course">
                        <option value="">All Courses</option>
                        <?php foreach ($courses as $course): ?>
                            <option value="<?php echo $course['id']; ?>" <?php echo $filter_course == $course['id'] ? 'selected' : ''; ?>>
                                <?php echo $course['course_name']; ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="filter-actions">
                    <button type="submit" class="btn-filter">🔍 Filter</button>
                    <a href="?" class="btn-clear">Clear</a>
                </div>
            </form>
        </div>

        <!-- Registrations Table -->
        <div class="table-container">
            <?php if (empty($registrations)): ?>
                <div class="empty-message">
                    <p>No registrations found. Clients can submit inquiries via the <a href="register.php" style="color: #06b6d4; text-decoration: none;">Course Inquiry Form</a>.</p>
                </div>
            <?php else: ?>
                <table>
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Email</th>
                            <th>Phone</th>
                            <th>Course</th>
                            <th>Level</th>
                            <th>Offer</th>
                            <th>Status</th>
                            <th>Assigned To</th>
                            <th>Inquiry Date</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($registrations as $reg): ?>
                            <tr>
                                <td><strong><?php echo htmlspecialchars($reg['first_name'] . ' ' . $reg['last_name']); ?></strong></td>
                                <td><?php echo htmlspecialchars($reg['email']); ?></td>
                                <td><?php echo htmlspecialchars($reg['phone']); ?></td>
                                <td><?php echo htmlspecialchars($reg['course_name'] ?? 'N/A'); ?></td>
                                <td><?php echo htmlspecialchars(ucwords($reg['level'] ?? 'N/A')); ?></td>
                                <td><?php echo htmlspecialchars(ucwords($reg['offer'] ?? 'N/A')); ?></td>
                                <td>
                                    <select class="status-select" onchange="updateStatus(<?php echo $reg['id']; ?>, this.value)">
                                        <option value="waiting" <?php echo $reg['status'] === 'waiting' ? 'selected' : ''; ?>>Waiting</option>
                                        <option value="started" <?php echo $reg['status'] === 'started' ? 'selected' : ''; ?>>Started</option>
                                        <option value="completed" <?php echo $reg['status'] === 'completed' ? 'selected' : ''; ?>>Completed</option>
                                        <option value="cancelled" <?php echo $reg['status'] === 'cancelled' ? 'selected' : ''; ?>>Cancelled</option>
                                    </select>
                                </td>
                                <td><?php echo $reg['assigned_staff'] ?? 'Unassigned'; ?></td>
                                <td><?php echo date('M d, Y', strtotime($reg['inquiry_date'])); ?></td>
                                <td>
                                    <div class="action-icons">
                                        <button class="action-btn" onclick="viewDetails(<?php echo $reg['id']; ?>)" title="View Details">👁️</button>
                                        <button class="action-btn" onclick="editRegistration(<?php echo $reg['id']; ?>)" title="Edit">✏️</button>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>
    </div>

    <!-- Details Modal -->
    <div id="detailsModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h2>Registration Details</h2>
                <button class="close-btn" onclick="closeModal('detailsModal')">&times;</button>
            </div>
            <div class="modal-body" id="detailsContent"></div>
        </div>
    </div>

    <!-- Edit Modal -->
    <div id="editModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h2>Update Registration</h2>
                <button class="close-btn" onclick="closeModal('editModal')">&times;</button>
            </div>
            <div class="modal-body">
                <div id="messageBox"></div>
                <form id="editForm">
                    <input type="hidden" id="editId" name="id">
                    
                    <div class="form-group">
                        <label>Assign To Staff</label>
                        <select id="staffSelect" name="staff_id">
                            <option value="">-- Unassigned --</option>
                            <?php foreach ($staff as $s): ?>
                                <option value="<?php echo $s['id']; ?>"><?php echo htmlspecialchars($s['full_name']); ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="form-group">
                        <label>Add Note</label>
                        <textarea id="noteText" placeholder="Add notes about this student..."></textarea>
                    </div>

                    <div class="form-group">
                        <label>Start Date</label>
                        <input type="date" id="startDate">
                    </div>
                </form>
            </div>
            <div class="modal-actions">
                <button class="btn-save" onclick="saveChanges()">Save Changes</button>
                <button class="btn-cancel" onclick="closeModal('editModal')">Cancel</button>
            </div>
        </div>
    </div>

    <script>
        const staff = <?php echo json_encode($staff); ?>;
        const registrations = <?php echo json_encode($registrations); ?>;

        function viewDetails(id) {
            const reg = registrations.find(r => r.id === id);
            if (!reg) return;

            const content = `
                <div class="detail-row">
                    <div class="detail-label">Full Name</div>
                    <div class="detail-value">${reg.first_name} ${reg.last_name}</div>
                </div>
                <div class="detail-row">
                    <div class="detail-label">Email</div>
                    <div class="detail-value"><a href="mailto:${reg.email}" style="color: #06b6d4;">${reg.email}</a></div>
                </div>
                <div class="detail-row">
                    <div class="detail-label">Phone</div>
                    <div class="detail-value">${reg.phone}</div>
                </div>
                <div class="detail-row">
                    <div class="detail-label">Course</div>
                    <div class="detail-value">${reg.course_name || 'N/A'}</div>
                </div>
                <div class="detail-row">
                    <div class="detail-label">Level</div>
                    <div class="detail-value">${reg.level || 'N/A'}</div>
                </div>
                <div class="detail-row">
                    <div class="detail-label">Offer</div>
                    <div class="detail-value">${reg.offer || 'N/A'}</div>
                </div>
                <div class="detail-row">
                    <div class="detail-label">Status</div>
                    <div class="detail-value"><span class="status-badge status-${reg.status}">${reg.status.toUpperCase()}</span></div>
                </div>
                <div class="detail-row">
                    <div class="detail-label">Assigned To</div>
                    <div class="detail-value">${reg.assigned_staff || 'Unassigned'}</div>
                </div>
                <div class="detail-row">
                    <div class="detail-label">Inquiry Date</div>
                    <div class="detail-value">${new Date(reg.inquiry_date).toLocaleDateString()}</div>
                </div>
                ${reg.start_date ? `
                <div class="detail-row">
                    <div class="detail-label">Start Date</div>
                    <div class="detail-value">${new Date(reg.start_date).toLocaleDateString()}</div>
                </div>
                ` : ''}
                ${reg.notes ? `
                <div class="detail-row">
                    <div class="detail-label">Notes</div>
                    <div class="detail-value">${reg.notes}</div>
                </div>
                ` : ''}
            `;

            document.getElementById('detailsContent').innerHTML = content;
            document.getElementById('detailsModal').classList.add('active');
        }

        function editRegistration(id) {
            const reg = registrations.find(r => r.id === id);
            if (!reg) return;

            document.getElementById('editId').value = id;
            document.getElementById('staffSelect').value = reg.assigned_to || '';
            document.getElementById('noteText').value = reg.notes || '';
            document.getElementById('startDate').value = reg.start_date || '';
            document.getElementById('editModal').classList.add('active');
        }

        function closeModal(modalId) {
            document.getElementById(modalId).classList.remove('active');
            document.getElementById('messageBox').innerHTML = '';
        }

        function updateStatus(id, status) {
            fetch(window.location.href, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: `action=update_status&id=${id}&status=${status}`
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    location.reload();
                } else {
                    alert('Error: ' + data.message);
                }
            });
        }

        function saveChanges() {
            const id = document.getElementById('editId').value;
            const staffId = document.getElementById('staffSelect').value;
            const note = document.getElementById('noteText').value;
            const startDate = document.getElementById('startDate').value;

            const messageBox = document.getElementById('messageBox');

            // Save staff assignment
            if (staffId !== '') {
                fetch(window.location.href, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                    },
                    body: `action=assign_staff&id=${id}&staff_id=${staffId}`
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        messageBox.innerHTML = '<div class="message success">✓ Changes saved successfully</div>';
                        setTimeout(() => location.reload(), 1500);
                    }
                });
            } else {
                messageBox.innerHTML = '<div class="message success">✓ Changes saved successfully</div>';
                setTimeout(() => location.reload(), 1500);
            }
        }

        function filterByStatus(status) {
            if (status === 'all') {
                window.location.href = '?';
            } else {
                window.location.href = '?status=' + status;
            }
        }

        // Close modal when clicking outside
        window.onclick = function(event) {
            const detailsModal = document.getElementById('detailsModal');
            const editModal = document.getElementById('editModal');
            
            if (event.target === detailsModal) {
                detailsModal.classList.remove('active');
            }
            if (event.target === editModal) {
                editModal.classList.remove('active');
            }
        }
    </script>
</body>
</html>
