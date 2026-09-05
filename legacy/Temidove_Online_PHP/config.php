<?php
/**
 * Temidove Smart Solutions
 * Database Configuration & Connection
 */

// Database Configuration
define('DB_HOST', 'localhost');
define('DB_USER', 'root');           // Default WAMP username
define('DB_PASS', '');               // Default WAMP password (empty)
define('DB_NAME', 'temidove_db');

// Create connection
$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);

// Check connection
if ($conn->connect_error) {
    die("Database Connection Failed: " . $conn->connect_error);
}

// Set charset to utf8
$conn->set_charset("utf8mb4");

// Application Settings
define('APP_NAME', 'Temidove Smart Solutions');
define('APP_URL', 'http://localhost/temidove');
define('SESSION_TIMEOUT', 3600); // 1 hour

// Start session if not started
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Check if user session has expired
if (isset($_SESSION['user_id'])) {
    if (time() - $_SESSION['last_activity'] > SESSION_TIMEOUT) {
        session_destroy();
        header('Location: logout.php');
        exit();
    }
    $_SESSION['last_activity'] = time();
}

// Function to check if user is logged in
function isLoggedIn() {
    return isset($_SESSION['user_id']) && isset($_SESSION['username']);
}

// Function to check user role
function isAdmin() {
    return isset($_SESSION['role']) && $_SESSION['role'] === 'admin';
}

// Function to redirect to login if not logged in
function requireLogin() {
    if (!isLoggedIn()) {
        header('Location: login.php');
        exit();
    }
}

// Function to sanitize input
function sanitize($input) {
    return htmlspecialchars(strip_tags(trim($input)), ENT_QUOTES, 'UTF-8');
}

// Function to escape for database
function dbEscape($string) {
    global $conn;
    return $conn->real_escape_string($string);
}
?>
