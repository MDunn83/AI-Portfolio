# P07 Customer Trigger Messaging Pipeline, Snowflake Build

The P07 pipeline with its data layer rebuilt on Snowflake. Same four behavioral triggers, same 7-day cooldown, same per-category emails. What is different is that the customer master is a dimension table, the activity log is an append-only audit fact, and the suppression window plus the priority cascade run as a SQL view instead of n8n Code nodes.

> Status: spec plus runnable setup. `REQUIREMENTS.md` and `BUILD_PROCESS.md` define the design; `setup.sql` stands up the tables and the view today. The n8n workflow JSON is the remaining piece, built against a live Snowflake account. This folder syncs publicly on merge to `main`, so every identifier is a placeholder.

---

## What you need

- A Snowflake account (the 30-day free trial). If you already set one up for the P02 build, reuse it; just run this folder's `setup.sql` to add the P07 objects.
- The existing n8n instance from the original P07 build.
- The n8n Snowflake node (built in).

---

## Snowflake account setup

The one-time account, region, and Cortex steps are shared with the P02 build and written up once there:
`../../P02-newsletter-automation/snowflake-build/README.md`, sections "One-time Snowflake setup" and "Cost and credit safety."

This build does not require Cortex (the email generation stays in n8n), so you can skip the Cortex region check unless you plan the optional in-warehouse generation extension.

---

## Stand up the P07 objects

1. Open a SQL worksheet and run `setup.sql` from this folder. It creates `CX_WH`, `CX_DB`, the `CORE` schema, the `CUSTOMER` dimension, the `ACTIVITY_LOG` fact, and the `V_CUSTOMER_TRIGGER` view. Idempotent, so re-running is safe.

2. Seed the dimension with your test customers. Match the test-data discipline from the original build: include at least one customer per trigger and one that should be suppressed and one No Action. Cast dates on load so a bad cell becomes NULL instead of failing:
   ```sql
   INSERT INTO CX_DB.CORE.CUSTOMER
     (CUSTOMER_ID, CUSTOMER_NAME, COMPANY, EMAIL, LAST_CONTACTED_DATE,
      SUPPORT_TICKET_CLOSED, LAST_ACTIVITY_DATE, RENEWAL_DATE, MILESTONE_REACHED)
   VALUES
     ('C001','Test Ticket','Acme','t1@example.com', NULL,
      DATEADD('hour',-3,CURRENT_TIMESTAMP()), CURRENT_DATE, NULL, FALSE);
   ```

3. Confirm the view resolves triggers correctly before touching n8n:
   ```sql
   SELECT CUSTOMER_NAME, SUPPRESSED, DAYS_INACTIVE, DAYS_TO_RENEWAL, TRIGGER_TYPE
   FROM CX_DB.CORE.V_CUSTOMER_TRIGGER;
   ```
   Check that suppression beats every trigger, and that the priority order (Ticket, Inactivity, Renewal, Milestone) holds for a customer who matches more than one.

---

## Wire up n8n

1. **Add a Snowflake credential** (Account `YOUR_SNOWFLAKE_ACCOUNT`, Warehouse `CX_WH`, Database `CX_DB`, Schema `CORE`, the scoped user). Key-pair auth preferred. Nothing goes in a committed file.

2. **Import the workflow JSON** (added during the build) and map the credential onto the Snowflake nodes. The nodes that changed from the original are in `BUILD_PROCESS.md` under "What changes in the n8n workflow."

3. **First run via Manual Trigger.** Confirm:
   - n8n reads `V_CUSTOMER_TRIGGER` and branches on `TRIGGER_TYPE`.
   - A suppressed customer gets a Suppressed row in `ACTIVITY_LOG` and no email.
   - A matched customer gets exactly one email with the right subject, and an `ACTIVITY_LOG` row with the preview.
   - After a send, `CORE.CUSTOMER.LAST_CONTACTED_DATE` is today's date, and that customer is suppressed on the next run.

---

## Verifying the data engineering claims

```sql
-- The dimension is the customer master.
SELECT CUSTOMER_NAME, LAST_CONTACTED_DATE, RENEWAL_DATE FROM CX_DB.CORE.CUSTOMER;

-- The view decides suppression and trigger in SQL.
SELECT CUSTOMER_NAME, SUPPRESSED, TRIGGER_TYPE FROM CX_DB.CORE.V_CUSTOMER_TRIGGER;

-- The fact table is the audit trail, including who was NOT contacted.
SELECT LOG_TS, CUSTOMER_NAME, TRIGGER_TYPE, EMAIL_SENT
FROM CX_DB.CORE.ACTIVITY_LOG ORDER BY LOG_TS DESC;
```

That last query, showing Suppressed and No Action rows sitting next to real sends, is the audit-trail proof and a clean build-in-public screenshot.

---

## Reference

- `REQUIREMENTS.md`, goal, scope, acceptance criteria
- `BUILD_PROCESS.md`, the dimension/fact model, the view SQL, the n8n rewiring
- `../README.md`, the original P07 pipeline
- Shared Snowflake account setup: `../../P02-newsletter-automation/snowflake-build/README.md`
