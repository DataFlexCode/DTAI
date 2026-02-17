# Docupipe Integration Plan for Datatech AI Library

## Objective
Implement Docupipe support in DTAI as a **parallel document pipeline** (not a chat provider), focused on:
1. Submitting documents for processing.
2. Launching schema-based standardization jobs.
3. Polling asynchronous status.
4. Returning **raw Docupipe JSON + minimal metadata**.

This aligns with the current requirement that the consuming application owns schema sourcing/selection, queue persistence, and UI workflow.

## Confirmed Product Constraints
- Parallel document-pipeline interface (not `cAiInterface` sibling behavior).
- Async-only helper methods (submit and poll later; no blocking wait helper).
- Schema source is application-owned (DB-backed in your implementation); library is schema-source agnostic.
- Application chooses schema (with optional user override).
- Library stops at extraction / standardization retrieval.
- Single retry on transient failure, then bubble error.
- Polling-first architecture (no webhook dependency initially).

## Docupipe Endpoints to Implement
Use `https://app.docupipe.ai` as default base URL.

1. `POST /document`
   - Submit document for processing.
   - Returns `documentId`.

2. `GET /document/{document_id}`
   - Retrieve processed document status/details.

3. `POST /v2/standardize/batch`
   - Start async standardization for one or more `documentIds`.
   - Supports optional `schemaId`, `guidelines`, `displayMode`, `splitMode`, `effortLevel`.
   - Returns `jobId`.

4. `GET /job/{job_id}`
   - Poll asynchronous job status.

5. `GET /standardization/{standardization_id}`
   - Retrieve standardized output JSON (final extraction payload).


## Documentation-Driven Endpoint Strategy
Given the broader DocuPipe API surface, the initial implementation remains intentionally narrow, but should reserve extension points for:

- **Workflow-driven submission**
  - `POST /workflow/on-submit-document` to create/update workflows.
  - `POST /document` with `workflowId` for one-call classify/split/standardize orchestration.
- **Bulk upload/standardize convenience endpoints**
  - `upload-multiple` and `upload-and-standardize-multiple` style endpoints for future throughput improvements.
- **Operational endpoints**
  - health checks, rate-limit guidance, and list/retrieve endpoints (`list_documents`, `list_jobs`, `list_standardizations`) to support observability and admin tooling.
- **Review and quality tooling**
  - visual review generation/retrieval endpoints for extraction QA workflows if customer support requires citeable evidence.

These are **not required for v1** but should influence class boundaries so they can be added without breaking the public API.

## Authentication and Headers
- `X-API-Key: <api key>` on all requests.
- `Accept: application/json` on all requests.
- `Content-Type: application/json` for JSON request bodies.
- Support multipart or JSON(base64) for document submission; if multipart is complex, prioritize URL/JSON flow first and add multipart next.

## Proposed Package Layout
Add a dedicated module set under `AppSrc`:
- `cDocuPipeClient.pkg`
  - Low-level HTTP calls, headers, retry wrapper, diagnostics.
- `cDocuPipeDocumentService.pkg`
  - Submit document, get document status/details.
- `cDocuPipeStandardizationService.pkg`
  - Start standardization batch, get standardization output.
- `cDocuPipeJobService.pkg`
  - Poll job status.
- `docupipeai.h`
  - Minimal structs for orchestration metadata + raw JSON.

This keeps Docupipe concerns isolated from chat-model abstractions.

## Data Contracts (Minimal + Raw JSON)
Define orchestration-first structs in `docupipeai.h`:

- `tDocuPipeConfig`
  - `String sApiKey`
  - `String sBaseUrl`
  - timeout/retry properties

- `tDocuPipeResult`
  - `Boolean bOk`
  - `Integer iHttpStatus`
  - `String sError`
  - `String sRawJson`
  - `String sRequestId` (optional)

- `tDocuPipeDocumentSubmitResponse`
  - `String sDocumentId`
  - `String sRawJson`

- `tDocuPipeStandardizeResponse`
  - `String sJobId`
  - `String sRawJson`

- `tDocuPipeJobResponse`
  - `String sJobId`
  - `String sStatus`
  - `String sRawJson`

- `tDocuPipeStandardizationGetResponse`
  - `String sStandardizationId`
  - `String sRawJson`
  - `String sDataJson` (optional convenience if payload nests under `data`)

Guiding rule: parse only IDs/status required for orchestration; pass through everything else.

## Public API Surface
Expose async-first methods only:

- `Procedure Configure tDocuPipeConfig cfg`
- `Function SubmitDocumentFromFile String sFilePath String sDataset String sWorkflowId Returns tDocuPipeDocumentSubmitResponse`
- `Function SubmitDocumentFromUrl String sUrl String sDataset String sWorkflowId Returns tDocuPipeDocumentSubmitResponse`
- `Function GetDocument String sDocumentId Returns tDocuPipeResult`
- `Function Standardize String[] aDocumentIds String sSchemaId String sGuidelines String sDisplayMode String sSplitMode String sEffortLevel Returns tDocuPipeStandardizeResponse`
- `Function GetJob String sJobId Returns tDocuPipeJobResponse`
- `Function GetStandardization String sStandardizationId Returns tDocuPipeStandardizationGetResponse`

Optional utility:
- `Function IsTerminalJobStatus String sStatus Returns Boolean`

## Retry + Error Policy
Implement once in `cDocuPipeClient` and reuse everywhere:
- Retry exactly once on:
  - transport/network failure
  - HTTP 429
  - HTTP 5xx
- Do not retry on 4xx except 429.
- Return structured errors; no UI popups inside library classes.

## Logging and Diagnostics
Add low-friction diagnostics hooks:
- request method + endpoint
- elapsed time
- HTTP status
- core IDs (`documentId`, `jobId`, `standardizationId`)
- optional raw JSON logging toggle

Return raw error payloads whenever available to aid customer troubleshooting.

## End-to-End Workflow (Application + Library)
1. App selects schema and submission options.
2. Library `SubmitDocument...` -> returns `documentId`.
3. App stores `documentId`/URI in its existing PDF tracking table.
4. App calls `Standardize(...)` -> receives `jobId`.
5. App polls `GetJob(jobId)` on its own schedule.
6. On completion, app calls `GetStandardization(standardizationId)` (ID from job payload).
7. App consumes raw JSON for downstream AP/payroll posting logic.

## Implementation Phases

### Phase 1: Contracts + Client Shell
1. Add `docupipeai.h` structs.
2. Add `cDocuPipeClient.pkg` with header injection + retry wrapper.
3. Add document/standardization/job service class shells.

### Phase 2: Endpoint Wiring
1. Implement `POST /document` (URL-based and/or file-based).
2. Implement `GET /document/{id}`.
3. Implement `POST /v2/standardize/batch`.
4. Implement `GET /job/{id}`.
5. Implement `GET /standardization/{id}`.

### Phase 3: Parsing + Ergonomics
1. Parse orchestration fields (`documentId`, `jobId`, status, standardization IDs).
2. Keep complete response as raw JSON.
3. Add README usage snippet for async polling pattern.

### Phase 4: Verification
1. Mocked-response tests:
   - submit -> documentId
   - standardize -> jobId
   - job status transitions
2. Manual integration tests with sample invoices/timesheets:
   - submit -> standardize -> poll -> fetch output
3. Retry-path tests for 429/5xx/network failures.

## Risks and Mitigations
- **Potential endpoint response shape drift:** Keep parsers tolerant and preserve full raw JSON.
- **File upload transport complexity in DataFlex:** Start with URL submission path if needed, then add multipart support.
- **Polling strategy variance by customer volume:** Keep cadence entirely application-controlled.


## Source-of-Truth Reconciliation Note
This plan should be reconciled against the supplied DocuPipe docs set, especially:
- API reference pages for `post_document`, `get_document`, `post_standardize_batch_v2`, `get_job`, and `get_standardization`.
- workflow pages (`workflow-upload-classify-and-standardize`, `upload-and-standardize-using-workflow`) for future one-call orchestration.
- rate-limit and health-check pages for operational hardening.

Pre-implementation verification checklist:
- request payload fields (`/document`, `/v2/standardize/batch`)
- response ID fields (`documentId`, `jobId`, `standardizationId`)
- status enums and terminal-state handling
- header/auth naming (`X-API-Key`)
- documented limits (file size/page count, endpoint-level limits, rate limits)

If machine-readable docs, guide docs, and reference pages disagree, treat endpoint reference pages as authoritative and preserve raw JSON passthrough to keep adapters resilient.
