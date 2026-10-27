/* =====================================================================
   POSTGRESQL SETUP - run this ONCE, before the queries
   Input : healthcare_cleaned.csv   (the file your notebook exported)
   Output: table "healthcare"       (clean, ready for analysis)

   STEP 0 (in psql or pgAdmin):  CREATE DATABASE healthcare_db;
                                 then connect to healthcare_db
   ===================================================================== */

-- STEP 1. Raw table: same column order as the CSV
DROP TABLE IF EXISTS healthcare_raw;
CREATE TABLE healthcare_raw (
    name                TEXT,
    age                 INTEGER,
    gender              TEXT,
    blood_type          TEXT,
    medical_condition   TEXT,
    date_of_admission   DATE,
    doctor              TEXT,
    hospital            TEXT,
    insurance_provider  TEXT,
    billing_amount      NUMERIC(12,2),
    room_number         INTEGER,
    admission_type      TEXT,
    discharge_date      DATE,
    medication          TEXT,
    test_results        TEXT,
    length_of_stay      INTEGER,
    admission_year      INTEGER,
    admission_month     TEXT
);

-- STEP 2. Load the CSV  (run this line in psql, NOT in the VS Code query window)
--         Use the full path to the file if psql was not started in the same folder.
--
--   \copy healthcare_raw FROM 'healthcare_cleaned.csv' WITH (FORMAT csv, HEADER true)
--
--   Using pgAdmin instead?  Right-click healthcare_raw > Import/Export Data...
--   > Import, pick the CSV, Format = csv, Header = on, Delimiter = ,

-- STEP 3. Build the final table: remove exact duplicates and negative bills
DROP TABLE IF EXISTS healthcare;
CREATE TABLE healthcare AS
SELECT DISTINCT *
FROM healthcare_raw
WHERE billing_amount >= 0;

ALTER TABLE healthcare ADD COLUMN admission_id SERIAL PRIMARY KEY;

CREATE INDEX idx_hc_condition ON healthcare (medical_condition);
CREATE INDEX idx_hc_admtype   ON healthcare (admission_type);
CREATE INDEX idx_hc_insurer   ON healthcare (insurance_provider);

DROP TABLE healthcare_raw;

-- STEP 4. Check: expect 54,860 rows
SELECT COUNT(*) AS rows_in_healthcare FROM healthcare;
