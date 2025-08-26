Use ai.h

Struct tClaudeError
    String type
    String message
End_Struct

Struct tClaudeModel
    String type
    String id
    String display_name
    String created_at    
End_Struct

Struct tClaudeModelList
    tClaudeModel[] data
    Boolean has_more
    String first_id
    String last_id
End_Struct

Struct tClaudeResponseContent
    String type
    String text
End_Struct

Struct tClaudeResponseUsage
    Integer input_tokens
    Integer cache_creation_input_tokens
    Integer cache_read_input_tokens
    Integer output_tokens
    String service_tier
End_Struct

Struct tClaudeResponse
    String id
    String type
    String role
    String model
    tClaudeResponseContent[] content
    String stop_reason
    String stop_sequence
    tClaudeResponseUsage usage
End_Struct

Struct tClaudeAttachment
    UChar[] uBase64File
    String sMimeType
    String sFileID
End_Struct

Struct tClaudeResponseUploadFile
    String id
    String type
    String filename
    Integer size
    DateTime created_at
    String purpose
End_Struct

Struct tClaudeFile
    String type
    String id
    Integer size_bytes
    DateTime created_at
    String filename
    String mime_type
    Boolean downloadable    
End_Struct

Struct tClaudeFileList
    tClaudeFile[] data
    Boolean has_more
    String first_id
    String last_id
End_Struct
