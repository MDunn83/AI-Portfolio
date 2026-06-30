# P02 Competitive Intelligence Monitor, Snowflake Build

The P02 monitor with its data layer rebuilt on Snowflake instead of Google Sheets. Same daily briefing, same 10 companies, same 8 signal types. What is different is the data engineering underneath: a raw landing zone (the lake), a SQL transform that dedups and types the data (the ELT step), a modeled fact table (the warehouse), and classification run in-warehouse with Snowflake Cortex.

This is the canonical Snowflake setup folder. The P07 Snowflake build points back here for the one-time account and credential steps.

> Status: spec plus runnable setup. `REQUIREMENTS.md` and `BUILD_PROCESS.md` define the design; `setup.sql` stands up the Snowflake objects today. The n8n workflow JSON is the remaining piece, built against a live Snowflake account. This folder is portfolio build-in-public material and syncs publicly on merge to `main`, so every identifier below is a placeholder.

---

## What you need

- A Snowflake account. The 30-day free trial gives you $400 in credits, which is far more than this build uses. No credit card to start.
- The existing n8n instance from the original P02 build.
- The n8n Snowflake node (built in; no community install needed).

---

## One-time Snowflake setup

1. **Start a trial.** Sign up at signup.snowflake.com. Pick any cloud and region, but note the region; Cortex model availability depends on it (step 4). Standard edition is fine.

2. **Grab your account identifier.** In the Snowflake UI, it is under your account menu, in the form `ORGNAME-ACCOUNTNAME`. The n8n credential wants this as the account locator. Keep it out of any committed file; it is `YOUR_SNOWFLAKE_ACCOUNT` everywhere in this repo.

3. **Run the setup script.** Open a SQL worksheet and run `setup.sql` from this folder. It creates the warehouse (`CI_WH`, extra-small, auto-suspend 60s), the database (`CI_DB`), the `RAW` and `CORE` schemas, both tables, and the optional retention Task. It is idempotent (`CREATE ... IF NOT EXISTS`), so re-running it is safe. Fill in any placeholder names you changed before running.

4. **Check Cortex in your region.** Run:
   ```sql
   SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Reply with the single word: ok');
   ```
   If it returns text, Cortex is live and you can use the in-warehouse classification path. If it errors with a model or region message, either switch the model name to one your region lists, or take the Groq fallback path documented in `BUILD_PROCESS.md` (keep the original Groq classifier in n8n, write results back to `CORE.SIGNAL`).

5. **Create a scoped role and user for n8n (recommended).** Do not wire n8n in as `ACCOUNTADMIN`. Create a role with usage on `CI_WH`, `CI_DB`, both schemas, and read/write on the two tables, then a user that carries that role. The setup script includes a commented block for this; uncomment and set a password or, better, a key pair.

---

## Wire up n8n

1. **Add a Snowflake credential** in n8n (Credentials, New, Snowflake). Fill in:
   - Account: `YOUR_SNOWFLAKE_ACCOUNT`
   - Warehouse: `CI_WH`
   - Database: `CI_DB`
   - Schema: `CORE`
   - Username / auth: the scoped user from setup step 5. Key-pair auth is preferred over a password.

   Nothing here goes in a committed file. The credential lives only in n8n's credential manager.

2. **Import the workflow JSON** (added during the build) and map the Snowflake credential onto every Snowflake node. The data nodes that changed from the original are listed in `BUILD_PROCESS.md` under "What changes in the n8n workflow."

3. **First run via Manual Trigger.** Confirm, in order:
   - `RAW.SIGNAL_LANDING` gets rows after the fetch (the landing write worked).
   - `CORE.SIGNAL` gets new rows after the transform, with no duplicate URLs (`SELECT SIGNAL_URL, COUNT(*) FROM CORE.SIGNAL GROUP BY 1 HAVING COUNT(*) > 1` returns nothing).
   - Classified rows have a `SIGNAL_TYPE`, `SUMMARY`, and `FUNDING_MUSD` (the Cortex pass worked).
   - The briefing query returns the included signals and the email sends; an empty result still sends the no-news note.

---

## Cost and credit safety

- The XS warehouse with `AUTO_SUSPEND = 60` only burns credits while a query runs. A daily run is a few seconds of compute.
- Cortex bills tokens against your credits. Trimming the text sent to `COMPLETE` (titles plus a short description) keeps it negligible.
- Set a resource monitor if you want a hard ceiling:
  ```sql
  CREATE RESOURCE MONITOR CI_GUARD WITH CREDIT_QUOTA = 50
    TRIGGERS ON 90 PERCENT DO SUSPEND ON 100 PERCENT DO SUSPEND_IMMEDIATE;
  ALTER WAREHOUSE CI_WH SET RESOURCE_MONITOR = CI_GUARD;
  ```

---

## Verifying the data engineering claims

After a run or two, these queries are the proof the pattern is real, and they are the things to screenshot for a build-in-public post:

```sql
-- The lake holds everything raw and semi-structured.
SELECT RAW:company, RAW:title, LOAD_TS FROM CI_DB.RAW.SIGNAL_LANDING LIMIT 10;

-- The warehouse holds the clean, deduplicated, classified model.
SELECT COMPANY_NAME, SIGNAL_TYPE, FUNDING_MUSD, BRIEFING_INCLUDED
FROM CI_DB.CORE.SIGNAL ORDER BY LOGGED_TS DESC LIMIT 20;

-- Cortex did the classification in-warehouse.
SELECT SIGNAL_TYPE, COUNT(*) FROM CI_DB.CORE.SIGNAL GROUP BY 1 ORDER BY 2 DESC;
```

---

## Reference

- `REQUIREMENTS.md`, goal, scope, acceptance criteria
- `BUILD_PROCESS.md`, schema layers, full DDL, transform and Cortex SQL, n8n rewiring
- `../README.md`, the original P02 monitor and its two earlier builds
