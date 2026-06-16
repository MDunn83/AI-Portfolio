# BUILD_PROCESS.md

Architecture, design decisions, and node-level spec for the P03 Document Processing workflow.

---

## Environment

- n8n Cloud or self-hosted n8n instance
- Output: single importable n8n workflow JSON file
- `active: false` in exported JSON

---

## Credentials

Use these exact credential names so n8n wires them automatically on import:

| Service | Credential Name | n8n Internal Key |
|---|---|---|
| Google Drive | Google Drive OAuth2 API | `googleDriveOAuth2Api` |
| Google Sheets | Google Sheets OAuth2 API | `googleSheetsOAuth2Api` |
| Gmail | Gmail OAuth2 API | `gmailOAuth2` |
| Groq API | Groq API | `groqApi` |

---

## Google Drive Folder Structure

```
Doc Processing Pipeline/
├── Inbox/                    ← Drop PDF files here
├── Classified/
│   ├── Funding_Docs/
│   ├── Contracts/
│   ├── Invoices/
│   └── Certs/
├── Review/                   ← Unknown/ambiguous documents
└── Staging/                  ← Google Sheet lives here
```

---

## Google Sheets Structure

One spreadsheet with four tabs, one per document type. Each row is one processed document.

| Tab Name | Columns |
|---|---|
| **Funding Doc** | Timestamp, Filename, File ID, Funder, Recipient, Amount, Program, Key Terms |
| **Contracts** | Timestamp, Filename, File ID, Vendor, Customer, Effective Date, Expiration Date, Contract Value, Key Services, Governing Law |
| **Invoices** | Timestamp, Filename, File ID, Vendor, Customer, Invoice #, Invoice Date, Due Date, Amount, Line Items, Payment Status |
| **Certs** | Timestamp, Filename, File ID, Cert Holder, Issuer, Cert Type, Issue Date, Expiration Date, Cert # |

---

## Technology Choices

| Purpose | Tool | Notes |
|---|---|---|
| Classification | llama-3.1-8b-instant via Groq | Fast, simple single-field task |
| Metadata extraction | llama-3.3-70b-versatile via Groq | Complex structured output, handles longer documents |
| Document storage | Google Drive | Folder-based routing and organization |
| Data logging | Google Sheets | Per-category tabs for structured logging |
| Email notifications | Gmail | Formatted HTML output |

---

## Workflow Architecture

```
Schedule Trigger (or File Upload Trigger)
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
Basic LLM Chain (Classification; llama-3.1-8b-instant)
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

The classification LLM runs first and returns a category for each document. The Switch node then fans each document to its dedicated branch. Each branch uses a prompt and parser schema to pull only the fields relevant to that document type; no generic extraction, no wasted tokens.

All extraction branches use **llama-3.3-70b-versatile** for complex structured output. The classification step uses the lighter **llama-3.1-8b-instant** since it's a simpler single-field task.

Wait nodes are included before each versatile LLM call to prevent hitting Groq call limits.

---

## Metadata Extracted per Document Type

### Funding Doc
- Funder name
- Recipient name
- Award amount
- Program name
- Key terms

### Contract
- Vendor
- Customer
- Effective date
- Expiration date
- Contract value
- Key services
- Governing law

### Invoice
- Vendor
- Customer
- Invoice number
- Invoice date
- Due date
- Total amount
- Line items
- Payment status

### Certificate
- Certificate holder
- Issuer
- Certification name
- Issue date
- Expiration date
- Credential ID

---

## Key Design Decisions

**Confidence-based routing via Unknown category**

The classification prompt explicitly defines each category and instructs the model to return `unknown` for any document containing elements of more than one category. This prevents misclassification of hybrid documents. Unknown documents are routed to a human review queue (Review folder) instead of being miscategorized.

**File ID threading**

After the Extract from File node strips all upstream metadata, a Set node reattaches `file_id` and `name` by reaching back to the Search Files node using `$('Search files and folders').item.json.id`. This identifier threads through every downstream node and is used as the Merge key. It prevents positional mismatches across parallel branches.

**Prompt/parser separation**

Each LLM node's system prompt contains only extraction instructions without JSON formatting directives. The Structured Output Parser exclusively owns the output schema. Mixing both causes intermittent "Model output doesn't fit required format" errors.

**Model tiering**

Classification uses a small fast model (8b) while extraction uses a larger model (70b). This balances speed and cost for the simple classification step while ensuring reliable structured output on the more demanding extraction task.

---

## Lessons Learned

- **Prompt Tug-of-War**: System prompt vs parser schema conflict causes model output mismatches. Keep them separate; parser owns the schema, prompt owns the instructions.
- **Identifier Threading**: Extract from File node strips all upstream metadata. Reattach file_id explicitly using cross-node references to avoid positional mismatches across parallel branches.
- **Schema-First Design**: Define the parser output schema before writing the extraction prompt. Writing the prompt first leads to format conflicts.
- **Category Definition Discipline**: Category names need explicit definitions and trigger rules in the prompt, not just labels. Ambiguity leads to misclassification.
- **Google Drive Move node**: Requires explicit folder ID for Parent Drive, not the generic "My Drive" dropdown. The dropdown reference breaks on reimport.

---

## n8n JSON Output Rules

- Each node requires: `id` (UUID string), `name`, `type`, `typeVersion`, `position` (`[x, y]`), `parameters`, and `credentials` (where applicable)
- Connections are defined in the top-level `"connections"` object keyed by source node name
- Switch node outputs: output[0] = first branch (e.g., Funding), output[1] = second branch (e.g., Contract), etc.
- Validate JSON is syntactically correct before writing the file
- The `settings` object must include `"executionOrder": "v1"`
- File ID and filename must be explicitly threaded through Set nodes, not inferred from position
