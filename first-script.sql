-- SCHEMA: artyomg

-- DROP SCHEMA IF EXISTS artyomg ;

CREATE SCHEMA IF NOT EXISTS artyomg
    AUTHORIZATION student;

-- SEQUENCE: artyomg.measurement_batch_seq

-- DROP SEQUENCE IF EXISTS artyomg.measurement_batch_seq;

CREATE SEQUENCE IF NOT EXISTS artyomg.measurement_batch_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;

ALTER SEQUENCE artyomg.measurement_batch_seq
    OWNER TO student;

-- SEQUENCE: artyomg.measurement_params_seq

-- DROP SEQUENCE IF EXISTS artyomg.measurement_params_seq;

CREATE SEQUENCE IF NOT EXISTS artyomg.measurement_params_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;

ALTER SEQUENCE artyomg.measurement_params_seq
    OWNER TO student;

-- Table: artyomg.measurement_batch

-- DROP TABLE IF EXISTS artyomg.measurement_batch;

CREATE TABLE IF NOT EXISTS artyomg.measurement_batch
(
    id integer NOT NULL DEFAULT nextval('artyomg.measurement_batch_seq'::regclass),
    start_period timestamp without time zone DEFAULT now(),
    position_x numeric(3,2),
    position_y numeric(3,2),
    user_id integer,
    CONSTRAINT measurement_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS artyomg.measurement_batch
    OWNER to student;

-- Table: artyomg.measurement_params

-- DROP TABLE IF EXISTS artyomg.measurement_params;

CREATE TABLE IF NOT EXISTS artyomg.measurement_params
(
    id integer NOT NULL DEFAULT nextval('artyomg.measurement_params_seq'::regclass),
    measurement_type_id integer NOT NULL,
    measurement_batch_id integer NOT NULL,
    height numeric(8,2),
    temperature numeric(8,2),
    wind_speed numeric(8,2),
    wind_direction numeric(8,2),
    bullet_speed numeric(8,2),
    pressure numeric(8,2),
    CONSTRAINT measurement_params_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS artyomg.measurement_params
    OWNER to student;

-- Table: artyomg.measurement_type

-- DROP TABLE IF EXISTS artyomg.measurement_type;

CREATE TABLE IF NOT EXISTS artyomg.measurement_type
(
    id integer NOT NULL,
    name character varying(20) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT measurement_type_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS artyomg.measurement_type
    OWNER to student;

-- Table: artyomg.users

-- DROP TABLE IF EXISTS artyomg.users;

CREATE TABLE IF NOT EXISTS artyomg.users
(
    id integer NOT NULL,
    username character varying COLLATE pg_catalog."default",
    rank character varying COLLATE pg_catalog."default",
    CONSTRAINT users_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS artyomg.users
    OWNER to student;
