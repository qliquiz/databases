CREATE SCHEMA IF NOT EXISTS artyomg;

do $$
begin

raise notice 'Initializing new database structure for weather measurements'; 
begin
    -- Drop existing foreign key constraints
    alter table if exists artyomg.measurement_params
    drop constraint if exists fk_measurement_type;

    alter table if exists artyomg.personnel
    drop constraint if exists fk_rank;

    alter table if exists artyomg.measurement_records
    drop constraint if exists fk_measurement_param;

    alter table if exists artyomg.measurement_records
    drop constraint if exists fk_personnel;

    -- Drop existing tables
    drop table if exists artyomg.measurement_params;
    drop table if exists artyomg.measurement_records;
    drop table if exists artyomg.personnel;
    drop table if exists artyomg.measurement_types;
    drop table if exists artyomg.ranks;
    drop table if exists artyomg.temperature;
    drop table if exists artyomg.temp_adjustments;

    -- Drop sequences
    drop sequence if exists artyomg.measurement_params_seq;
    drop sequence if exists artyomg.measurement_records_seq;
    drop sequence if exists artyomg.personnel_seq;
    drop sequence if exists artyomg.ranks_seq;
    drop sequence if exists artyomg.measurement_types_seq;
end;

raise notice 'Successfully removed existing data structures';

-- Ranks reference table
create table artyomg.ranks
(
    id integer primary key not null,
    title character varying(255)
);

insert into artyomg.ranks(id, title)
values(1,'Рядовой'),(2,'Майор');

create sequence artyomg.ranks_seq start 3;
alter table artyomg.ranks alter column id set default nextval('artyomg.ranks_seq');

-- Personnel table
create table artyomg.personnel
(
    id integer primary key not null,
    full_name text,
    birth_date timestamp,
    rank_id integer
);

insert into artyomg.personnel(id, full_name, birth_date, rank_id)  
values(1, 'Горев Артём Дмитриевич','2005-11-11', 2);

create sequence artyomg.personnel_seq start 2;
alter table artyomg.personnel alter column id set default nextval('artyomg.personnel_seq');

-- Measurement equipment types
create table artyomg.measurement_types
(
    id integer primary key not null,
    code character varying(50),
    details text 
);

insert into artyomg.measurement_types(id, code, details)
values(1, 'ДМК', 'Десантный метео комплекс'),
(2,'ВР','Ветровое ружье');

create sequence artyomg.measurement_types_seq start 3;
alter table artyomg.measurement_types alter column id set default nextval('artyomg.measurement_types_seq');

-- Measurement parameters
create table artyomg.measurement_params
(
    id integer primary key not null,
    measurement_type_id integer not null,
    altitude numeric(8,2) default 0,
    temp numeric(8,2) default 0,
    press numeric(8,2) default 0,
    wind_dir numeric(8,2) default 0,
    wind_vel numeric(8,2) default 0
);

insert into artyomg.measurement_params(id, measurement_type_id, altitude, temp, press, wind_dir, wind_vel)
values(1, 1, 100, 12, 34, 0.2, 45);

create sequence artyomg.measurement_params_seq start 2;
alter table artyomg.measurement_params alter column id set default nextval('artyomg.measurement_params_seq');

-- Measurement history
create table artyomg.measurement_records
(
    id integer primary key not null,
    personnel_id integer not null,
    param_id integer not null,
    measurement_time timestamp default now()
);

insert into artyomg.measurement_records(id, personnel_id, param_id)
values(1, 1, 1);

create sequence artyomg.measurement_records_seq start 2;
alter table artyomg.measurement_records alter column id set default nextval('artyomg.measurement_records_seq');

raise notice 'Successfully created and populated reference tables'; 

-- Temperature correction table
create table if not exists artyomg.temp_adjustments
(
    base_temp numeric(8,2) primary key,
    adjustment numeric(8,2)
);

insert into artyomg.temp_adjustments(base_temp, adjustment)
values(0, 0.5),(5, 0.5),(10, 1), (20,1), (25, 2), (30, 3.5), (40, 4.5);

-- Custom type for interpolation
drop type if exists artyomg.interpolation_data;
create type artyomg.interpolation_data as
(
    temp_lower numeric(8,2),
    temp_upper numeric(8,2),
    adj_lower numeric(8,2),
    adj_upper numeric(8,2)
);

raise notice 'Calculation structures created';

-- Setting up foreign key constraints
begin 
    alter table artyomg.measurement_records
    add constraint fk_personnel 
    foreign key (personnel_id)
    references artyomg.personnel (id);    
    
    alter table artyomg.measurement_records
    add constraint fk_measurement_param 
    foreign key(param_id)
    references artyomg.measurement_params(id);
    
    alter table artyomg.measurement_params
    add constraint fk_measurement_type
    foreign key(measurement_type_id)
    references artyomg.measurement_types (id);
    
    alter table artyomg.personnel
    add constraint fk_rank
    foreign key(rank_id)
    references artyomg.ranks (id);
end;

raise notice 'Foreign key constraints established';
raise notice 'Database structure successfully created';

end $$;

-- Configuration tables
drop table if exists artyomg.measurement_config;
drop table if exists artyomg.system_constants;

CREATE TABLE IF NOT EXISTS artyomg.system_constants
(
    parameter_key character varying(30) NOT NULL,
    parameter_value text NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_param_key
    ON artyomg.system_constants USING btree
    (parameter_key ASC NULLS LAST);

CREATE TABLE if not exists artyomg.measurement_config (
    parameter_name VARCHAR(50) NOT NULL,
    lower_bound NUMERIC NOT NULL,
    upper_bound NUMERIC NOT NULL,
    measurement_unit VARCHAR(20) NOT NULL
);

-- Populating configuration
DO $$
begin
    IF (SELECT COUNT(*) FROM artyomg.measurement_config) >= 3 THEN
        RAISE NOTICE 'Configuration data already exists';
    else
        INSERT INTO artyomg.measurement_config (parameter_name, lower_bound, upper_bound, measurement_unit) VALUES
        ('Station Altitude', -10000, 10000, 'm'),
        ('Temperature', -58, 58, '°C'),
        ('Pressure', 500, 900, 'mm Hg'),
        ('Wind Direction', 0, 59, '°'),
        ('Wind Speed', 0, 15, 'm/s'),
        ('Bullet Drift', 0, 150, 'm');
        
        RAISE NOTICE 'Configuration data successfully added';
    end if;
END;
$$;

-- Custom data type and validation function
DROP TYPE IF EXISTS artyomg.measurement_data CASCADE;
CREATE TYPE artyomg.measurement_data AS (
    value NUMERIC
);

CREATE OR REPLACE FUNCTION artyomg.validate_measurement(param_type VARCHAR, measured_value numeric)
RETURNS artyomg.measurement_data AS $$
DECLARE
    min_val numeric;
    max_val numeric;
    result artyomg.measurement_data;
BEGIN
    SELECT lower_bound, upper_bound
    INTO min_val, max_val
    FROM artyomg.measurement_config
    WHERE parameter_name = param_type;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Parameter % not found in configuration', param_type;
    END IF;
    
    IF measured_value < min_val OR measured_value > max_val THEN
        RAISE EXCEPTION 'Measurement % is outside valid range [% - %]', measured_value, min_val, max_val;
    END IF;

    result.value := measured_value;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Utility functions
DROP FUNCTION IF EXISTS artyomg.format_pressure();
DROP FUNCTION IF EXISTS artyomg.get_timestamp();
DROP FUNCTION IF EXISTS artyomg.format_altitude();

CREATE OR REPLACE FUNCTION artyomg.format_pressure(
    press_value numeric,
    temp_value numeric
)
RETURNS text
LANGUAGE plpgsql AS $$
DECLARE
    base_pressure numeric; 
    formatted_text text;
    pressure_diff numeric;
    diff_integer integer;
BEGIN
    SELECT parameter_value::numeric INTO base_pressure
    FROM artyomg.system_constants
    WHERE parameter_key = 'base_pressure';

    pressure_diff := press_value - base_pressure;
    diff_integer := pressure_diff::integer;
    
    IF diff_integer > 0 THEN
        formatted_text := LPAD(diff_integer::text, 3, '0');
    ELSE
        diff_integer := diff_integer * -1;
        formatted_text := '5' || LPAD(diff_integer::text, 2, '0');
    END IF;
    
    RETURN formatted_text;
END;
$$;

CREATE OR REPLACE FUNCTION artyomg.get_timestamp()
RETURNS text 
LANGUAGE plpgsql AS $$
BEGIN
    RETURN TO_CHAR(NOW(), 'DDHH') || LEFT(TO_CHAR(NOW(), 'MI'), 1);
END;
$$;

CREATE OR REPLACE FUNCTION artyomg.format_altitude(
    alt_value integer
)
RETURNS text 
LANGUAGE plpgsql AS $$
BEGIN
    RETURN LPAD(alt_value::text, 4, '0');
END;
$$;

-- Temperature interpolation function
CREATE OR REPLACE FUNCTION artyomg.calculate_temp_adjustment(input_temp NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    interp_values artyomg.interpolation_data;
    final_adjustment NUMERIC;
BEGIN
    SELECT adjustment INTO final_adjustment
    FROM artyomg.temp_adjustments
    WHERE base_temp = input_temp;
    
    IF FOUND THEN
        RETURN final_adjustment;
    END IF;

    SELECT 
        t1.base_temp, t2.base_temp, 
        t1.adjustment, t2.adjustment
    INTO interp_values
    FROM 
        (SELECT base_temp, adjustment 
            FROM artyomg.temp_adjustments 
            WHERE base_temp <= input_temp 
            ORDER BY base_temp DESC 
            LIMIT 1) AS t1,
        (SELECT base_temp, adjustment 
            FROM artyomg.temp_adjustments 
            WHERE base_temp >= input_temp 
            ORDER BY base_temp ASC 
            LIMIT 1) AS t2;

    IF interp_values.temp_lower IS NULL OR interp_values.temp_upper IS NULL THEN
        RETURN NULL;
    END IF;

    final_adjustment := interp_values.adj_lower + 
                       (interp_values.adj_upper - interp_values.adj_lower) * 
                        (input_temp - interp_values.temp_lower) / 
                        (interp_values.temp_upper - interp_values.temp_lower);
    
    RETURN final_adjustment;
END;
$$ LANGUAGE plpgsql;

-- Test data generation
INSERT INTO artyomg.personnel (id, full_name, birth_date, rank_id) 
VALUES
    (2, 'Иванов Иван Иванович', '1985-03-15', 1),
    (3, 'Петров Петр Петрович', '1990-07-10', 2),
    (4, 'Сидоров Александр Александрович', '1982-09-23', 1),
    (5, 'Кузнецов Дмитрий Дмитриевич', '1992-01-05', 2);

DO $$
DECLARE
    person_id INTEGER;
    equipment_id INTEGER;
    measurement_id INTEGER;
BEGIN
    FOR person_id IN 1..5 LOOP
        FOR equipment_id IN 1..2 LOOP
            FOR i IN 1..100 LOOP
                INSERT INTO artyomg.measurement_params (
                    measurement_type_id, 
                    altitude, 
                    temp, 
                    press, 
                    wind_dir, 
                    wind_vel
                ) 
                VALUES (
                    equipment_id, 
                    100 + (random() * 400),
                    20 + (random() * 10),
                    1010 + (random() * 20),
                    random() * 360,
                    random() * 15
                ) RETURNING id INTO measurement_id;

                INSERT INTO artyomg.measurement_records (
                    personnel_id, 
                    param_id, 
                    measurement_time
                ) 
                VALUES (
                    person_id, 
                    measurement_id, 
                    NOW() - (random() * INTERVAL '30 days')
                );
            END LOOP;
        END LOOP;
    END LOOP;
END;
$$;
