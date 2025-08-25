//-----------------------------------------------------------------------------
// DataFlex Structures for Gemini API Request
//-----------------------------------------------------------------------------

// This is a simplified representation of a Gemini API content part.
// It is used to pass data into the main procedure.
Struct tGeminiPart
    String sRole
    String sPartType  // "text" or "inlineData" or "functionCall"
    String sText      // Used for text parts
    String sMimeType  // Used for inlineData parts (e.g., "image/jpeg")
    String sData      // Base64-encoded data for inlineData parts
    String sFunctionName // Used for functionCall and functionResponse parts
    String sFunctionArgs // JSON string of arguments for functionCall
    String sFunctionContent // JSON string of response for functionResponse
End_Struct

// This structure holds optional generation parameters.
Struct tGenerationConfig
    Integer iMaxOutputTokens
    Number nTemperature
    Number nTopP
    Integer iTopK
End_Struct

//-----------------------------------------------------------------------------
// Structures for Deserializing Gemini API Responses
// Member names match JSON keys for proper deserialization.
//-----------------------------------------------------------------------------

// Used to represent the "parts" array inside a candidate's content
Struct tGeminiContentPart
    String text
End_Struct

// Used to represent the "content" of a candidate
Struct tGeminiCandidateContent
    tGeminiContentPart[] parts
    String role
End_Struct

// Used to represent a "safetyRating" for a prompt
Struct tGeminiSafetyRating
    String category
    String probability
End_Struct

// Used to represent the "promptFeedback" from the API
Struct tGeminiPromptFeedback
    tGeminiSafetyRating[] safetyRatings
End_Struct

// Used to represent a "candidate" response from the API
Struct tGeminiCandidate
    tGeminiCandidateContent content
    String finishReason
    Integer Index
End_Struct

// Used for a successful API response
Struct tGeminiResponse
    tGeminiCandidate[] candidates
    tGeminiPromptFeedback promptFeedback
End_Struct

// Used for an API error response
Struct tGeminiError
    Integer code
    String message
    String status
End_Struct

// Master response struct that can hold either a successful or error response.
// You will need to check which member is populated after deserializing.
Struct tGeminiMasterResponse
    tGeminiResponse response
    { Name="Error" }
    tGeminiError GeminiError
End_Struct

//-----------------------------------------------------------------------------
// Structures for Deserializing the Gemini Model List API Response
// Member names match JSON keys for proper deserialization.
//-----------------------------------------------------------------------------

// Used to represent each individual model in the response
Struct tGeminiModel
    String name
    String version
    String displayName
    String description
    Integer inputTokenLimit
    Integer outputTokenLimit
    String[] supportedGenerationMethods
    Number temperature
    Number  topP
    Integer topK
End_Struct

// Used to represent the full model list response
Struct tGeminiModelList
    tGeminiModel[] models
End_Struct
