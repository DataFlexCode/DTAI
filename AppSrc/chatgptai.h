Use ai.h

Struct tChatGPTError
    String message
    String type
    String param
    String code
End_Struct

Struct tChatGPTModel
    String id
    String Object
    Integer created
    String owned_by
End_Struct

Struct tChatGPTModelList
    tChatGPTModel[] data
    String Object
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
    DateTime created
    String model
    tChatGPTChoice[] choices
    tChatGPTUsage usage
End_Struct
