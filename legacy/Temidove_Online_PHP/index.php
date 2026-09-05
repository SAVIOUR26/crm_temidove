<?php
require_once 'config.php';

// Redirect logged in users to dashboard
if (isLoggedIn()) {
    header('Location: dashboard.php');
    exit();
}

// Get courses for the courses section
$courses_result = $conn->query("SELECT id, course_name, description FROM courses ORDER BY course_name ASC LIMIT 9");
$featured_courses = [];
while ($row = $courses_result->fetch_assoc()) {
    $featured_courses[] = $row;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Temidove Smart Solutions - Online Training</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
        }

        /* Navigation */
        nav {
            background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%);
            padding: 15px 0;
            position: sticky;
            top: 0;
            z-index: 100;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }

        .nav-content {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .logo {
            color: white;
            font-size: 22px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .nav-links {
            display: flex;
            gap: 25px;
            align-items: center;
        }

        .nav-links a {
            color: white;
            text-decoration: none;
            font-size: 14px;
            transition: opacity 0.3s;
        }

        .nav-links a:hover {
            opacity: 0.8;
        }

        .btn-primary {
            background: linear-gradient(135deg, #06b6d4 0%, #0891b2 100%);
            color: white !important;
            padding: 10px 20px;
            border-radius: 6px;
            font-weight: 600;
            transition: transform 0.2s;
        }

        .btn-primary:hover {
            transform: translateY(-2px);
            opacity: 1 !important;
        }

        /* Hero Section */
        .hero {
            background: linear-gradient(135deg, #06b6d4 0%, #0891b2 50%, #1e3a8a 100%);
            color: white;
            padding: 80px 20px;
            text-align: center;
        }

        .hero-content {
            max-width: 800px;
            margin: 0 auto;
        }

        .hero h1 {
            font-size: 48px;
            margin-bottom: 20px;
            font-weight: 700;
        }

        .hero p {
            font-size: 18px;
            margin-bottom: 30px;
            opacity: 0.95;
        }

        .hero-buttons {
            display: flex;
            gap: 15px;
            justify-content: center;
            flex-wrap: wrap;
        }

        .btn {
            padding: 14px 35px;
            border: 2px solid white;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: all 0.3s;
            display: inline-block;
        }

        .btn-light {
            background: white;
            color: #1e3a8a;
        }

        .btn-light:hover {
            transform: translateY(-3px);
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }

        .btn-outline {
            background: transparent;
            color: white;
        }

        .btn-outline:hover {
            background: white;
            color: #06b6d4;
        }

        /* Main Container */
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 20px;
        }

        /* Courses Section */
        .section {
            padding: 60px 20px;
        }

        .section-title {
            text-align: center;
            font-size: 36px;
            color: #1e3a8a;
            margin-bottom: 50px;
            font-weight: 700;
        }

        .courses-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
        }

        .course-card {
            background: white;
            border-radius: 10px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
            overflow: hidden;
            transition: all 0.3s;
        }

        .course-card:hover {
            transform: translateY(-10px);
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.15);
        }

        .course-card-header {
            background: linear-gradient(135deg, #1e3a8a 0%, #06b6d4 100%);
            padding: 30px;
            color: white;
            text-align: center;
        }

        .course-card-title {
            font-size: 20px;
            font-weight: 600;
            margin-bottom: 10px;
        }

        .course-card-body {
            padding: 25px;
        }

        .course-description {
            color: #475569;
            font-size: 14px;
            margin-bottom: 20px;
            line-height: 1.6;
        }

        .course-cta {
            background: linear-gradient(135deg, #06b6d4 0%, #0891b2 100%);
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 600;
            width: 100%;
            transition: opacity 0.3s;
        }

        .course-cta:hover {
            opacity: 0.9;
        }

        /* Features Section */
        .features {
            background: #f8fafc;
        }

        .features-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 30px;
        }

        .feature-item {
            background: white;
            padding: 30px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
        }

        .feature-icon {
            font-size: 48px;
            margin-bottom: 15px;
        }

        .feature-title {
            font-size: 18px;
            color: #1e3a8a;
            font-weight: 600;
            margin-bottom: 10px;
        }

        .feature-text {
            color: #64748b;
            font-size: 14px;
        }

        /* Footer */
        footer {
            background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%);
            color: white;
            text-align: center;
            padding: 30px 20px;
            margin-top: 50px;
        }

        footer p {
            margin-bottom: 10px;
            font-size: 14px;
        }

        /* Stats Section */
        .stats {
            background: linear-gradient(135deg, #1e3a8a 0%, #06b6d4 100%);
            color: white;
            padding: 50px 20px;
        }

        .stats-content {
            max-width: 1200px;
            margin: 0 auto;
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 40px;
            text-align: center;
        }

        .stat-box h3 {
            font-size: 36px;
            font-weight: 700;
            margin-bottom: 10px;
        }

        .stat-box p {
            font-size: 14px;
            opacity: 0.9;
        }

        @media (max-width: 768px) {
            .hero h1 {
                font-size: 32px;
            }

            .nav-links {
                gap: 15px;
            }

            .nav-links a {
                font-size: 12px;
            }

            .btn {
                padding: 10px 20px;
                font-size: 14px;
            }

            .section-title {
                font-size: 28px;
            }
        }
    </style>
</head>
<body>
    <!-- Navigation -->
    <nav>
        <div class="nav-content">
            <div class="logo">
                🎓 Temidove Smart Solutions
            </div>
            <div class="nav-links">
                <a href="#courses">Courses</a>
                <a href="#about">About</a>
                <a href="login.php">Staff Login</a>
                <a href="register.php" class="btn-primary">Inquire Now</a>
            </div>
        </div>
    </nav>

    <!-- Hero Section -->
    <div class="hero">
        <div class="hero-content">
            <h1>Transform Your Skills with Temidove</h1>
            <p>Comprehensive online training in technology, business, and creative fields</p>
            <div class="hero-buttons">
                <a href="register.php" class="btn btn-light">Start Your Inquiry</a>
                <a href="#courses" class="btn btn-outline">Explore Courses</a>
            </div>
        </div>
    </div>

    <!-- Statistics -->
    <div class="stats">
        <div class="stats-content">
            <div class="stats-grid">
                <div class="stat-box">
                    <h3>11+</h3>
                    <p>Professional Courses</p>
                </div>
                <div class="stat-box">
                    <h3>100%</h3>
                    <p>Online Access</p>
                </div>
                <div class="stat-box">
                    <h3>Expert</h3>
                    <p>Instructors</p>
                </div>
                <div class="stat-box">
                    <h3>Flexible</h3>
                    <p>Schedule</p>
                </div>
            </div>
        </div>
    </div>

    <!-- Featured Courses -->
    <div id="courses" class="section">
        <div class="container">
            <h2 class="section-title">Our Courses</h2>
            <div class="courses-grid">
                <?php foreach ($featured_courses as $course): ?>
                    <div class="course-card">
                        <div class="course-card-header">
                            <div class="course-card-title"><?php echo htmlspecialchars($course['course_name']); ?></div>
                        </div>
                        <div class="course-card-body">
                            <p class="course-description"><?php echo htmlspecialchars($course['description'] ?? 'Comprehensive training program'); ?></p>
                            <button class="course-cta" onclick="window.location.href='register.php?course=<?php echo $course['id']; ?>'">
                                Inquire About This Course
                            </button>
                        </div>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>
    </div>

    <!-- Features Section -->
    <div class="features section">
        <div class="container">
            <h2 class="section-title">Why Choose Us?</h2>
            <div class="features-grid">
                <div class="feature-item">
                    <div class="feature-icon">💻</div>
                    <h3 class="feature-title">Technology-Focused</h3>
                    <p class="feature-text">Latest industry tools and technologies in every course</p>
                </div>
                <div class="feature-item">
                    <div class="feature-icon">👨‍🏫</div>
                    <h3 class="feature-title">Expert Instructors</h3>
                    <p class="feature-text">Learn from experienced professionals in their fields</p>
                </div>
                <div class="feature-item">
                    <div class="feature-icon">🎯</div>
                    <h3 class="feature-title">Career Support</h3>
                    <p class="feature-text">Guidance and support to achieve your goals</p>
                </div>
                <div class="feature-item">
                    <div class="feature-icon">🌍</div>
                    <h3 class="feature-title">Online Access</h3>
                    <p class="feature-text">Learn from anywhere at your own pace</p>
                </div>
                <div class="feature-item">
                    <div class="feature-icon">📊</div>
                    <h3 class="feature-title">Progress Tracking</h3>
                    <p class="feature-text">Monitor your learning journey with detailed analytics</p>
                </div>
                <div class="feature-item">
                    <div class="feature-icon">🏆</div>
                    <h3 class="feature-title">Certification</h3>
                    <p class="feature-text">Earn recognized certificates upon completion</p>
                </div>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <footer>
        <div class="container">
            <h3>Temidove Smart Solutions</h3>
            <p>Empowering learners with skills for the digital future</p>
            <p style="margin-top: 20px; opacity: 0.7; font-size: 12px;">
                &copy; 2024 Temidove Smart Solutions. All rights reserved.
            </p>
        </div>
    </footer>
</body>
</html>
