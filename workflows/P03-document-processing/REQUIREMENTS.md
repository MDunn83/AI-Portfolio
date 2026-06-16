# P03 Document Processing and Classification Pipeline
## Requirements Document

Version 1.0 | June 2026

---

## Goal

Drop a PDF into a watched Google Drive inbox folder. Get back, automatically:

1. A document classification into one of four categories (or Unknown if ambiguous).
2. Extraction of category-specific metadata fields.
3. Routing to the correct subfolder (or Review for ambiguous documents).
4. A complete log entry in Google Sheets.
5. A formatted HTML email summary with extracted details.

Zero manual sorting required. The entire workflow runs on file upload.

---

## Scope

### In scope

- Trigger on new PDF upload to the Google Drive inbox folder.
- Text extraction from PDF documents.
- LLM-based document classification into four defined categories.
- Confidence-based routing; ambiguous documents routed to Review folder.
- Category-specific metadata extraction using a second LLM call.
- Logging all documents to Google Sheets with per-category tabs.
- HTML email notifications with extracted metadata.
- File movement from inbox to the correct categorized subfolder.

### Out of scope

- Non-PDF file formats (DOCX, TXT, images, etc.).
- Multi-tenant support or role-based access control.
- Real-time polling; pipeline is trigger-based only.
- Document editing or annotation after submission.
- Manual approval or review-cycle workflow (Review folder is hand-triage only).
- Custom categories beyond the four defined types.

---

## Document Categories

| Category | What It Classifies |
|---|---|
| **Funding Doc** | Investment agreements, term sheets, seed rounds, series rounds, funding offers |
| **Contract** | Service agreements, vendor MSAs, legal contracts (services only, no investment component) |
| **Invoice** | Vendor bills, payment requests, subscription renewals, expense reports |
| **Certificate** | Training credentials, professional certifications, course completions, badges |

---

## Functional Requirements

### FR1 -- Trigger

Pipeline fires when a new PDF file is uploaded to the watched Google Drive inbox folder. The trigger captures the file ID, filename, and prepares the document for processing.

### FR2 -- Text extraction

Extract plain text from the PDF file. The extracted text becomes the input for classification and metadata extraction.

### FR3 -- Classification

Use an LLM to classify the document into one of four categories: Funding Doc, Contract, Invoice, or Certificate. If the document contains elements of multiple categories or does not clearly fit one category, classify it as Unknown.

The classification model is llama-3.1-8b-instant (fast, single-field task).

### FR4 -- Confidence-based routing

Documents classified as Unknown are routed to the Review folder for human triage. High-confidence documents (Funding Doc, Contract, Invoice, Certificate) proceed to extraction and routing.

### FR5 -- Category-specific extraction

For documents with confirmed categories, extract metadata fields specific to that type:

- **Funding Doc**: Funder name, recipient name, award amount, program name, key terms
- **Contract**: Vendor, customer, effective date, expiration date, contract value, key services, governing law
- **Invoice**: Vendor, customer, invoice number, invoice date, due date, total amount, line items, payment status
- **Certificate**: Certificate holder, issuer, certification name, issue date, expiration date, credential ID

The extraction model is llama-3.3-70b-versatile (reliable structured output on complex documents).

### FR6 -- Parallel processing

After classification, the workflow fans each document to its dedicated extraction branch. All extraction happens in parallel; no sequential per-type processing.

### FR7 -- Google Sheets logging

Append one row to the appropriate Google Sheets tab for every processed document, regardless of classification outcome. Log columns include: Timestamp, Filename, File ID, and all extracted fields for that category.

### FR8 -- Email notification

Send a formatted HTML email summarizing the classification result and extracted metadata. The email adapts dynamically; only fields relevant to that document type are displayed. Null fields are suppressed.

### FR9 -- File movement

Move the processed PDF from the inbox to the correct categorized subfolder:
- Funding Docs → `Classified/Funding_Docs/`
- Contracts → `Classified/Contracts/`
- Invoices → `Classified/Invoices/`
- Certificates → `Classified/Certs/`
- Unknown → `Review/`

---

## Non-Functional Requirements

### NFR1 -- Model tiering

Classification uses llama-3.1-8b-instant for speed on the simple single-field task. All extraction branches use llama-3.3-70b-versatile for reliable structured output on longer documents. No generic extraction; each branch uses a prompt tailored to its category.

### NFR2 -- No hardcoded credentials or folder IDs

All Google Drive folder IDs, Google Sheets spreadsheet ID, and Gmail addresses are supplied via n8n credentials and environment variables. The exported workflow JSON uses placeholders for all IDs.

### NFR3 -- No manual steps after trigger

Once a PDF lands in the inbox, the entire pipeline runs to completion without operator intervention.

### NFR4 -- Identifier threading

File ID and filename persist through all parallel branches via explicit field threading. Positional mismatches across branches are prevented by using file ID as the merge key, not row position.

### NFR5 -- Platform

Must run on n8n Cloud or self-hosted n8n instance. Output is a single importable n8n workflow JSON file with `active: false` flag.

---

## Acceptance Criteria

1. Uploading a PDF to the inbox folder triggers the pipeline without manual intervention.
2. A document is correctly classified into Funding Doc, Contract, Invoice, or Certificate based on its content.
3. A document with elements of multiple categories, or unclear content, is classified as Unknown.
4. Unknown documents are routed to the Review folder with no other processing.
5. High-confidence documents are routed to their correct subfolder (Funding_Docs, Contracts, Invoices, or Certs).
6. Extraction fields for each category are correctly populated and logged to the appropriate Google Sheets tab.
7. A formatted HTML email is sent with the classification result and extracted metadata.
8. A new row is appended to Google Sheets for every processed document, with Timestamp, Filename, File ID, and category-specific fields.
9. The file is moved from Inbox to its categorized subfolder or Review folder.
10. The exported workflow JSON contains no live credentials, folder IDs, or email addresses.

---

## Reference

- Architecture and design rationale: `./BUILD_PROCESS.md`
- Setup and human-facing instructions: `./README.md`
- n8n workflow file: `./P03-document-processing.json`
