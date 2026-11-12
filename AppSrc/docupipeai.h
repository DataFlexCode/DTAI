Use Windows.pkg

Struct tDocuPipeConfig
    String sApiKey
    String sBaseUrl
    Integer iTimeoutSeconds
    Integer iRetryCount
    Boolean bLogRawJson
End_Struct

Struct tDocuPipeResult
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sRawJson
    String sRequestId
End_Struct

// POST /document returns documentId plus the jobId of the upload/parse job.
// The document must finish parsing (job status "completed") before it is standardized.
Struct tDocuPipeDocumentSubmitResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sDocumentId
    String sJobId
    String sStatus
    String sRawJson
End_Struct

// GET /document/{id} reduced to what polling needs. sStatus is "processing", "completed" or "error".
// sRawJson is the complete document (includes the parsed text in "result", can be large)
Struct tDocuPipeDocumentStatusResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sDocumentId
    String sStatus
    String sRawJson
End_Struct

// POST /v3/standardize returns jobId + standardizationId.
// POST /v2/standardize/batch returns jobId (+ standardizationIds once known); sStandardizationId is the first one.
Struct tDocuPipeStandardizeResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sJobId
    String sStandardizationId
    String sStatus
    String sRawJson
End_Struct

// GET /job/{id}. sStatus is "processing", "completed" or "error"
Struct tDocuPipeJobResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sJobId
    String sStatus
    String sErrorMessage
    String sStandardizationId
    String sRawJson
End_Struct

// GET /standardization/{id}. sDataJson is the "data" member (the extracted fields)
Struct tDocuPipeStandardizationGetResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sStandardizationId
    String sRawJson
    String sDataJson
End_Struct

// POST /schema (or a schema ID reference read from a file). bExistingReference=True when the file only
// referenced an existing schemaId; bFromCache=True when the same file content was already registered this session
Struct tDocuPipeSchemaCreateResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sSchemaId
    String sSchemaName
    String sJobId
    Boolean bExistingReference
    Boolean bFromCache
    String sRawJson
End_Struct

// one row of GET /schemas (requested with exclude_payload=true, so no jsonSchema)
Struct tDocuPipeSchemaInfo
    String sSchemaId
    String sSchemaName
    String sTimestamp       // creation timestamp, ISO 8601 UTC e.g. 2026-11-12T20:03:36.211000Z
    String sFieldPreview    // fieldPreview[] joined with ", " (often empty)
    String sGuidelines
End_Struct

Struct tDocuPipeSchemaListResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    tDocuPipeSchemaInfo[] aSchemas
    String sRawJson
End_Struct
