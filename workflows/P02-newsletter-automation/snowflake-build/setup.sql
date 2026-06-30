-- =============================================================================
-- P02 Competitive Intelligence Monitor, Snowflake setup
-- Idempotent. Run once on a fresh trial account in a SQL worksheet.
-- Placeholders: rename CI_DB / CI_WH / CI_USER if you like, but keep them
-- consistent with the n8n credential. No live identifiers belong in this file.
-- =============================================================================

-- Warehouse: extra-small, suspends fast to protect trial credits.
CREATE WAREHOUSE IF NOT EXISTS CI_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

CREATE DATABASE IF NOT EXISTS CI_DB;
CREATE SCHEMA IF NOT EXISTS CI_DB.RAW;   -- landing zone (the lake)
CREATE SCHEMA IF NOT EXISTS CI_DB.CORE;  -- modeled warehouse

USE WAREHOUSE CI_WH;
USE DATABASE CI_DB;

-- -----------------------------------------------------------------------------
-- Landing zone: one row per fetched article, raw and semi-structured.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CI_DB.RAW.SIGNAL_LANDING (
  LANDING_ID  STRING DEFAULT UUID_STRING(),
  RAW         VARIANT,
  SOURCE      STRING,
  LOAD_TS     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- -----------------------------------------------------------------------------
-- Modeled fact: one row per unique signal URL. This is the log and read model.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CI_DB.CORE.SIGNAL (
  SIGNAL_URL        STRING PRIMARY KEY,
  COMPANY_NAME      STRING,
  SIGNAL_TITLE      STRING,
  SIGNAL_TYPE       STRING,
  SUMMARY           STRING,
  PUB_DATE          TIMESTAMP_NTZ,
  FUNDING_MUSD      NUMBER(12,2),
  BRIEFING_INCLUDED BOOLEAN,
  LOGGED_TS         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- -----------------------------------------------------------------------------
-- Retention Task: prune signals older than 7 days. Serverless; created
-- suspended. Resume it after confirming the pipeline runs.
-- -----------------------------------------------------------------------------
CREATE TASK IF NOT EXISTS CI_DB.CORE.PRUNE_SIGNALS
  SCHEDULE = 'USING CRON 0 7 * * * UTC'
  AS DELETE FROM CI_DB.CORE.SIGNAL
     WHERE LOGGED_TS < DATEADD('day', -7, CURRENT_TIMESTAMP());
-- ALTER TASK CI_DB.CORE.PRUNE_SIGNALS RESUME;

-- Keep the lake from growing without bound on the trial.
CREATE TASK IF NOT EXISTS CI_DB.RAW.PRUNE_LANDING
  SCHEDULE = 'USING CRON 30 7 * * * UTC'
  AS DELETE FROM CI_DB.RAW.SIGNAL_LANDING
     WHERE LOAD_TS < DATEADD('day', -3, CURRENT_TIMESTAMP());
-- ALTER TASK CI_DB.RAW.PRUNE_LANDING RESUME;

-- -----------------------------------------------------------------------------
-- OPTIONAL: scoped role and user for n8n, so you are not wiring in ACCOUNTADMIN.
-- Uncomment, set a password or (preferred) a key pair, then point the n8n
-- credential at CI_USER. Keep the secret out of this file.
-- -----------------------------------------------------------------------------
-- CREATE ROLE IF NOT EXISTS CI_N8N_ROLE;
-- GRANT USAGE ON WAREHOUSE CI_WH TO ROLE CI_N8N_ROLE;
-- GRANT USAGE ON DATABASE CI_DB TO ROLE CI_N8N_ROLE;
-- GRANT USAGE ON SCHEMA CI_DB.RAW  TO ROLE CI_N8N_ROLE;
-- GRANT USAGE ON SCHEMA CI_DB.CORE TO ROLE CI_N8N_ROLE;
-- GRANT INSERT ON TABLE CI_DB.RAW.SIGNAL_LANDING TO ROLE CI_N8N_ROLE;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE CI_DB.CORE.SIGNAL TO ROLE CI_N8N_ROLE;
-- CREATE USER IF NOT EXISTS CI_USER DEFAULT_ROLE = CI_N8N_ROLE DEFAULT_WAREHOUSE = CI_WH;
-- GRANT ROLE CI_N8N_ROLE TO USER CI_USER;

-- Cortex region check: run this separately. If it errors, use a model your
-- region lists, or take the Groq fallback in BUILD_PROCESS.md.
-- SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Reply with the single word: ok');
