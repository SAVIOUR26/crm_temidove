<?php
require_once 'config.php';
requireLogin();

$course_id = intval($_GET['course_id'] ?? 0);
$offer = $_GET['offer'] ?? '';
$allowed_offers = ['offer 1', 'offer 2', 'offer 3'];

if ($course_id <= 0 || !in_array($offer, $allowed_offers)) {
    header('Location: departments.php');
    exit();
}

// Handle status / assignment / note updates via AJAX (same behaviour as dashboard.php)
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
        $assign_staff = $staff_id > 0 ? $staff_id : null;
        $update_stmt = $conn->prepare("UPDATE registrations SET assigned_to = ? WHERE id = ?");
        $update_stmt->bind_param("ii", $assign_staff, $registration_id);

        if ($update_stmt->execute()) {
            echo json_encode(['success' => true, 'message' => 'Staff assigned successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Error assigning staff']);
        }
        $update_stmt->close();
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

// Fetch the department (course)
$stmt = $conn->prepare("SELECT id, course_name FROM courses WHERE id = ?");
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

$offer_labels = ['offer 1' => 'Offer 1', 'offer 2' => 'Offer 2', 'offer 3' => 'Offer 3'];

// Fetch clients (registrations) for this department + offer
$query = "SELECT r.*, c.course_name, u.full_name as assigned_staff
          FROM registrations r
          LEFT JOIN courses c ON r.course_id = c.id
          LEFT JOIN users u ON r.assigned_to = u.id
          WHERE r.course_id = ? AND r.offer = ?
          ORDER BY r.inquiry_date DESC";

$stmt = $conn->prepare($query);
$stmt->bind_param("is", $course_id, $offer);
$stmt->execute();
$registrations_result = $stmt->get_result();
$registrations = [];
while ($row = $registrations_result->fetch_assoc()) {
    $registrations[] = $row;
}
$stmt->close();

// Staff for the assignment dropdown
$staff_result = $conn->query("SELECT id, full_name FROM users WHERE role = 'staff' OR role = 'admin' ORDER BY full_name ASC");
$staff = [];
while ($row = $staff_result->fetch_assoc()) {
    $staff[] = $row;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($course['course_name']); ?> - <?php echo htmlspecialchars($offer_labels[$offer]); ?> Clients</title>
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

        .breadcrumb { font-size: 13px; color: #475569; margin-bottom: 20px; }
        .breadcrumb a { color: #06b6d4; text-decoration: none; }
        .breadcrumb a:hover { text-decoration: underline; }

        .page-header {
            background: linear-gradient(135deg, #06b6d4 0%, #1e3a8a 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
        }
        .page-header h1 { font-size: 24px; margin-bottom: 8px; }
        .page-header p { opacity: 0.9; font-size: 14px; }

        .table-container {
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            overflow: hidden;
        }

        table { width: 100%; border-collapse: collapse; }
        thead { background: #f1f5f9; border-bottom: 2px solid #e0e7ff; }
        th {
            padding: 15px;
            text-align: left;
            font-size: 13px;
            font-weight: 600;
            color: #1e3a8a;
            text-transform: uppercase;
        }
        td { padding: 15px; border-bottom: 1px solid #e0e7ff; font-size: 13px; }
        tbody tr:hover { background: #f8fafc; }

        .status-badge {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }
        .status-waiting { background: #fef3c7; color: #92400e; }
        .status-started { background: #dbeafe; color: #1e40af; }
        .status-completed { background: #d1fae5; color: #065f46; }
        .status-cancelled { background: #fee2e2; color: #991b1b; }

        .status-select {
            padding: 6px 10px;
            border-radius: 6px;
            border: 1px solid #e0e7ff;
            font-size: 12px;
        }

        .action-icons { display: flex; gap: 8px; }
        .action-btn {
            background: #f0f4f8;
            border: none;
            width: 32px;
            height: 32px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
        }
        .action-btn:hover { background: #e0e7ff; }

        .empty-message { text-align: center; padding: 50px; color: #64748b; }

        .modal {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(15, 23, 42, 0.6);
            z-index: 1000;
            align-items: center;
            justify-content: center;
        }
        .modal.active { display: flex; }
        .modal-content {
            background: white;
            border-radius: 10px;
            max-width: 500px;
            width: 90%;
            max-height: 85vh;
            overflow-y: auto;
        }
        .modal-header {
            padding: 20px;
            border-bottom: 1px solid #e0e7ff;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .modal-header h2 { color: #1e3a8a; font-size: 18px; }
        .close-btn { background: none; border: none; font-size: 22px; cursor: pointer; color: #64748b; }
        .modal-body { padding: 20px; }

        .detail-row { display: flex; padding: 10px 0; border-bottom: 1px solid #f1f5f9; }
        .detail-label { width: 130px; font-weight: 600; color: #475569; font-size: 13px; }
        .detail-value { flex: 1; font-size: 13px; color: #1e293b; }

        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; margin-bottom: 6px; font-size: 13px; font-weight: 600; color: #1e3a8a; }
        .form-group input, .form-group select, .form-group textarea {
            width: 100%;
            padding: 10px;
            border: 1px solid #e0e7ff;
            border-radius: 6px;
            font-size: 13px;
            font-family: inherit;
        }
        .form-group textarea { resize: vertical; min-height: 80px; }

        .modal-actions { display: flex; gap: 10px; padding: 20px; border-top: 1px solid #e0e7ff; }
        .btn-save {
            background: linear-gradient(135deg, #1e3a8a 0%, #06b6d4 100%);
            color: white; padding: 10px 20px; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; flex: 1;
        }
        .btn-cancel { background: #e0e7ff; color: #1e3a8a; padding: 10px 20px; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; flex: 1; }

        .message { padding: 12px; border-radius: 6px; margin-bottom: 15px; font-size: 13px; }
        .message.success { background: #dcfce7; color: #166534; border-left: 4px solid #10b981; }

        @media (max-width: 768px) {
            table { font-size: 12px; }
            th, td { padding: 10px; }
        }
    </style>
</head>
<body>
    <div class="navbar">
        <div class="navbar-content">
            <h2>👥 Clients</h2>
            <div class="user-section">
                <a href="offers.php?course_id=<?php echo $course_id; ?>" class="btn-nav">← Offers</a>
                <a href="departments.php" class="btn-nav">Departments</a>
                <a href="dashboard.php" class="btn-nav">Dashboard</a>
                <a href="logout.php" class="btn-logout">Logout</a>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="breadcrumb">
            <a href="dashboard.php">Dashboard</a> &nbsp;›&nbsp;
            <a href="departments.php">Departments</a> &nbsp;›&nbsp;
            <a href="offers.php?course_id=<?php echo $course_id; ?>"><?php echo htmlspecialchars($course['course_name']); ?></a> &nbsp;›&nbsp;
            <?php echo htmlspecialchars($offer_labels[$offer]); ?>
        </div>

        <div class="page-header">
            <h1><?php echo htmlspecialchars($course['course_name']); ?> — <?php echo htmlspecialchars($offer_labels[$offer]); ?></h1>
            <p><?php echo count($registrations); ?> client(s) in this offer.</p>
        </div>

        <div class="table-container">
            <?php if (empty($registrations)): ?>
                <div class="empty-message">No clients found for this offer yet.</div>
            <?php else: ?>
                <table>
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Email</th>
                            <th>Phone</th>
                            <th>Level</th>
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
                                <td><?php echo htmlspecialchars(ucwords($reg['level'] ?? 'N/A')); ?></td>
                                <td>
                                    <select class="status-select" onchange="updateStatus(<?php echo $reg['id']; ?>, this.value)">
                                        <option value="waiting" <?php echo $reg['status'] === 'waiting' ? 'selected' : ''; ?>>Waiting</option>
                                        <option value="started" <?php echo $reg['status'] === 'started' ? 'selected' : ''; ?>>Started</option>
                                        <option value="completed" <?php echo $reg['status'] === 'completed' ? 'selected' : ''; ?>>Completed</option>
                                        <option value="cancelled" <?php echo $reg['status'] === 'cancelled' ? 'selected' : ''; ?>>Cancelled</option>
                                    </select>
                                </td>
                                <td><?php echo htmlspecialchars($reg['assigned_staff'] ?? 'Unassigned'); ?></td>
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
                <h2>Client Details</h2>
                <button class="close-btn" onclick="closeModal('detailsModal')">&times;</button>
            </div>
            <div class="modal-body" id="detailsContent"></div>
        </div>
    </div>

    <!-- Edit Modal -->
    <div id="editModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h2>Update Client</h2>
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
                        <textarea id="noteText" placeholder="Add notes about this client..."></textarea>
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
        const registrations = <?php echo json_encode($registrations); ?>;

        function viewDetails(id) {
            const reg = registrations.find(r => r.id === id);
            if (!reg) return;

            const content = `
                <div class="detail-row"><div class="detail-label">Full Name</div><div class="detail-value">${reg.first_name} ${reg.last_name}</div></div>
                <div class="detail-row"><div class="detail-label">Email</div><div class="detail-value"><a href="mailto:${reg.email}" style="color:#06b6d4;">${reg.email}</a></div></div>
                <div class="detail-row"><div class="detail-label">Phone</div><div class="detail-value">${reg.phone}</div></div>
                <div class="detail-row"><div class="detail-label">Course</div><div class="detail-value">${reg.course_name || 'N/A'}</div></div>
                <div class="detail-row"><div class="detail-label">Level</div><div class="detail-value">${reg.level || 'N/A'}</div></div>
                <div class="detail-row"><div class="detail-label">Offer</div><div class="detail-value">${reg.offer || 'N/A'}</div></div>
                <div class="detail-row"><div class="detail-label">Status</div><div class="detail-value"><span class="status-badge status-${reg.status}">${reg.status.toUpperCase()}</span></div></div>
                <div class="detail-row"><div class="detail-label">Assigned To</div><div class="detail-value">${reg.assigned_staff || 'Unassigned'}</div></div>
                <div class="detail-row"><div class="detail-label">Inquiry Date</div><div class="detail-value">${new Date(reg.inquiry_date).toLocaleDateString()}</div></div>
                ${reg.notes ? `<div class="detail-row"><div class="detail-label">Notes</div><div class="detail-value">${reg.notes}</div></div>` : ''}
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
            document.getElementById('editModal').classList.add('active');
        }

        function closeModal(modalId) {
            document.getElementById(modalId).classList.remove('active');
            document.getElementById('messageBox').innerHTML = '';
        }

        function updateStatus(id, status) {
            fetch(window.location.href, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: `action=update_status&id=${id}&status=${status}`
            })
            .then(r => r.json())
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
            const messageBox = document.getElementById('messageBox');

            const note = document.getElementById('noteText').value;

            const requests = [];
            requests.push(fetch(window.location.href, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: `action=assign_staff&id=${id}&staff_id=${staffId}`
            }));

            if (note !== '') {
                requests.push(fetch(window.location.href, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: `action=add_note&id=${id}&note=${encodeURIComponent(note)}`
                }));
            }

            Promise.all(requests).then(() => {
                messageBox.innerHTML = '<div class="message success">✓ Changes saved successfully</div>';
                setTimeout(() => location.reload(), 1200);
            });
        }

        window.onclick = function(event) {
            const detailsModal = document.getElementById('detailsModal');
            const editModal = document.getElementById('editModal');
            if (event.target === detailsModal) detailsModal.classList.remove('active');
            if (event.target === editModal) editModal.classList.remove('active');
        }
    </script>
</body>
</html>
