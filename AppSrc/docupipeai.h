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

Struct tDocuPipeDocumentSubmitResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sDocumentId
    String sRawJson
End_Struct

Struct tDocuPipeStandardizeResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sJobId
    String sRawJson
End_Struct

Struct tDocuPipeJobResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sJobId
    String sStatus
    String sStandardizationId
    String sRawJson
End_Struct

Struct tDocuPipeStandardizationGetResponse
    Boolean bOk
    Integer iHttpStatus
    String sError
    String sStandardizationId
    String sRawJson
    String sDataJson
End_Struct
