-- Group-18 members:
-- CHEN ZHIKUN A0310130J
-- QIN XINYUE A0243468X
-- HE YIHAN A0309390A
-- HUANG YIHE
-- Each member contributed equally in this project.

-- ==============================================
-- Customers table
-- ==============================================
CREATE TABLE customers (
    nric VARCHAR(9) PRIMARY KEY,  
    name VARCHAR(50) NOT NULL,
    date_of_birth DATE NOT NULL,
    car_pref_brand VARCHAR(20),  
    car_pref_model VARCHAR(20),  
    has_driving_license BOOLEAN DEFAULT FALSE,

    CONSTRAINT chk_nric_format CHECK (nric ~ '^[A-Z][0-9]{7}[A-Z]$')
);

-- ==============================================
-- CarMake table (stores brand & model capacity)
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
    license_plate CHAR(8) PRIMARY KEY,
    color VARCHAR(64) NOT NULL,
    brand VARCHAR(64) NOT NULL,  
    model VARCHAR(64) NOT NULL,

    CHECK (license_plate ~ '^S[A-Z]{2}[0-9]{4}[A-Z]$'),

    FOREIGN KEY (brand, model) REFERENCES carmake (brand, model)
        ON UPDATE CASCADE
);

-- ==============================================
-- Rentals table
-- ==============================================
CREATE TABLE rentals (
    rental_id SERIAL PRIMARY KEY,
    nric VARCHAR(9) NOT NULL,
    license_plate CHAR(8) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

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
        ON DELETE CASCADE,

    FOREIGN KEY (passenger_nric) REFERENCES customers(nric)
        ON DELETE CASCADE
);

-- ==============================================
-- TRIGGER: Prevent Overlapping Rentals
-- ==============================================
CREATE OR REPLACE FUNCTION prevent_rental_overlap()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM rentals
        WHERE NEW.license_plate = rentals.license_plate
        AND (NEW.start_date BETWEEN rentals.start_date AND rentals.end_date
             OR NEW.end_date BETWEEN rentals.start_date AND rentals.end_date
             OR rentals.start_date BETWEEN NEW.start_date AND NEW.end_date)
    ) THEN
        RAISE EXCEPTION 'Car is already rented during this period';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_rental_overlap
BEFORE INSERT ON rentals
FOR EACH ROW EXECUTE FUNCTION prevent_rental_overlap();

-- ==============================================
-- TRIGGER: Enforce Passenger Capacity
-- ==============================================
CREATE OR REPLACE FUNCTION check_passenger_capacity()
RETURNS TRIGGER AS $$
DECLARE
    max_capacity INT;
    current_passengers INT;
BEGIN
    -- Get the car's brand and model from the rental
    SELECT c.brand, c.model INTO max_capacity
    FROM rentals r
    JOIN car c ON r.license_plate = c.license_plate
    WHERE r.rental_id = NEW.rental_id;

    -- Get the car's capacity from carmake
    SELECT capacity INTO max_capacity
    FROM carmake
    WHERE brand = (SELECT brand FROM car WHERE license_plate = (SELECT license_plate FROM rentals WHERE rental_id = NEW.rental_id))
    AND model = (SELECT model FROM car WHERE license_plate = (SELECT license_plate FROM rentals WHERE rental_id = NEW.rental_id));

    -- Count the current passengers
    SELECT COUNT(*) INTO current_passengers
    FROM passengers
    WHERE rental_id = NEW.rental_id;

    -- Enforce the capacity limit
    IF current_passengers >= max_capacity THEN
        RAISE EXCEPTION 'Exceeds the passenger capacity';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_passenger_capacity
BEFORE INSERT ON passengers
FOR EACH ROW EXECUTE FUNCTION check_passenger_capacity();
