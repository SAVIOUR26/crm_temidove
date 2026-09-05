<?php
require_once 'config.php';

$error = '';
$success = '';
$courses = [];

// Fetch all available courses
$result = $conn->query("SELECT id, course_name, description, price FROM courses ORDER BY course_name ASC");
if ($result) {
    while ($row = $result->fetch_assoc()) {
        $courses[] = $row;
    }
}

// Handle registration form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $first_name = sanitize($_POST['first_name'] ?? '');
    $last_name = sanitize($_POST['last_name'] ?? '');
    $email = sanitize($_POST['email'] ?? '');
    $phone = sanitize($_POST['phone'] ?? '');
    $course_id = intval($_POST['course_id'] ?? 0);
    $level = sanitize($_POST['level'] ?? '');
    $offer = sanitize($_POST['offer'] ?? '');

    // Allowed values for level and offer (must match the ENUM in the database)
    $allowed_levels = ['prelevel', 'level 1', 'level 1 plus', 'level 2', 'level 3', 'advanced level in english'];
    $allowed_offers = ['offer 1', 'offer 2', 'offer 3'];

    // Validation
    if (empty($first_name) || empty($last_name) || empty($email) || empty($phone) || $course_id === 0 || empty($level) || empty($offer)) {
        $error = 'Please fill in all required fields.';
    } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $error = 'Please enter a valid email address.';
    } elseif (!in_array(strtolower($level), $allowed_levels)) {
        $error = 'Please select a valid level.';
    } elseif (!in_array(strtolower($offer), $allowed_offers)) {
        $error = 'Please select a valid offer.';
    } else {
        // Insert registration
        $stmt = $conn->prepare(
            "INSERT INTO registrations (first_name, last_name, email, phone, course_id, level, offer, status) 
             VALUES (?, ?, ?, ?, ?, ?, ?, 'waiting')"
        );
        
        if ($stmt) {
            $stmt->bind_param("ssssiss", $first_name, $last_name, $email, $phone, $course_id, $level, $offer);
            
            if ($stmt->execute()) {
                $success = 'Your inquiry has been submitted successfully! Our team will contact you soon.';
                // Clear form
                $_POST = array();
            } else {
                $error = 'Error submitting inquiry. Please try again.';
            }
            $stmt->close();
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Course Inquiry - Temidove Smart Solutions</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f8fafc;
            line-height: 1.6;
        }

        .navbar {
            background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%);
            color: white;
            padding: 15px 0;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }

        .navbar-content {
            max-width: 1000px;
            margin: 0 auto;
            padding: 0 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .navbar h2 {
            font-size: 20px;
        }

        .navbar-links a {
            color: white;
            text-decoration: none;
            margin-left: 20px;
            font-size: 14px;
            transition: opacity 0.3s;
        }

        .navbar-links a:hover {
            opacity: 0.8;
        }

        .container {
            max-width: 700px;
            margin: 40px auto;
            padding: 0 20px;
        }

        .form-card {
            background: white;
            border-radius: 10px;
            box-shadow: 0 5px 20px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }

        .form-header {
            background: linear-gradient(135deg, #06b6d4 0%, #0891b2 100%);
            padding: 30px;
            color: white;
            text-align: center;
        }

        .form-header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }

        .form-header p {
            opacity: 0.9;
            font-size: 14px;
        }

        .form-body {
            padding: 40px;
        }

        .form-group {
            margin-bottom: 25px;
        }

        label {
            display: block;
            margin-bottom: 8px;
            color: #1e3a8a;
            font-weight: 600;
            font-size: 14px;
        }

        .required {
            color: #dc2626;
        }

        input[type="text"],
        input[type="email"],
        input[type="tel"],
        select {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e7ff;
            border-radius: 6px;
            font-size: 14px;
            font-family: inherit;
            transition: border-color 0.3s;
        }

        input[type="text"]:focus,
        input[type="email"]:focus,
        input[type="tel"]:focus,
        select:focus {
            outline: none;
            border-color: #06b6d4;
            box-shadow: 0 0 0 3px rgba(6, 182, 212, 0.1);
        }

        .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }

        @media (max-width: 600px) {
            .form-row {
                grid-template-columns: 1fr;
            }
        }

        .course-description {
            background: #f0f4f8;
            padding: 10px 12px;
            border-radius: 4px;
            font-size: 13px;
            color: #475569;
            margin-top: 5px;
        }

        .course-price {
            color: #16a34a;
            font-weight: 600;
            font-size: 14px;
        }

        .error-message {
            background-color: #fee2e2;
            color: #dc2626;
            padding: 15px;
            border-radius: 6px;
            margin-bottom: 20px;
            border-left: 4px solid #dc2626;
        }

        .success-message {
            background-color: #dcfce7;
            color: #16a34a;
            padding: 15px;
            border-radius: 6px;
            margin-bottom: 20px;
            border-left: 4px solid #16a34a;
        }

        .btn-submit {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #1e3a8a 0%, #06b6d4 100%);
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }

        .btn-submit:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(6, 182, 212, 0.3);
        }

        .btn-submit:active {
            transform: translateY(0);
        }

        .info-text {
            background: #f0f9ff;
            padding: 15px;
            border-left: 4px solid #06b6d4;
            border-radius: 4px;
            font-size: 13px;
            color: #0c4a6e;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="navbar">
        <div class="navbar-content">
            <h2>Temidove Smart Solutions</h2>
            <div class="navbar-links">
                <a href="login.php">Staff Login</a>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="form-card">
            <div class="form-header">
                <h1>Course Inquiry</h1>
                <p>Register your interest in one of our courses</p>
            </div>

            <div class="form-body">
                <?php if (!empty($error)): ?>
                    <div class="error-message"><?php echo $error; ?></div>
                <?php endif; ?>

                <?php if (!empty($success)): ?>
                    <div class="success-message"><?php echo $success; ?></div>
                <?php endif; ?>

                <form method="POST" action="">
                    <div class="form-row">
                        <div class="form-group">
                            <label for="first_name">First Name <span class="required">*</span></label>
                            <input type="text" id="first_name" name="first_name" required value="<?php echo $_POST['first_name'] ?? ''; ?>">
                        </div>
                        <div class="form-group">
                            <label for="last_name">Last Name <span class="required">*</span></label>
                            <input type="text" id="last_name" name="last_name" required value="<?php echo $_POST['last_name'] ?? ''; ?>">
                        </div>
                    </div>

                    <div class="form-group">
                        <label for="email">Email Address <span class="required">*</span></label>
                        <input type="email" id="email" name="email" required value="<?php echo $_POST['email'] ?? ''; ?>">
                    </div>

                    <div class="form-group">
                        <label for="phone">Phone Number <span class="required">*</span></label>
                        <input type="tel" id="phone" name="phone" required value="<?php echo $_POST['phone'] ?? ''; ?>">
                    </div>

                    <div class="form-group">
                        <label for="course_id">Select Course <span class="required">*</span></label>
                        <select id="course_id" name="course_id" required onchange="updateCourseInfo()">
                            <option value="">-- Choose a Course --</option>
                            <?php foreach ($courses as $course): ?>
                                <option value="<?php echo $course['id']; ?>">
                                    <?php echo $course['course_name']; ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                        <div id="course-info"></div>
                    </div>

                    <div class="form-row">
                        <div class="form-group">
                            <label for="level">Level <span class="required">*</span></label>
                            <select id="level" name="level" required>
                                <option value="">-- Select Level --</option>
                                <option value="prelevel" <?php echo (($_POST['level'] ?? '') === 'prelevel') ? 'selected' : ''; ?>>Prelevel</option>
                                <option value="level 1" <?php echo (($_POST['level'] ?? '') === 'level 1') ? 'selected' : ''; ?>>Level 1</option>
                                <option value="level 1 plus" <?php echo (($_POST['level'] ?? '') === 'level 1 plus') ? 'selected' : ''; ?>>Level 1 Plus</option>
                                <option value="level 2" <?php echo (($_POST['level'] ?? '') === 'level 2') ? 'selected' : ''; ?>>Level 2</option>
                                <option value="level 3" <?php echo (($_POST['level'] ?? '') === 'level 3') ? 'selected' : ''; ?>>Level 3</option>
                                <option value="advanced level in english" <?php echo (($_POST['level'] ?? '') === 'advanced level in english') ? 'selected' : ''; ?>>Advanced Level in English</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label for="offer">Offer <span class="required">*</span></label>
                            <select id="offer" name="offer" required>
                                <option value="">-- Select Offer --</option>
                                <option value="offer 1" <?php echo (($_POST['offer'] ?? '') === 'offer 1') ? 'selected' : ''; ?>>Offer 1</option>
                                <option value="offer 2" <?php echo (($_POST['offer'] ?? '') === 'offer 2') ? 'selected' : ''; ?>>Offer 2</option>
                                <option value="offer 3" <?php echo (($_POST['offer'] ?? '') === 'offer 3') ? 'selected' : ''; ?>>Offer 3</option>
                            </select>
                        </div>
                    </div>

                    <button type="submit" class="btn-submit">Submit Inquiry</button>
                </form>

                <div class="info-text">
                    ℹ️ After submitting your inquiry, our team will review your request and contact you within 24-48 hours to discuss course details and enrollment options.
                </div>
            </div>
        </div>
    </div>

    <script>
        const courses = <?php echo json_encode($courses); ?>;

        function updateCourseInfo() {
            const select = document.getElementById('course_id');
            const courseInfo = document.getElementById('course-info');
            const selectedId = parseInt(select.value);

            if (selectedId > 0) {
                const course = courses.find(c => c.id === selectedId);
                if (course) {
                    courseInfo.innerHTML = `
                        <div class="course-description">
                            <p>${course.description}</p>
                            <p class="course-price">Fee: UGX ${parseInt(course.price).toLocaleString()}</p>
                        </div>
                    `;
                }
            } else {
                courseInfo.innerHTML = '';
            }
        }
    </script>
</body>
</html>
