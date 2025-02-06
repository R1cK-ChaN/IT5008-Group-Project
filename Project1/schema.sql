-- ==============================================
-- Customers table
-- ==============================================
CREATE TABLE customers (
    nric VARCHAR(9) PRIMARY KEY,  -- Primary identifier
    name VARCHAR(50) NOT NULL,
    date_of_birth DATE NOT NULL,
    car_pref_brand VARCHAR(20),   -- Preferred car brand
    car_pref_model VARCHAR(20),   -- Preferred car model
    has_driving_license BOOLEAN DEFAULT FALSE,

    CONSTRAINT chk_nric_format CHECK (nric REGEXP '^[A-Z][0-9]{7}[A-Z]$')
);

-- ==============================================
-- CarMake table
-- ==============================================
CREATE TABLE carmake (
    brand VARCHAR(64) NOT NULL,  
    model VARCHAR(64) NOT NULL,  
    capacity INT NOT NULL CHECK (capacity > 0),
    PRIMARY KEY (brand, model)
);

-- ==============================================
-- Car table
-- ==============================================
CREATE TABLE car (
    license_plate CHAR(8) NOT NULL PRIMARY KEY,
    color VARCHAR(64) NOT NULL,
    brand VARCHAR(64) NOT NULL,  
    model VARCHAR(64) NOT NULL,

    -- Singapore format: S + 2 letters + 4 numbers + 1 letter
    CHECK (license_plate REGEXP '^S[A-Z]{2}[0-9]{4}[A-Z]$'),

    FOREIGN KEY (brand, model) REFERENCES carmake (brand, model)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- ==============================================
-- Rentals table
-- ==============================================
CREATE TABLE rentals (
    rental_id INT AUTO_INCREMENT PRIMARY KEY,
    nric VARCHAR(9) NOT NULL,
    license_plate CHAR(8) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    CHECK (start_date <= end_date),

    FOREIGN KEY (nric) REFERENCES customers(nric)
        ON DELETE CASCADE,

    FOREIGN KEY (license_plate) REFERENCES car(license_plate)
        ON DELETE CASCADE
);

-- ==============================================
-- Passengers table
-- ==============================================
CREATE TABLE passengers (
    rental_id INT NOT NULL,
    passenger_nric VARCHAR(9) NOT NULL,

    PRIMARY KEY (rental_id, passenger_nric),

    FOREIGN KEY (rental_id) REFERENCES rentals(rental_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    FOREIGN KEY (passenger_nric) REFERENCES customers(nric)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- avoid overlapping rental
CREATE TRIGGER check_rental_overlap
BEFORE INSERT ON rentals
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM rentals
        WHERE license_plate = NEW.license_plate
        AND (NEW.start_date BETWEEN start_date AND end_date
            OR NEW.end_date BETWEEN start_date AND end_date
            OR start_date BETWEEN NEW.start_date AND NEW.end_date)
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'already rented';
    END IF;
END;

-- avoid exceeding passenger capacity
CREATE TRIGGER check_passenger_capacity
BEFORE INSERT ON passengers
FOR EACH ROW
BEGIN
    DECLARE max_capacity INT;
    DECLARE current_passengers INT;
    
    -- check the capacity of the car
    SELECT c.capacity INTO max_capacity
    FROM rentals r
    JOIN car c ON r.license_plate = c.license_plate
    WHERE r.rental_id = NEW.rental_id;
    
    -- check the number of passengers
    SELECT COUNT(*) INTO current_passengers
    FROM passengers
    WHERE rental_id = NEW.rental_id;
    
    -- if exceeds the capacity, raise an error
    IF current_passengers >= max_capacity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'exceeds the passenger capacity';
    END IF;
END;
