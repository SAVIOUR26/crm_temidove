-- Temidove Smart Solutions - Database Setup
-- Import this file into phpMyAdmin to create the database and tables

CREATE DATABASE IF NOT EXISTS temidove_db;
USE temidove_db;

-- Admin/Staff Users Table
CREATE TABLE IF NOT EXISTS users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(50) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  full_name VARCHAR(100) NOT NULL,
  role ENUM('admin', 'staff') DEFAULT 'staff',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Courses Table
CREATE TABLE IF NOT EXISTS courses (
  id INT PRIMARY KEY AUTO_INCREMENT,
  course_name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  price DECIMAL(10, 2) DEFAULT 0,
  duration_weeks INT DEFAULT 8,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Client Registrations/Inquiries Table
CREATE TABLE IF NOT EXISTS registrations (
  id INT PRIMARY KEY AUTO_INCREMENT,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  course_id INT NOT NULL,
  level ENUM('prelevel', 'level 1', 'level 1 plus', 'level 2', 'level 3', 'advanced level in english') DEFAULT NULL,
  offer ENUM('offer 1', 'offer 2', 'offer 3') DEFAULT NULL,
  inquiry_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  status ENUM('waiting', 'started', 'completed', 'cancelled') DEFAULT 'waiting',
  notes TEXT,
  assigned_to INT,
  start_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (course_id) REFERENCES courses(id),
  FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL
);

-- Insert Default Courses
INSERT INTO courses (course_name, description, price, duration_weeks) VALUES
('English Language', 'Comprehensive English language training program', 150000, 12),
('Advanced Computer Skills', 'Advanced computer skills and IT training', 200000, 10),
('Accounting', 'Professional accounting and bookkeeping', 250000, 12),
('Video Editing', 'Professional video editing and production', 300000, 8),
('Graphics & Camera Shooting', 'Graphics design and professional photography', 280000, 10),
('Art Painting', 'Traditional and digital art painting', 180000, 8),
('Programming Languages', 'Web and app development programming', 350000, 16),
('Website Designing', 'Professional web design and development', 300000, 12),
('Digital Marketing', 'Digital marketing and social media strategy', 220000, 8),
('Content Creation', 'Professional content creation and editing', 240000, 8),
('Business Management', 'Business strategy and management skills', 200000, 10);

-- Insert Default Admin User (username: admin, password: admin123)
INSERT INTO users (username, password, email, full_name, role) VALUES
('admin', '$2y$10$9Y0dTfCWF7h2dRYBnvHBpO0eKcJwPvZE3Vt0k5mH7xK9L2qR8vXXm', 'admin@temidove.com', 'Admin User', 'admin');

-- Insert Sample Staff Users
INSERT INTO users (username, password, email, full_name, role) VALUES
('instructor1', '$2y$10$9Y0dTfCWF7h2dRYBnvHBpO0eKcJwPvZE3Vt0k5mH7xK9L2qR8vXXm', 'instructor1@temidove.com', 'John Instructor', 'staff'),
('instructor2', '$2y$10$9Y0dTfCWF7h2dRYBnvHBpO0eKcJwPvZE3Vt0k5mH7xK9L2qR8vXXm', 'instructor2@temidove.com', 'Jane Staff', 'staff');

-- Note: Default password for all accounts is "admin123"
