-- create database
CREATE DATABASE IF NOT EXISTS `cs336project`;
USE `cs336project`;

-- disable foreign key checks so can drop tables on re-execution of sql
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS Reservation;
DROP TABLE IF EXISTS Schedule;
DROP TABLE IF EXISTS TrainStop;
DROP TABLE IF EXISTS TransitLine;
DROP TABLE IF EXISTS Passenger;
DROP TABLE IF EXISTS Forum;
DROP TABLE IF EXISTS Employee;
DROP TABLE IF EXISTS Station;
DROP TABLE IF EXISTS Train;

-- re-enable foreign key checks before re-creating tables
SET FOREIGN_KEY_CHECKS = 1;

-- =========================
-- Independent tables
-- =========================

CREATE TABLE Train (
    train_id INT NOT NULL,
    
    PRIMARY KEY (train_id),
    CONSTRAINT chk_train_id
        CHECK (train_id BETWEEN 1000 AND 9999)
) ENGINE = InnoDB;

CREATE TABLE Station (
    station_id INT NOT NULL AUTO_INCREMENT,
    station_name VARCHAR(50) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(25) NOT NULL,
    
    PRIMARY KEY (station_id)
) ENGINE = InnoDB;

CREATE TABLE Forum (
    message_id INT NOT NULL AUTO_INCREMENT,
    message_date DATETIME NOT NULL,
    body_text VARCHAR(500) NOT NULL,
    username VARCHAR(50) NOT NULL,
    reply_to INT NULL,

    PRIMARY KEY (message_id),
    FOREIGN KEY (reply_to) REFERENCES Forum (message_id)
        ON DELETE CASCADE
) ENGINE = InnoDB;

CREATE TABLE Employee (
    ssn VARCHAR(11) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    username VARCHAR(50) NOT NULL,
    `password` VARCHAR(100) NOT NULL,
    `role` VARCHAR(20) NOT NULL,
    -- role is 'manager' or 'customer_rep'
    message_id INT,
    -- only relevant for customer_rep role
    
    PRIMARY KEY (ssn),
    UNIQUE KEY uq_employee_username (username),

    CONSTRAINT fk_employee_message
        FOREIGN KEY (message_id)
        REFERENCES Forum (message_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE = InnoDB;


-- =========================
-- Transit line
-- =========================

CREATE TABLE TransitLine (
    line_id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(20) NOT NULL,
    fare INT NOT NULL,
    station_id INT,
    
    PRIMARY KEY (line_id),

    CONSTRAINT fk_transitline_station
        FOREIGN KEY (station_id)
        REFERENCES Station (station_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE = InnoDB;


-- =========================
-- Train stop
-- =========================

CREATE TABLE TrainStop (
    stop_id INT NOT NULL AUTO_INCREMENT,
    line_id INT NOT NULL,
    station_id INT NOT NULL,
    arrival_datetime DATETIME,
    departure_datetime DATETIME,
    
    PRIMARY KEY (stop_id),

    CONSTRAINT fk_trainstop_line
        FOREIGN KEY (line_id)
        REFERENCES TransitLine (line_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_trainstop_station
        FOREIGN KEY (station_id)
        REFERENCES Station (station_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE = InnoDB;


-- =========================
-- Schedule
-- =========================

CREATE TABLE Schedule (
    schedule_id INT NOT NULL AUTO_INCREMENT,
    stops VARCHAR(100),
    arrival_time DATETIME,
    departure_time DATETIME,
    line_id INT NOT NULL,
    train_id INT NOT NULL,
    stop_id INT NOT NULL,
    
    PRIMARY KEY (schedule_id),

    CONSTRAINT fk_schedule_train
        FOREIGN KEY (train_id)
        REFERENCES Train (train_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_schedule_line
        FOREIGN KEY (line_id)
        REFERENCES TransitLine (line_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_schedule_stop
        FOREIGN KEY (stop_id)
        REFERENCES TrainStop (stop_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;


-- =========================
-- Passenger
-- =========================

CREATE TABLE Passenger (
    username VARCHAR(50) NOT NULL,
    `password` VARCHAR(100) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    message_id INT,
    
    PRIMARY KEY (username),
    UNIQUE KEY uq_passenger_email (email),

    CONSTRAINT fk_passenger_message
        FOREIGN KEY (message_id)
        REFERENCES Forum (message_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE = InnoDB;


-- =========================
-- Reservation
-- =========================

CREATE TABLE Reservation (
    reservation_id INT NOT NULL AUTO_INCREMENT,
    trip_type VARCHAR(20) NOT NULL,
    passenger_type VARCHAR(10) NOT NULL,
    -- passenger types are 'Child' 'Adult' or 'Senior'
    reservation_date DATE NOT NULL,
    schedule_id INT NOT NULL,
    passenger_username VARCHAR(50) NOT NULL,
    stop_id INT NOT NULL,
    
    PRIMARY KEY (reservation_id),

    CONSTRAINT fk_reservation_schedule
        FOREIGN KEY (schedule_id)
        REFERENCES Schedule (schedule_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_reservation_stop
        FOREIGN KEY (stop_id)
        REFERENCES TrainStop (stop_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_reservation_passenger
        FOREIGN KEY (passenger_username)
        REFERENCES Passenger (username)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE = InnoDB;


-- =========================
-- Default Login:
-- =========================

INSERT INTO Employee (ssn, first_name, last_name, username, password, role)
VALUES ('123-45-6789', 'John', 'Smith', 'Admin', 'adminpass', 'manager');
