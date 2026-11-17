// General struct defintions for AI interface
struct tRestCallStats
    datetime dtStart
    datetime dtStop
    timespan tElapsed
    // add size of request/response? add status code result, transfer error description?
end_struct
    
// this is actually the same as the definition for tClaudeAttachment
//  
Struct tAIAttachment
    UChar[] uBase64File
    String sMimeType
    String sFileID
    String sDescription         // for reference/UI only, not passed to AI at the moment
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

//-----------------------------------------------------------------------------
// Tool calling (function calling) and conversation support
// See tool_calls_plan.md. Everything here must stay DataFlex 19.1 compatible.
//-----------------------------------------------------------------------------

// Normalized stop reasons (tAIResponse.eStopReason)
Define AI_STOP_UNKNOWN        for 0
Define AI_STOP_END_TURN       for 1   // normal final answer (stop / end_turn / STOP)
Define AI_STOP_TOOL_CALLS     for 2   // model wants tools run (tool_calls / tool_use / functionCall parts)
Define AI_STOP_MAX_TOKENS     for 3   // length / max_tokens / MAX_TOKENS
Define AI_STOP_CONTENT_FILTER for 4   // content_filter / refusal / SAFETY etc.
Define AI_STOP_ERROR          for 5   // transport or API error (see psLastError)
Define AI_STOP_CONFIRMATION   for 6   // tool loop paused: calls need the app/user to approve them

// Tool choice (peToolChoice)
Define AI_TOOLCHOICE_AUTO     for 0   // model decides (default)
Define AI_TOOLCHOICE_NONE     for 1   // tools sent but must not be called
Define AI_TOOLCHOICE_REQUIRED for 2   // must call at least one tool
Define AI_TOOLCHOICE_SPECIFIC for 3   // must call psToolChoiceName

// Error numbers (piLastErrorNumber)
Define AI_ERR_NONE            for 0
Define AI_ERR_NO_API_KEY      for 1
Define AI_ERR_TRANSFER        for 2   // WinINet/transfer failure, timeout
Define AI_ERR_API             for 3   // provider returned an error object
Define AI_ERR_PARSE           for 4   // response not JSON / unexpected shape
Define AI_ERR_TOOL_LOOP       for 5   // loop limit, repeated call, etc.
Define AI_ERR_TOOL_DEFINITION for 6   // invalid tool name/schema, duplicate tool

// Tool confirmation answers (OnConfirmToolCall)
Define AI_CONFIRM_YES         for 1
Define AI_CONFIRM_NO          for 2
Define AI_CONFIRM_DEFER       for 3   // pause the loop and hand the decision to the app

Struct tAIToolDefinition
    String  sName                  // ^[a-zA-Z0-9_-]{1,64}$
    String  sDescription           // required by xAI, recommended everywhere
    String  sParametersJson        // JSON Schema, root must be {"type":"object",...}
    Boolean bStrict                // OpenAI/Claude strict schema mode (ignored elsewhere)
    Boolean bRequiresConfirmation  // ask before running (decision D5)
End_Struct

Struct tAIToolCall
    String  sId                    // provider call id; Gemini: id if returned, else generated
    String  sName
    String  sArgumentsJson         // JSON object text, normalized ("{}" when empty)
    Integer iIndex                 // order within the assistant turn
    String  sProviderData          // opaque per-provider extras (e.g. Gemini thoughtSignature)
End_Struct

Struct tAIToolResult
    String  sCallId                // = tAIToolCall.sId
    String  sName                  // = tAIToolCall.sName (Gemini needs it)
    String  sContent               // text or JSON text returned by the app
    Boolean bIsError               // tool failed / declined; sContent holds the message
End_Struct

// One conversation turn, provider neutral (held by cAIConversation)
Struct tAIMessage
    String          sRole          // "user" | "assistant" | "tool"
    String          sText          // text for user/assistant turns
    tAIAttachment[] Attachments    // user turns only
    tAIToolCall[]   ToolCalls      // assistant turns that requested tools
    tAIToolResult[] ToolResults    // "tool" turn: all results for the previous assistant turn
    String          sProvider      // "claude" | "chatgpt" | "grok" | "gemini" (assistant turns)
    UChar[]         ucProviderJson // raw provider message JSON, UTF-8 (StringifyUtf8), for exact replay
    String          sSpeaker       // optional label (AI-to-AI: who said it)
    Boolean         bRelayed       // user turn relayed from another AI (not recorded twice in a transcript)
End_Struct

// Shared transcript entry (cAITranscript); never sent to a model
Struct tAITranscriptEntry
    String   sSpeaker
    String   sRole
    String   sText
    DateTime dtWhen
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
    String sToolCallId    // tool calls: provider call id (sType = "tool_call")
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
    // added for tool calling (tool_calls_plan.md)
    Integer       eStopReason           // AI_STOP_*
    String        sText                 // joined text of choice 0's text parts
    tAIToolCall[] ToolCalls             // tool calls of choice 0, flat
    Integer       iToolIterations       // round trips used by the tool loop
    tAIToolCall[] PendingConfirmations  // calls waiting for approval (AI_STOP_CONFIRMATION)
    tAIMessage    AssistantMessage      // the assistant turn as stored in the conversation
End_Struct

