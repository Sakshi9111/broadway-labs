USE school;

CREATE TABLE students (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE courses (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    credits INT NOT NULL
);

CREATE TABLE enrollments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    enrolled_at DATE NOT NULL,

    CONSTRAINT fk_enrollment_student
        FOREIGN KEY (student_id)
        REFERENCES students(id),

    CONSTRAINT fk_enrollment_course
        FOREIGN KEY (course_id)
        REFERENCES courses(id),

    CONSTRAINT uq_student_course
        UNIQUE (student_id, course_id)
);

INSERT INTO students (name, email) VALUES
('Asha Sharma', 'asha@example.com'),
('Ravi Thapa', 'ravi@example.com'),
('Mina Gurung', 'mina@example.com'),
('Suman KC', 'suman@example.com'),
('Priya Rai', 'priya@example.com');

INSERT INTO courses (name, credits) VALUES
('Database Systems', 3),
('Web Development', 3),
('Java Programming', 4),
('Computer Networks', 3);

INSERT INTO enrollments (student_id, course_id, enrolled_at) VALUES
(1, 1, '2026-09-01'),
(1, 2, '2026-09-01'),
(2, 1, '2026-09-02'),
(2, 3, '2026-09-02'),
(3, 2, '2026-09-03'),
(3, 3, '2026-09-03'),
(3, 4, '2026-09-03'),
(4, 1, '2026-09-04'),
(4, 4, '2026-09-04'),
(5, 2, '2026-09-05'),
(5, 3, '2026-09-05');