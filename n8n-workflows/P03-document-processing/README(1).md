# n8n Document Processing & Classification Workflow


An automated document classification and routing pipeline built in n8n. Drop a PDF into a Google Drive inbox folder — the workflow reads it, classifies it using AI, extracts structured metadata, routes it to the correct subfolder, logs everything to Google Sheets, and sends a formatted email summary. Zero manual sorting required.

---

## What It Does

When a new PDF lands in the watched Google Drive inbox folder, the workflow:

1. **Downloads and extracts** the document text
2. **Classifies** the document into one of four categories using an LLM
3. **Routes** high-confidence documents to the correct Google Drive subfolder
4. **Flags** ambiguous or hybrid documents to a Review folder for human review
5. **Extracts** category-specific metadata fields using a second targeted LLM call
6. **Logs** all metadata to Google Sheets
7. **Sends** a clean formatted HTML email summary with the extracted details
8. **Moves** the file from the source folder to the correct categorized folder

---

## Document Categories

| Category | What It Classifies | (note, synthetic files were used for this workflow)
|---|---|
| **Funding Doc** | Investment agreements, term sheets, seed/series rounds |
| **Contract** | Service agreements, vendor MSAs, legal contracts (services only, no investment component) |
| **Invoice** | Vendor bills, payment requests, subscription renewals |
| **Certificate** | Training credentials, professional certifications, course completions |
| **Unknown** | Hybrid documents or anything that doesn't clearly fit one category — routed to Review folder |

---

## Architecture

```
Schedule Trigger
    ↓
Search Files and Folders (scan Inbox)
    ↓
Edit Fields (map file_id + name)
    ↓
Switch2 (file type routing: .pdf, .docx, .md)
    ↓
Download File
    ↓
Extract from File (PDF → plain text)
    ↓
Edit Fields1 (reattach file_id + name post-extraction)
    ↓
Basic LLM Chain (Classification — llama-3.1-8b-instant)
    ↓
Merge (combine classification output with file metadata)
    ↓
Switch (route on category)
    ↓
    ├── Funding → Funding LLM → Parser → Merge → Sheets + Email + Move
    ├── Contract → Contract LLM → Parser → Merge → Sheets + Email + Move
    ├── Invoice → Invoice LLM → Parser → Merge → Sheets + Email + Move
    ├── Certificate → Certificate LLM → Parser → Merge → Sheets + Email + Move
    └── Unknown → Move to Review folder + Email alert
```

---

## Parallel Processing Design

The classification LLM runs first and returns a category for each document. The Switch node then fans each item to its dedicated branch. Each branch uses a prompt and parser schema to pull only the fields relevant to that document type so there's no generic extraction nor wasted tokens.

All extraction branches use **llama-3.3-70b-versatile** for complex structured output. The classification step uses the lighter **llama-3.1-8b-instant** since it's a simpler single-field task.  Note, I included "Wait" nodes before each of the versatile LLM nodes since I was hitting call limits without them.

---

## Metadata Extracted by Document Type

**Funding Doc**
- Funder name, recipient name, award amount, program name, key terms

**Contract**
- Vendor, customer, effective date, expiration date, contract value, key services, governing law

**Invoice**
- Vendor, customer, invoice number, invoice date, due date, total amount, line items, payment status

**Certificate**
- Certificate holder, issuer, certification name, issue date, expiration date, credential ID

---

## Google Drive Folder Structure

```
Doc Processing Pipeline/
├── Inbox/                    ← Drop files here
├── Classified/
│   ├── Funding_Docs/
│   ├── Contracts/
│   ├── Invoices/
│   └── Certs/
├── Review/                   ← Unknown/ambiguous documents
└── Staging/                  ← Google Sheet lives here
```

---

## Google Sheets Logging

One spreadsheet with four tabs for each document type. Each row is one processed document.

**Funding Docs:** Timestamp | Filename | File ID | Funder | Recipient | Amount | Program | Key Terms 

**Contracts:** Timestamp | Filename | File ID | Vendor | Customer | Effective Date | Expiration Date | Contract Value | Key Services | Governing Law 

**Invoices:** Timestamp | Filename | File ID | Vendor | Customer | Invoice # | Invoice Date | Due Date | Amount | Line Items | Payment Status

**Certs:** Timestamp | Filename | File ID | Cert Holder | Issuer | Cert Type | Issue Date | Expiration Date | Cert # 

---

## Email Output

Each processed document triggers a formatted HTML email with clearly labeled sections. The email adapts dynamically based on document type so that only fields relevant to that category are shown. Null fields are suppressed.

```
📄 Document Classified & Routed

Document Type:  contract
Filename:       doc_5_contract_consulting.pdf
Routed To:      Contracts
Timestamp:      2026-04-24T10:05:23

─────────────────────────────────
Extracted Details

Vendor:           Strategic Growth Consulting LLC
Customer:         CloudSync Technologies Inc.
Effective Date:   April 1, 2026
Expiration Date:  March 31, 2027
Contract Value:   $8,500 USD/month
Key Services:     Business consulting, strategy, board reporting
```

---

## AI Models

| Node | Model | Reason |
|---|---|---|
| Classification | llama-3.1-8b-instant | Fast, simple single-field task |
| All extraction branches | llama-3.3-70b-versatile | Complex structured output, handles longer documents |

All models run via **Groq** for low-latency inference.  I wanted to use something free for proof of concept, but you can use whatever LLM you like that gets the job done.

---

## Prerequisites

- n8n Cloud account (or self-hosted n8n instance)
- Google account with Drive, Sheets, and Gmail access
- Groq API key (free tier available)

---

## Setup

### Step 1: Google Drive
Create the folder structure above. Copy the folder ID from the URL of each folder — you'll need them in n8n.

```
https://drive.google.com/drive/folders/[FOLDER_ID_IS_HERE]
```

### Step 2: Google Sheets
Create a spreadsheet with four tabs named exactly:
- `Certs`
- `Contracts`
- `Funding Doc`
- `Invoices`

Add the column headers for each tab as listed in the Google Sheets Logging section above.

### Step 3: n8n Credentials
Create the following credentials in n8n:

| Credential | Used By |
|---|---|
| Groq API | All LLM nodes |
| Google Drive OAuth2 | Search, Download, Move nodes |
| Google Sheets OAuth2 | Append row nodes |
| Gmail OAuth2 | Send email nodes |

### Step 4: Import Workflow
1. Import `Meeting_Minutes_clean.json` via the n8n workflow menu (⋯ → Import)
2. Update all Google Drive nodes with your actual folder IDs
3. Update all Google Sheets nodes with your spreadsheet ID and tab names
4. Update the Gmail node with your email address
5. Connect all credentials to their respective nodes
6. Activate the workflow

### Step 5: Test
Upload a PDF to your Inbox folder. Within 60 seconds you should see:
- The file moved to the correct subfolder
- A new row in the appropriate Google Sheet tab
- A formatted HTML email in your inbox

---

## Environment Variables

Set these in your n8n instance settings or as environment variables:

```
GROQ_API_KEY=
INBOX_FOLDER_ID=
FUNDING_FOLDER_ID=
CONTRACTS_FOLDER_ID=
INVOICES_FOLDER_ID=
CERTS_FOLDER_ID=
REVIEW_FOLDER_ID=
GOOGLE_SHEETS_ID=
```

---

## Key Design Decisions

**Confidence-based routing via Unknown category**
The classification prompt explicitly defines each category and instructs the model to return `unknown` for any document containing elements of more than one category. This is meant to prevent misclassification of hybrid documents.  These "unknown" documents get routed to a human review queue instead of being miscategorized.

**file_id threading**
After the Extract from File node strips all upstream metadata, I used a Set node to reattach `file_id` and `name` by reaching back to the Search Files node using `$('Search files and folders').item.json.id`. This identifier threads through every downstream node and is used as the Merge key.  It's used to avoid positional mismatches across parallel branches.

**Prompt/parser separation**
Each LLM node's system prompt contains only extraction instructions without JSON formatting directives. The Structured Output Parser exclusively owns the output schema. Mixing both causes intermittent 'Model output doesn't fit required format' errors.

**Model tiering**
Classification uses a small fast model (8b) while xtraction uses a larger model (70b). I did this to balance speed and cost for the simple classification step while ensuring reliable structured output on the more demanding extraction task.

---

## Lessons Learned

- **Prompt Tug-of-War** — system prompt vs parser schema conflict
- **Identifier Threading** — reattaching file_id after file processing nodes strip it
- **Schema-First Design** — define the parser before writing the prompt
- **Category Definition Discipline** — category names need explicit definitions and trigger rules, not just labels
- **Google Drive Move node** — requires explicit folder ID for Parent Drive, not the generic 'My Drive' dropdown

---

## File Structure

```
doc-processing-workflow/
├── Meeting_Minutes_clean.json    ← n8n workflow (credentials scrubbed)
└── README.md
```

---

## Built With

- [n8n](https://n8n.io) — workflow automation
- [Groq](https://console.groq.com) — LLM inference
- [LLaMA 3.1 8b Instant](https://groq.com) — document classification
- [LLaMA 3.3 70b Versatile](https://groq.com) — metadata extraction
- Google Drive — document storage and routing
- Google Sheets — persistent classification log
- Gmail — formatted email notifications

---

## Part of a Larger Portfolio

This workflow is the third in a series of AI automation projects built to demonstrate enterprise-grade workflow design, AI orchestration, and responsible automation practices.

| # | Project | Status |
|---|---|---|
| 1 | Meeting Intelligence Pipeline | ✅ Complete |
| 2 | Competitive Intelligence Monitor | ○ Planned |
| 3 | Document Processing & Routing | ✅ Complete |
| 4 | AI Governance & Audit Trail | ○ Planned |
| 5 | Employee Onboarding Orchestrator | ○ Planned |
| 6 | Lead Generation & Enrichment | ○ Planned |
| 7 | Customer Trigger Messaging | ○ Planned |
