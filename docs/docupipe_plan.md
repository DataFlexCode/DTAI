## Implementation plan for DocuPipe support in the Datatech AI library

### 1) Create a parallel “document pipeline” module (new top-level namespace)

Add a new module that does **not** pretend to be a chat model.

**Suggested package layout**

* `DocuPipe/`

  * `cDocuPipeClient.pkg` (low-level HTTP client)
  * `cDocuPipeDocumentService.pkg` (document upload + retrieval)
  * `cDocuPipeStandardizationService.pkg` (run standardization + fetch result)
  * `cDocuPipeJobService.pkg` (job polling)
  * `DocuPipeTypes.pkg` (request/response structs)
  * `DocuPipeErrors.pkg` (error mapping, retry wrapper)

This keeps responsibilities clean and lets you later add classification/workflows without contaminating the existing “prompt model” provider interface.

---

### 2) Define minimal DataFlex structs (raw JSON passthrough focused)

Because you want **raw DocuPipe JSON + metadata**, keep structs lean:

**Core structs**

* `tDocuPipeConfig`

  * `sApiKey`
  * `sBaseUrl` default `"https://app.docupipe.ai"` ([DocuPipe][1])
  * timeouts, retry flags
* `tDocuPipeResult`

  * `bOk`
  * `iHttpStatus`
  * `sError`
  * `sRawJson` (entire response body)
  * `sRequestId` (if DocuPipe returns one; optional)
* `tDocuPipeDocumentSubmitResponse` (parsed from raw json)

  * `sDocumentId` (DocuPipe returns a unique `documentId`) ([DocuPipe][1])
* `tDocuPipeStandardizeResponse`

  * `sJobId` ([help.docupipe.ai][5])
  * `sRawJson`
* `tDocuPipeJobResponse`

  * `sStatus` (e.g., running/completed/failed)
  * `sRawJson`
* `tDocuPipeStandardizationGetResponse`

  * `sRawJson` (and optionally `sDataJson` if DocuPipe nests under `data`) ([help.docupipe.ai][5])

Parse only what you must for orchestration (IDs, status). Everything else pass-through.

---

### 3) Low-level HTTP client: headers, retry-once, and payload support

Implement `cDocuPipeClient` around your existing JSON/HTTP infrastructure (e.g., `cdtJsonHttpTransfer`-style patterns you already use).

**Key requirements**

* Always add header: `X-API-Key: <key>` ([help.docupipe.ai][5])
* Add `Accept: application/json`
* For JSON bodies: `Content-Type: application/json` ([help.docupipe.ai][5])
* For file upload: support multipart form-data (DocuPipe “submit document” supports uploading local file or providing URL) ([DocuPipe][1])

  * If multipart is painful in DataFlex, you can support **URL-based submission first** (app uploads PDF to your doc store, then provides a presigned URL to DocuPipe). The endpoint explicitly allows a URL. ([DocuPipe][1])

**Retry policy**

* Wrap every request in `TryOnceRetryOnTransient()`:

  * Retry once on network failure / HTTP 429 / HTTP 5xx
  * No retry on 4xx (except 429)
* After retry, return a structured error to the caller (library does not decide next steps)

---

### 4) Core workflows (async-only)

#### A) Submit document (processing / OCR / text extraction)

Method:

* `SubmitDocumentFromFile(path, optional workflowId, optional datasetName) -> documentId + raw json`

  * POST `https://app.docupipe.ai/document` ([DocuPipe][1])
* `SubmitDocumentFromUrl(url, ...) -> documentId + raw json`

  * same endpoint ([DocuPipe][1])

Follow-up:

* `GetDocument(documentId) -> raw json`

  * GET `https://app.docupipe.ai/document/{document_id}` (returns `status` and `result` fields per docs) ([DocuPipe][2])

This supports your “upload PDF → later query status/results” UI queue idea (app stores `documentId` / doc URI in DB).

#### B) Standardize to schema (the JSON you actually want)

Method:

* `StandardizeDocuments(documentIds[], schemaId, guidelines, displayMode, splitMode, effortLevel) -> jobId + raw json`

  * POST `https://app.docupipe.ai/v2/standardize/batch` ([DocuPipe][3])
  * schemaId optional per docs (empty => ad-hoc) ([DocuPipe][3])

Polling:

* `GetJob(jobId) -> status + raw json`

  * GET `https://app.docupipe.ai/job/{job_id}` ([DocuPipe][4])

Result fetch:

* Once job complete, fetch standardization output:

  * Help-center example shows `GET https://app.docupipe.ai/standardization/{std_id}` and output under `data` ([help.docupipe.ai][5])
  * (In API Reference this may be “Retrieve a Standardization JSON” endpoint; implement as configurable path if needed.)

**Important note for desktop polling design**

* Your library should expose a “poll primitive” (GetJob) and let the *application* decide cadence, backoff, UI updates, and persistence (consistent with your answer #5).

---

### 5) Public API surface for your DataFlex library

Expose a small, composable interface that mirrors the async nature:

**Recommended public methods**

* `Configure(tDocuPipeConfig cfg)`
* `SubmitDocumentFromFile(...) -> tDocuPipeResult + documentId`
* `SubmitDocumentFromUrl(...) -> tDocuPipeResult + documentId`
* `GetDocument(documentId) -> tDocuPipeResult`
* `Standardize(documentIds[], schemaId, options...) -> tDocuPipeResult + jobId`
* `GetJob(jobId) -> tDocuPipeResult`
* `GetStandardization(standardizationId) -> tDocuPipeResult` (raw json)

Keep schema selection out of this layer (caller passes schemaId).

---

### 6) Logging + diagnostics (practical for customer rollouts)

Because you’ll be debugging customer documents:

* Log (sanitized) request metadata:

  * endpoint, method, documentId/jobId, http status, response time
* Store raw JSON responses optionally (feature toggle in config) so you can reproduce extraction issues
* Always bubble back the full raw body on error when possible (DocuPipe often returns useful error objects)

---

### 7) Testing plan (even before you have many PDFs)

* Unit tests with mocked HTTP responses:

  * Submit → returns documentId
  * Standardize → returns jobId
  * Job polling status transitions
* Integration tests (when you have samples):

  * For each doc type (produce invoice, freight invoice, handwritten timesheet):

    * Run end-to-end: submit → standardize with schemaId → poll job → fetch standardization JSON
  * Golden-file the **raw DocuPipe JSON** (since you’re not mapping into a Datatech struct yet)

---

## A Codex-ready “do the work” prompt you can paste

You can feed this to Codex verbatim:

> Implement DocuPipe support as a parallel “document pipeline” module (NOT as a chat provider). Use base URL `https://app.docupipe.ai`. Add `X-API-Key` header for auth on all requests. Core endpoints:
>
> * POST `/document` submit document (file upload or URL) returning `documentId`
> * GET `/document/{documentId}` returns `status` and `result`
> * POST `/v2/standardize/batch` accepts `documentIds` or dataset, optional `schemaId`, plus params `displayMode`, `splitMode`, `effortLevel`; returns `jobId`
> * GET `/job/{jobId}` poll job status
> * GET `/standardization/{standardizationId}` fetch standardized JSON output (help-center examples show output under `data`)
>   Requirements: async-only helpers (no blocking wait). Library returns raw DocuPipe JSON + minimal metadata (IDs/status). Single retry on transient failures (network/429/5xx) then return error. App controls schema selection and persistence/UI.
>   Create packages: `cDocuPipeClient`, `cDocuPipeDocumentService`, `cDocuPipeStandardizationService`, `cDocuPipeJobService`, plus types/errors. Provide DataFlex code skeletons, method signatures, and pseudo-implementations for HTTP calls (including multipart upload or URL-based submission first if multipart is hard). Include logging hooks and simple unit-test strategy with mocked responses.

---

If you want, I can also:

* pull the exact request/response fields for `/v2/standardize/batch` and `/document` from the reference pages you’ll use most, and
* suggest a clean way to implement multipart form-data in DataFlex (or a safer “URL submission first” approach).

[1]: https://docs.docupipe.ai/reference/post_document "Submit a Document for Processing"
[2]: https://docs.docupipe.ai/reference/get_document?utm_source=chatgpt.com "Retrieve a Processed Document"
[3]: https://docs.docupipe.ai/reference/post_standardize_batch_v2 "Standardize Documents"
[4]: https://docs.docupipe.ai/reference/get_job?utm_source=chatgpt.com "Retrieve a Job"
[5]: https://help.docupipe.ai/en/articles/10523724-standardization-101?utm_source=chatgpt.com "Standardization 101 🏢 | DocuPipe Help Center"
