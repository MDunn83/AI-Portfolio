# P03 Zapier Build: Lessons Learned

Mark Dunn | June 2026

This document covers what went wrong, what was surprising, and what I'd do differently if I built this in Zapier again. The n8n build is the reference implementation. This Zapier build exists as a comparison piece; same spec, different tool, very different experience.

---

## What I Observed Directly

**Zapier doesn't let you export a single workflow.** There's no "download this Zap as a file." If you want a portable artifact, you're screenshotting your canvas. n8n exports a clean JSON file you can commit, version, and share.

**Zapier Copilot was unreliable on basic requests.** It couldn't rename a path from "Path A" to "Funding Doc." It would confirm the change and then do nothing. For anything beyond template suggestions, Copilot was more friction than help. I had to go hands-on for the actual configuration work.

**Zapier doesn't pre-populate Google Sheets field mappings.** You have to map every column by hand. n8n has the same issue, so this isn't a point in either tool's favor, but it's worth knowing going in. Plan extra time for Sheets config on any multi-column write.

**You can't drag and reposition the canvas freely.** n8n lets you grab and move nodes anywhere. Zapier's canvas is more constrained. For a 15+ node workflow with branching paths, this got frustrating.

**Zapier has a wider app ecosystem for commodity integrations.** If you need to connect to a niche SaaS tool quickly, Zapier probably has it. n8n is catching up but isn't there yet. For the building-block stuff (Drive, Sheets, Gmail, Slack), both tools are equivalent.

**n8n is easier to troubleshoot.** In n8n, you can click any node, inspect its input and output, and see exactly what data is flowing. Zapier's test mode uses stale stub data that doesn't refresh when a live run happens. Debugging required switching between the editor and Zap History, which was slow.

---

## Technical Lessons

### PDF Handling Is a Real Gap in Zapier's Low-Code Model

"AI by Zapier" cannot read binary PDF files on the standard tier. It hallucinated a generic placeholder response ("This is a sample PDF file...") on every test run regardless of what file was actually in the trigger. The model is running on prompt text only with no file access.

The workaround was PDF.co, a third-party extraction service. That introduced a new requirement: the Google Drive Inbox folder has to be publicly shareable so PDF.co can fetch the file.

n8n handles binary files natively. You can pass a PDF as binary data between nodes without a third-party service and without any sharing changes to Drive.

**Bottom line:** PDF processing with private cloud storage is harder in Zapier than the documentation suggests. Plan for an extra integration layer and the constraints that come with it.

### Zapier's Code Step Input Mapping Is Non-Obvious

Data does not flow automatically between steps in a Code step. Every variable you want to access in your code has to be explicitly declared in the "Input Data" section of the step's Configure tab. If you skip this, `inputData` is empty and your code produces nothing.

The key naming also matters exactly: if your code says `inputData.extracted_metadata` and the Input Data key is `extracted_Metadata`, you get `undefined` with no error.

n8n's expression editor shows you upstream data inline as you type. You can also drag JSON output from a previous step directly into a field. That's a big difference in how it feels to build.

### Dynamic Output Schemas Break Zapier's Field Picker

The original code used a JavaScript spread operator to output different fields depending on the document category (funder_name for funding docs, vendor/customer for contracts, etc.). Zapier couldn't expose these dynamically-generated fields in the downstream field picker because it caches the output schema from the last test run.

The fix was to replace the dynamic spread with an explicit, static return object that declares every possible field by name with empty string fallbacks. Every category's fields show up every run; most are just blank. It works, but it's less elegant than the n8n approach where you can shape output dynamically.

### The Test Mode Stale Data Problem

Zapier's step editor shows you the output from the last configuration test, not the last live run. If you test Step 3, then drop a real file in Drive and the Zap runs live, Step 3's editor still shows the old test data. To refresh the sample, you have to walk the chain from Step 1 and click "Retest step" on every downstream step in order.

For a 15-step workflow with branching paths, this is genuinely tedious. n8n lets you trigger an execution and inspect every node's actual output from that run in one place.

### LLM Prompts Need the Data Explicitly Injected

"AI by Zapier" does not automatically pass upstream step data into the prompt. You have to use the `/` inline field picker to insert field references directly into the prompt text. A prompt that says "Analyze the following document" without a field reference is running on nothing.

This burned time early in the build because the prompt looked complete but the classifier was producing "Review" on every run with generic reasoning.

---

## On the Public Folder Sharing Requirement

The Inbox folder is set to "Anyone with the link can view" so PDF.co can fetch files. This is not acceptable for production use with sensitive documents.

In production, you would replace PDF.co with a self-hosted extraction service running inside your own infrastructure, or use a service account with delegated Drive access so the extraction happens server-side with proper credentials. Neither option is available in Zapier's standard integration model without custom API calls.

The n8n build handles this correctly; file extraction happens inside the n8n environment using Drive credentials already configured for the workflow.

---

## Tool Comparison: Zapier vs. n8n for This Build

| | Zapier | n8n |
|---|---|---|
| PDF text extraction | Requires third-party (PDF.co) + public folder | Native binary handling |
| Dynamic branching | Paths node, limited operators | Switch node, regex and expression support |
| Code step data access | Manual Input Data mapping required | Full upstream data available via expressions |
| Output schema | Static; dynamic fields break the picker | Fully dynamic |
| Canvas navigation | Fixed layout, limited drag | Free positioning |
| Debugging | Editor + Zap History are separate | Single execution inspector |
| Workflow export | No single-workflow export | JSON export, version-controllable |
| App ecosystem | Wider for niche SaaS tools | Catching up; full for common services |
| Copilot / AI assist | Available but unreliable | Not built-in |

**When Zapier wins:** teams without technical staff who need to connect commodity apps quickly, or workflows that are genuinely simple trigger-action chains.

**When n8n wins:** AI-heavy pipelines, file processing, complex branching logic, any workflow where you need to see what's actually happening at each step.

---

## What I Would Do Differently

If I built this in Zapier again, I would:

1. Set up PDF.co and the public Drive folder sharing before touching anything else. It's the prerequisite for every other step to work and costs the most debugging time if you hit it mid-build.
2. In the Code step, declare every output field you might ever need right at the start, even if most will be blank for a given run. Don't try to only output the fields that apply to the current document type. Zapier gets confused and stops showing the fields downstream.
3. Test the classifier's exact string output before building path filters. Pin the category values in the prompt ("return ONLY one of these exact strings") and confirm in a live run before setting up any conditions.
4. Walk the full chain with a real test file before configuring any downstream nodes. Stub data from test mode is not representative and leads to wasted configuration time.
5. Plan for the Sheets field mapping to be completely manual. Budget 20-30 minutes per path, not 5.
