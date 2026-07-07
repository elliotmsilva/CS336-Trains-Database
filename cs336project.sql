CREATE DATABASE IF NOT EXISTS `cs336project`;
USE `cs336project`;

DROP TABLE IF EXISTS passenger;
CREATE TABLE passenger (
    passenger_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name  VARCHAR(50),
    last_name   VARCHAR(50),
    email       VARCHAR(100),
    username    VARCHAR(50) UNIQUE NOT NULL,
    password    VARCHAR(50) NOT NULL
);

DROP TABLE IF EXISTS employee;
CREATE TABLE employee (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    ssn         VARCHAR(11),
    first_name  VARCHAR(50),
    last_name   VARCHAR(50),
    username    VARCHAR(50) UNIQUE NOT NULL,
    password    VARCHAR(50) NOT NULL,
    role        VARCHAR(20) NOT NULL               -- 'manager' or 'rep'
);

-- random test users
INSERT INTO passenger (first_name, last_name, email, username, password)
VALUES ('John', 'Smith', 'john@email.com', 'jsmith', 'password123');

INSERT INTO employee (ssn, first_name, last_name, username, password, role)
VALUES ('123-45-6789', 'Jane', 'Doe', 'jdoe', 'admin123', 'rep');

INSERT INTO employee (ssn, first_name, last_name, username, password, role)
VALUES ('000-00-0000', 'Elliot', 'Silva', 'es1242', 'es1242', 'manager');
