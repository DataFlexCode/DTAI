// General struct defintions for AI interface

// this is actually the same as the definition for tClaudeAttachment
//  
Struct tAIAttachment
    UChar[] uBase64File
    String sMimeType
    String sFileID
End_Struct

// unified structure for all AI model details
Struct tAIModel
    String type         // Claude
    String id           // Claude, Grok
    String display_name // Claude
    String created_at   // Claude        
    Integer created     // UNIX creation date/time Grok
    {Name=object }
    String _object      // Grok
    String owned_by     // Grok
End_Struct

// unified response struct
Struct tAIResponseContentPart
    String sType          // "text", "inlineData", "functionCall", etc.
    String sRole          // "assistant", "user", "system", etc.
    String sText          // plain text if applicable
    String sMimeType      // for inline data
    String sData          // base64 encoded if inline
    String sFunctionName  // function call (Gemini)
    String sFunctionArgs
    String sFunctionContent
End_Struct

Struct tAIResponseUsage
    Integer iPromptTokens
    Integer iCompletionTokens
    Integer iTotalTokens
    Integer iInputTokens
    Integer iOutputTokens
    Integer iCacheCreationInputTokens
    Integer iCacheReadInputTokens
    String  sServiceTier
End_Struct

Struct tAISafetyRating
    String sCategory
    String sProbability
End_Struct

Struct tAIPromptFeedback
    tAISafetyRating[] safetyRatings
End_Struct

Struct tAIChoice
    Integer iIndex
    String  sFinishReason   // ChatGPT/Gemini
    String  sStopReason     // Claude
    String  sStopSequence   // Claude
    tAIResponseContentPart[] ContentParts
End_Struct

Struct tAIResponse
    String sId
    String sObjectOrType    // ChatGPT uses "object", Claude "type"
    DateTime dtCreated
    String sModel
    String sRole            // For single-role responses
    tAIChoice[] Choices     // Unifies ChatGPT choices, Claude content, Gemini candidates
    tAIResponseUsage Usage
    tAIPromptFeedback PromptFeedback // Gemini-specific, optional
End_Struct

