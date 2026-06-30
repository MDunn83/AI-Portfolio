# P07 Customer Trigger Messaging Pipeline, Snowflake Build
## Requirements Document

Version 0.1 (spec, not yet built) | June 2026

---

## Goal

Take the working P07 pipeline and move its data layer off Google Sheets and into Snowflake, modeled the way a commercial customer-data team would model it: a customer dimension, an activity/audit fact table, and an analytical view that does the trigger detection and suppression in SQL.

The behavior does not change. The pipeline still watches a customer database, fires one of four behavioral triggers per customer in priority order, writes an AI-generated email, and logs every send and every suppression. What changes is that the suppression window and the priority cascade, which the original does in n8n Code nodes, become windowed SQL in a view. n8n reads the view, generates the email, and writes back.

This is the build that most looks like real customer-data engineering: a dimension table, an append-only audit fact, and date-windowed analytical SQL over customer events.

---

## Scope

### In scope

- A `CORE.CUSTOMER` dimension table holding the customer master (the current Customer sheet).
- A `CORE.ACTIVITY_LOG` append-only fact table holding every touch, including suppressions and no-actions (the current Activity Log sheet, kept as an audit trail).
- A `CORE.V_CUSTOMER_TRIGGER` view that, per customer, computes the 7-day suppression flag and the matched trigger via a priority CASE with date math.
- n8n reads the view, generates the email per category, sends it, and writes back to the fact table and the dimension.
- All Snowflake objects created from one idempotent setup script in this folder.

### Out of scope

- Changing pipeline behavior: same four triggers, same priority order, same 7-day cooldown, same per-category prompts and fixed subject lines, same one-email-per-customer-per-run rule.
- Moving the LLM email generation into the warehouse. The per-category prompts stay in n8n where they already work; Cortex generation is noted as an optional extension only.
- A real-time or streaming customer feed. The customer master is loaded into the dimension; this build does not build the upstream ingestion.
- Any paid Snowflake tier. Fits inside the free trial.

---

## Functional Requirements

### FR1, Customer dimension

`CORE.CUSTOMER` holds one row per customer with the fields the pipeline uses: customer id, name, company, email, last contacted date, support ticket closed date, last activity date, renewal date, milestone reached. This replaces the Customer sheet.

### FR2, Suppression and categorization in SQL

`CORE.V_CUSTOMER_TRIGGER` computes, per customer:
- a `SUPPRESSED` flag, true when last contacted is within the last 7 days;
- a `TRIGGER_TYPE`, resolved by a priority CASE: Ticket (ticket closed within 24h) beats Inactivity (last activity more than 14 days ago) beats Renewal (renewal within 30 days) beats Milestone (milestone reached = true), else No Action.

The first matching trigger wins, exactly as the original priority cascade. Suppressed customers resolve to a suppressed state regardless of trigger.

### FR3, n8n reads the view

n8n reads `CORE.V_CUSTOMER_TRIGGER`. The view has already applied suppression and picked the trigger, so n8n receives, per customer, the decision and the fields it needs to write the email. No category logic runs in n8n Code nodes anymore.

### FR4, Email generation (unchanged, in n8n)

For a customer with an actionable trigger, the existing per-category prompt generates the email body, with the fixed subject line for that category. Suppressed and No Action customers get no email.

### FR5, Audit logging to the fact table

Every customer the pipeline touches gets exactly one row appended to `CORE.ACTIVITY_LOG`: timestamp, customer id, name, company, trigger type (or Suppressed / No Action), email-sent flag, message preview (first 100 chars, blank for suppressed and no-action). The fact table is append-only and is the complete audit trail, including the customers deliberately not contacted.

### FR6, Last-contacted write-back

After a customer receives an email, n8n writes today's date to that customer's `LAST_CONTACTED_DATE` in `CORE.CUSTOMER`. This is what the suppression window in the view reads on the next run.

---

## Non-Functional Requirements

### NFR1, Free trial only

XS warehouse, auto-suspend 60s, inside the 30-day trial credits.

### NFR2, No hardcoded credentials or identifiers

No account locator, warehouse, database, username, password, or key pair in any committed file. Placeholders only. The n8n Snowflake credential is wired through n8n's credential manager. Recipient email comes from the customer row, never hardcoded.

### NFR3, Reproducible setup

One idempotent SQL script in this folder creates the dimension, the fact table, and the view.

### NFR4, Platform

n8n orchestrates and generates the email; Snowflake is the data layer and does the suppression plus categorization. Deliverable: one importable workflow JSON plus the setup SQL.

---

## Acceptance Criteria

1. Running the setup SQL on a fresh trial account creates `CORE.CUSTOMER`, `CORE.ACTIVITY_LOG`, and `CORE.V_CUSTOMER_TRIGGER` with no manual edits beyond placeholders.
2. A customer last contacted within 7 days resolves to `SUPPRESSED = TRUE` in the view and gets a Suppressed row in the fact table, no email.
3. The view resolves each non-suppressed customer to the first matching trigger in priority order (Ticket, Inactivity, Renewal, Milestone), or No Action.
4. A customer with an actionable trigger receives exactly one email, body from the per-category prompt, fixed subject for that category.
5. Every touched customer produces exactly one `ACTIVITY_LOG` row with timestamp, customer, company, trigger type, email-sent flag, and preview.
6. Suppressed and No Action rows show email-sent false and a blank preview.
7. A customer who receives an email has today's date written to `LAST_CONTACTED_DATE`, and is suppressed on the next run.
8. No committed file contains a live identifier or credential.

---

## Resume keywords this build earns (once actually built)

Snowflake, data warehouse, dimensional modeling (customer dimension, activity fact), SQL views, windowed / analytical SQL, date-difference logic, audit table, customer data pipeline, ELT.

---

## Reference

- Original P07 build: `../README.md`, `../claude-code-build/REQUIREMENTS.md`
- Schema, the view SQL, and the n8n rewiring: `./BUILD_PROCESS.md`
- Setup and run: `./README.md` (Snowflake account setup is shared with the P02 build)
- Build directives: `./CLAUDE.md`
