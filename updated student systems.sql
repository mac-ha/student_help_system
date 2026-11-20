-- Schools table
CREATE TABLE schools (
    school_id SERIAL PRIMARY KEY,
    school_name VARCHAR(100) NOT NULL
);

-- Programs table
CREATE TABLE programs (
    program_id SERIAL PRIMARY KEY,
    program_name VARCHAR(100) NOT NULL,
    school_id INT REFERENCES schools(school_id) ON DELETE CASCADE
);

-- Students table
CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    student_number VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    school_id INT REFERENCES schools(school_id),
    program_id INT REFERENCES programs(program_id)
);

-- Courses table
CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    course_code VARCHAR(20) UNIQUE NOT NULL,
    course_name VARCHAR(100) NOT NULL,
    program_id INT REFERENCES programs(program_id)
);

-- Registrations table (student-course relationship)
CREATE TABLE registrations (
    registration_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(student_id) ON DELETE CASCADE,
    course_code VARCHAR(20) REFERENCES courses(course_code) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'enrolled'
);


-- HOD table
CREATE TABLE hods (
    hod_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    school_id INT REFERENCES schools(school_id)
);

-- Approvals table (tracks student requests)
CREATE TABLE approvals (
    approval_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(student_id),
    request_type VARCHAR(50) NOT NULL, -- e.g. change_program, drop_course
    status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
    hod_id INT REFERENCES hods(hod_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


INSERT INTO schools (school_name) VALUES ('School of Engineering'), ('School of Business');

INSERT INTO programs (program_name, school_id) VALUES 
('Computer Science', 1),
('Mechanical Engineering', 1),
('Accounting', 2);

INSERT INTO hods (name, email, school_id) VALUES
('Dr. Banda', 'banda@university.edu', 1),
('Prof. Mwale', 'mwale@university.edu', 2);


-- Add more programs to School of Engineering (school_id = 1)
INSERT INTO programs (program_name, school_id) VALUES
('Electrical Engineering', 1),
('Civil Engineering', 1),
('Software Engineering', 1),
('Information Technology', 1),
('Chemical Engineering', 1);

-- Add more programs to School of Business (school_id = 2)
INSERT INTO programs (program_name, school_id) VALUES
('Finance', 2),
('Marketing', 2),
('Human Resource Management', 2),
('Economics', 2),
('Business Administration', 2);






-- Insert courses into courses table
INSERT INTO courses (course_code, course_name, program_id) VALUES
('CS101', 'Intro to Programming', 1),
('CS102', 'Data Structures', 1),
('CS103', 'Databases', 1),
('BUS101', 'Principles of Accounting', 2),
('BUS102', 'Business Law', 2);



INSERT INTO registrations (student_id, course_code, status)
VALUES (1,'CS101', 'enrolled');




SELECT st.student_number, st.name, c.course_code, c.course_name, r.status
FROM students st
JOIN registrations r ON st.student_id = r.student_id
JOIN courses c ON r.course_code = c.course_code
ORDER BY st.student_number, c.course_code;









SELECT course_id, course_code, course_name FROM courses;


select*from courses;


SELECT s.school_name, p.program_name
FROM schools s
JOIN programs p ON s.school_id = p.school_id
ORDER BY s.school_name, p.program_name;

select*from courses;

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'registrations';


DROP TABLE IF EXISTS registrations CASCADE;



CREATE TABLE registrations (
    registration_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(student_id) ON DELETE CASCADE,
    course_code VARCHAR(20) REFERENCES courses(course_code) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'enrolled'
);

INSERT INTO registrations (student_id, course_code, status)
VALUES (1, 'CS101', 'enrolled');




SELECT st.student_number, st.name, c.course_code, c.course_name, r.status
FROM students st
JOIN registrations r ON st.student_id = r.student_id
JOIN courses c ON r.course_code = c.course_code
ORDER BY st.student_number, c.course_code;




--------logic for a dropped course to be connected to the node server route

DO $$ 
DECLARE 
    v_student_id INT := 1;
    v_course_code VARCHAR(20) := 'CS101';
    v_rows_affected INT;
BEGIN 
    -- Update the registration status to dropped
    UPDATE registrations 
    SET status = 'dropped' 
    WHERE student_id = v_student_id 
      AND course_code = v_course_code 
      AND status = 'enrolled';
      
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected > 0 THEN
        RAISE NOTICE 'Success: Student % has successfully dropped course %.', v_student_id, v_course_code;
    ELSE
        RAISE NOTICE 'Notice: No active enrollment found for Student % in course %.', v_student_id, v_course_code;
    END IF;
END $$ LANGUAGE plpgsql;




-----logic for connectiion to the route on the node server


-- Step 1: Update the foreign key constraint to allow cascading updates (run once)
ALTER TABLE registrations 
DROP CONSTRAINT registrations_course_code_fkey,
ADD CONSTRAINT registrations_course_code_fkey 
    FOREIGN KEY (course_code) 
    REFERENCES courses(course_code) 
    ON UPDATE CASCADE 
    ON DELETE CASCADE;

-- Step 2: Now you can safely update a course code, and registrations will update automatically!
UPDATE courses 
SET course_code = 'CS104' 
WHERE course_code = 'CS101';

RAISE NOTICE 'Course code updated successfully from CS101 to CS104!';




--------logic for overloading the courses for a student

DO $$ 
DECLARE 
    v_student_id INT := 1;
    v_new_course VARCHAR(20) := 'CS102';
    v_active_count INT;
    v_max_allowed INT := 3; -- Example limit
BEGIN 
    -- 1. Count how many active courses the student is currently enrolled in
    SELECT COUNT(*) 
    INTO v_active_count
    FROM registrations
    WHERE student_id = v_student_id 
      AND status = 'enrolled';

    -- 2. Check if adding one more exceeds the limit
    IF v_active_count >= v_max_allowed THEN
        RAISE EXCEPTION 'Registration Denied: Student % has reached the maximum limit of % active courses (Currently enrolled in %).', 
            v_student_id, v_max_allowed, v_active_count;
    ELSE
        -- 3. If under the limit, proceed with insertion
        INSERT INTO registrations (student_id, course_code, status)
        VALUES (v_student_id, v_new_course, 'enrolled');
        
        RAISE NOTICE 'Success: Student % registered for %. Total active courses: %', 
            v_student_id, v_new_course, (v_active_count + 1);
    END IF;
END $$ LANGUAGE plpgsql;

select*from registrations;

