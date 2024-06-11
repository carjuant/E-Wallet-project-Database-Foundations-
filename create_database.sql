--creation of ewallet schema 

CREATE SCHEMA ewallet ;
SET search_path TO ewallet;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

/* script of "create" of all database desing DDL, first the tables without foreing keys */

-- Table E10.country

CREATE TABLE IF NOT EXISTS country (
	code int PRIMARY KEY,
	name varchar (30) UNIQUE NOT NULL 
); 

--index for country name

CREATE INDEX country_name_index ON country(name);

-- Table E12.state

CREATE TABLE IF NOT EXISTS state (
	id_state SERIAL PRIMARY KEY,
	state varchar (15) UNIQUE NOT NULL 
);

-- Table E9.Type_Transaction

CREATE TABLE IF NOT EXISTS type_transaction (
	id_type_transaction SERIAL PRIMARY KEY,
	type_transaction varchar (30) UNIQUE NOT NULL 
);

-- Table E11.Type_Document

CREATE TABLE IF NOT EXISTS type_document (
	id_type_document SERIAL PRIMARY KEY,
	type_document varchar (20) UNIQUE NOT NULL
); 

-- Table E8.Type_Account

CREATE TABLE IF NOT EXISTS type_account (
	id_type_account SERIAL PRIMARY KEY,
	type_account varchar (20) UNIQUE NOT NULL
	);
	
/* Now we see for tables with foreing keys that references primary keys that we have*/

-- Table E6.Bank_Account

CREATE TABLE IF NOT EXISTS bank_account (
	id_bank_account SERIAL PRIMARY KEY,
	account_number varchar (50) UNIQUE NOT NULL,
	name_account varchar (50) NOT NULL,
	bank_name varchar (30) NOT NULL,
	headline varchar (50) NOT NULL,
	id_headline int NOT NULL,
	balance float CHECK (balance > 0) NOT NULL,
	fk_type_document int NOT NULL,
	fk_type_account int NOT NULL, 
	CONSTRAINT fk_type_document_headline FOREIGN KEY (fk_type_document)
		REFERENCES type_document(id_type_document),
	CONSTRAINT fk_type_account FOREIGN KEY (fk_type_account)
		REFERENCES type_account(id_type_account)	
);

-- index to search account number in bank_account

CREATE INDEX bank_account_number_index ON bank_account(account_number);

-- index for headline

CREATE INDEX bank_account_headline_index ON bank_account(headline);

-- Table E1.UserS

CREATE TABLE IF NOT EXISTS users (
	phone_number int PRIMARY KEY,
	password varchar (30) NOT NULL,
	email varchar (150) UNIQUE NOT NULL,
	names varchar (30) NOT NULL,
	lastNames varchar (30) NOT NULL,
	cc int UNIQUE NOT NULL,
	mattress float CHECK (mattress > 0) DEFAULT 0,
	balance float CHECK (balance > 0) DEFAULT 0 NOT NULL,
	fk_country int NOT NULL,
	CONSTRAINT fk_country_user FOREIGN KEY (fk_country)
		REFERENCES country(code)	
);

-- fix a error in a column constraint default 0 (balance & mattress) for inicial users

--ALTER TABLE users ALTER COLUMN email TYPE varchar (150);
--ALTER TABLE users ALTER COLUMN mattress SET DEFAULT 0;
--ALTER TABLE users ALTER column balance SET DEFAULT 0; 

--indexes for email an cc

CREATE INDEX users_email_index ON users(email);
CREATE INDEX users_cc_index ON users(cc);

-- Table E4.Service

CREATE TABLE IF NOT EXISTS service (
	id_service SERIAL PRIMARY KEY,
	name_service varchar (30) UNIQUE NOT NULL,
	fk_bank_account int NOT NULL,
	CONSTRAINT fk_bank_account_service FOREIGN KEY (fk_bank_account)
		REFERENCES bank_account(id_bank_account)	
);

CREATE INDEX name_service_index ON service(name_service);

-- Table E3.Pocket

CREATE TABLE IF NOT EXISTS pocket (
	id_pocket SERIAL PRIMARY KEY,
	name varchar(30) NOT NULL,
	amount float check(amount > 0) DEFAULT 0 NOT NULL,
	fk_user int NOT NULL,
	CONSTRAINT fk_user_pocket FOREIGN KEY (fk_user)
		REFERENCES users(phone_number)
);


--alter table to set default 0 to amount

--ALTER TABLE	pocket ALTER COLUMN amount SET DEFAULT 0;

-- Table E7.User_Bank_REL

CREATE TABLE IF NOT EXISTS user_bank_rel (
	id_user_bank_rel UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
	description varchar(50) NOT NULL,
	amount float CHECK (amount > 0),
	date timestamp DEFAULT NOW() NOT NULL,
	fk_type_transaction int NOT NULL,
	fk_state int NOT NULL,
	fk_user int NOT NULL,
	fk_bank_account int NOT NULL,
	CONSTRAINT fk_type_transaction_usbarel FOREIGN KEY (fk_type_transaction)
		REFERENCES type_transaction(id_type_transaction),
	CONSTRAINT fk_state_usbarel FOREIGN KEY (fk_state)
	 	REFERENCES state(id_state),
	CONSTRAINT fk_user_usbarel FOREIGN KEY (fk_user)
		REFERENCES users(phone_number),
	CONSTRAINT fk_bank_account_usbarel FOREIGN KEY (fk_bank_account)
		REFERENCES bank_account(id_bank_account)
);

-- Table E5. Payment_Service

CREATE TABLE IF NOT EXISTS payment_service (
	id_payment_service UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
	amount float CHECK (amount > 0),
	date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
	fk_state int NOT NULL,	
	fk_user int NOT NULL,
	fk_service int NOT NULL,
	CONSTRAINT fk_state_payservice FOREIGN KEY (fk_state)
		REFERENCES state(id_state),
	CONSTRAINT fk_user_payservice FOREIGN KEY (fk_user)
		REFERENCES users(phone_number),
	CONSTRAINT fk_service FOREIGN KEY (fk_service)
		REFERENCES service(id_service)
);

-- Table E2.TransactionS

CREATE TABLE IF NOT EXISTS transactions (
	id_transaction UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
	description varchar(50),
	amount float CHECK (amount > 0),
	date timestamp DEFAULT (now()) NOT NULL,
	fk_state int NOT NULL,	
	fk_user_origin int NOT NULL,
	fk_user_destin int NOT NULL,
	CONSTRAINT chk_no_self_transaction CHECK (fk_user_origin <> fk_user_destin),
	CONSTRAINT fk_state_transaction FOREIGN KEY (fk_state)
		REFERENCES state(id_state),
	CONSTRAINT fk_user_origin FOREIGN KEY (fk_user_origin)
		REFERENCES users(phone_number),
	CONSTRAINT fk_user_destin FOREIGN KEY (fk_user_destin)
		REFERENCES users(phone_number)
);

/* create view for usable_money */

CREATE VIEW usable_money AS
SELECT phone_number, u.names, (u.balance - COALESCE(SUM(pocket.amount),0) - COALESCE (u.mattress,0)) AS usable_money
FROM users u 
JOIN pocket ON pocket.fk_user = u.phone_number
GROUP BY u.phone_number, u.names, u.balance, u.mattress ; 


-- create a function to update balance in table users, its better call the function in the others function for the triggers than repeat all the functions


CREATE OR REPLACE FUNCTION update_balance(phone_number int) RETURNS void AS $$
BEGIN
    UPDATE users
    SET balance = (
        SELECT COALESCE(SUM(amount), 0)
        FROM pocket
        WHERE fk_user = phone_number
    ) + COALESCE((SELECT mattress FROM users WHERE phone_number = phone_number), 0)
    WHERE phone_number = phone_number;
END;
$$ LANGUAGE plpgsql;


-- example of function for update balance when the mattress is updated without call the last function


CREATE OR REPLACE FUNCTION update_mattress() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.mattress <> OLD.mattress THEN
        UPDATE users
        SET balance = balance - (NEW.mattress - OLD.mattress)
        WHERE  phone_number = NEW.phone_number;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- trigger to call function to update balance when the column mattres was updated

CREATE TRIGGER trigger_update_mattress
AFTER UPDATE OF mattress ON users
FOR EACH ROW
EXECUTE FUNCTION update_mattress();


-- function and trigger calling the initial function to update pocket

CREATE OR REPLACE FUNCTION update_pocket() RETURNS TRIGGER AS $$
BEGIN
    PERFORM update_balance(phone_number);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_pocket
AFTER INSERT OR UPDATE OR DELETE ON pocket
FOR EACH ROW
EXECUTE FUNCTION update_pocket();
`

-- function and trigger for update in table transaction


CREATE OR REPLACE FUNCTION update_transaction() RETURNS TRIGGER AS $$
BEGIN
    PERFORM update_balance(fk_user_origin);
    PERFORM update_balance(fk_user_destin);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_transaction
AFTER INSERT ON transactions
FOR EACH ROW
EXECUTE FUNCTION update_transaction();
