Use ai.h

Struct tChatGPTError
    String message
    String type
    String param
    String code
End_Struct

//Struct tChatGPTModel
//    String id
//    String Object
//    Integer created
//    String owned_by
//End_Struct
//
//Struct tChatGPTModelList
//    tChatGPTModel[] data
//    String Object
//End_Struct

// DataFlex struct definitions for ChatGPT Model List JSON

// Individual model structure
Struct tChatGPTModel
    { Name="object" }
    String sObject          // "model"
    String id              // Model identifier (e.g., "gpt-4o-audio-preview-2024-12-17")
    String[] SupportedMethods  // Array of supported methods (e.g., "chat.completions")
    String[] Groups        // Array of model groups (e.g., "gpt_4o")
    String[] Features      // Array of features (e.g., "streaming", "audio", "function_calling")
    Integer maxtokens      // Maximum tokens supported
    String owned_by        // Owner of the model (optional)
    Integer created        // Unix timestamp of creation (optional)
    String permission      // Permission level (optional)
    Boolean root           // Root access flag (optional)
    String parent          // Parent model (optional)
End_Struct

// Root structure for the model list response
Struct tChatGPTModelList
    { Name="object" } 
    String sObject          // "list"
    tChatGPTModel[] data   // Array of model objects
    Boolean has_more       // Whether there are more results (optional)
End_Struct

Struct tChatGPTMessage
    String role
    String content
End_Struct

Struct tChatGPTChoice
    Integer Index
    tChatGPTMessage message
    String finish_reason
End_Struct

Struct tChatGPTUsage
    Integer prompt_tokens
    Integer completion_tokens
    Integer total_tokens
End_Struct

Struct tChatGPTResponse
    String id
    String Object
    integer created
    String model
    tChatGPTChoice[] choices
    tChatGPTUsage usage
End_Struct
