-- =============================================================================
-- P07 Customer Trigger Messaging Pipeline, Snowflake setup
-- Idempotent. Run once on a fresh trial account in a SQL worksheet.
-- Placeholders: rename CX_DB / CX_WH / CX_USER if you like, but keep them
-- consistent with the n8n credential. No live identifiers belong in this file.
-- Snowflake account / warehouse signup steps are shared with the P02 build,
-- see ../../P02-newsletter-automation/snowflake-build/README.md.
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS CX_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

CREATE DATABASE IF NOT EXISTS CX_DB;
CREATE SCHEMA IF NOT EXISTS CX_DB.CORE;

USE WAREHOUSE CX_WH;
USE DATABASE CX_DB;

-- -----------------------------------------------------------------------------
-- Customer dimension: the customer master.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CX_DB.CORE.CUSTOMER (
  CUSTOMER_ID            STRING PRIMARY KEY,
  CUSTOMER_NAME          STRING,
  COMPANY                STRING,
  EMAIL                  STRING,
  LAST_CONTACTED_DATE    DATE,
  SUPPORT_TICKET_CLOSED  TIMESTAMP_NTZ,
  LAST_ACTIVITY_DATE     DATE,
  RENEWAL_DATE           DATE,
  MILESTONE_REACHED      BOOLEAN
);

-- -----------------------------------------------------------------------------
-- Activity fact: append-only audit of every touch, including non-contacts.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CX_DB.CORE.ACTIVITY_LOG (
  LOG_ID           STRING DEFAULT UUID_STRING(),
  LOG_TS           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  CUSTOMER_ID      STRING,
  CUSTOMER_NAME    STRING,
  COMPANY          STRING,
  TRIGGER_TYPE     STRING,
  EMAIL_SENT       BOOLEAN,
  MESSAGE_PREVIEW  STRING
);

-- -----------------------------------------------------------------------------
-- Trigger view: suppression window + priority cascade, all in SQL.
-- First match wins, top to bottom. Suppression beats every trigger.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW CX_DB.CORE.V_CUSTOMER_TRIGGER AS
SELECT
  CUSTOMER_ID,
  CUSTOMER_NAME,
  COMPANY,
  EMAIL,
  (LAST_CONTACTED_DATE IS NOT NULL
     AND DATEDIFF('day', LAST_CONTACTED_DATE, CURRENT_DATE) < 7) AS SUPPRESSED,
  DATEDIFF('day', LAST_ACTIVITY_DATE, CURRENT_DATE) AS DAYS_INACTIVE,
  DATEDIFF('day', CURRENT_DATE, RENEWAL_DATE)       AS DAYS_TO_RENEWAL,
  CASE
    WHEN (LAST_CONTACTED_DATE IS NOT NULL
          AND DATEDIFF('day', LAST_CONTACTED_DATE, CURRENT_DATE) < 7)
      THEN 'Suppressed'
    WHEN SUPPORT_TICKET_CLOSED IS NOT NULL
          AND DATEDIFF('hour', SUPPORT_TICKET_CLOSED, CURRENT_TIMESTAMP()) <= 24
      THEN 'Ticket'
    WHEN LAST_ACTIVITY_DATE IS NOT NULL
          AND DATEDIFF('day', LAST_ACTIVITY_DATE, CURRENT_DATE) > 14
      THEN 'Inactivity'
    WHEN RENEWAL_DATE IS NOT NULL
          AND DATEDIFF('day', CURRENT_DATE, RENEWAL_DATE) BETWEEN 0 AND 30
      THEN 'Renewal'
    WHEN MILESTONE_REACHED = TRUE
      THEN 'Milestone'
    ELSE 'No Action'
  END AS TRIGGER_TYPE
FROM CX_DB.CORE.CUSTOMER;

-- -----------------------------------------------------------------------------
-- OPTIONAL: scoped role and user for n8n. Uncomment, set a secret out of band,
-- and point the n8n credential at CX_USER instead of ACCOUNTADMIN.
-- -----------------------------------------------------------------------------
-- CREATE ROLE IF NOT EXISTS CX_N8N_ROLE;
-- GRANT USAGE ON WAREHOUSE CX_WH TO ROLE CX_N8N_ROLE;
-- GRANT USAGE ON DATABASE CX_DB TO ROLE CX_N8N_ROLE;
-- GRANT USAGE ON SCHEMA CX_DB.CORE TO ROLE CX_N8N_ROLE;
-- GRANT SELECT, UPDATE ON TABLE CX_DB.CORE.CUSTOMER TO ROLE CX_N8N_ROLE;
-- GRANT SELECT ON VIEW CX_DB.CORE.V_CUSTOMER_TRIGGER TO ROLE CX_N8N_ROLE;
-- GRANT INSERT ON TABLE CX_DB.CORE.ACTIVITY_LOG TO ROLE CX_N8N_ROLE;
-- CREATE USER IF NOT EXISTS CX_USER DEFAULT_ROLE = CX_N8N_ROLE DEFAULT_WAREHOUSE = CX_WH;
-- GRANT ROLE CX_N8N_ROLE TO USER CX_USER;
