# Tool Call (Function Calling) Support Plan for Datatech AI Library (DTAI)

Matt Davidian, November 2026. Branch: `tool-call-support`

Revision 2 (Nov 14, 2026): records Matt's decisions on the first round of open questions, adds silent errors, tool confirmation and a DataFlex 19.1 compatibility review.

Revision 3 (Nov 14, 2026): resolves D3. History lives in a separate `cAIConversation` object (per view or task, attachable to any provider, AI-to-AI relay, optional shared transcript). Phases 0 and 1 are implemented and compile on 19.1 and 25.0.

Revision 4 (Nov 15, 2026): Phase 2 (Claude) and most of Phase 3 (the `Chat`/`ContinueConversation` loop, confirmation, error capture inside tools) are implemented and tested offline with saved Claude samples and a fake transport, on 19.1 and 25.0. Not yet run against the live Claude API.

Revision 5 (Nov 15, 2026): Phase 3 finished (`AIToolCallTest.vw`, `cAIDialogue`, log limits). Phases 4 (ChatGPT) and 5 (Grok on Chat Completions) implemented and tested offline. Offline tests: 194 pass on 19.1 and 25.0. Nothing has been run against the live APIs yet.

Revision 6 (Nov 15, 2026): Phase 6 (Gemini) implemented and tested offline; Gemini is enabled in `AIToolCallTest.vw`. The confirmation state (pending calls, held results, approvals) moved from the provider object to `cAIConversation`, so two views or tasks sharing a provider object don't interfere. Offline tests: 250 pass on 19.1 and 25.0. Still nothing run against the live APIs.

Revision 7 (Nov 16, 2026): default models updated (the old Claude, ChatGPT and Grok defaults are retired or shut down, Gemini 2.5 Flash is deprecated): Claude `claude-sonnet-5-5`, ChatGPT `gpt-6-luna`, Gemini `models/gemini-3.8-flash`, Grok `grok-4.7`. ChatGPT sends `max_completion_tokens` for reasoning models and `reasoning_effort: "none"` when tools are sent (Chat Completions needs it for function calling on `gpt-6-luna`). `AIToolCallTest.vw` has a Model combo.

## Objective
Add tool call support (also called function calling) to the four chat providers: `cChatGPTInterface`, `cClaudeInterface`, `cGeminiInterface` and `cGrokInterface`. It sits behind **one provider-neutral DataFlex interface** in `cAiInterface`, so an application can:

1. Define a tool once: a name, a description and a JSON Schema for its parameters.
2. Run a prompt against any provider using the same calls.
3. Receive tool calls in one standard shape, run them in DataFlex code (database lookups, calculations, business rules) and hand back a result string.
4. Let the library carry the request, tool call, tool result and next request loop until the model gives a final answer. Apps can also drive each step by hand.

Switching providers must not change the application's tool code.

## Decisions (Nov 14, 2026)

| # | Topic | Decision |
|---|---|---|
| D1 | Grok endpoint | Move `cGrokInterface` off the deprecated `/v1/messages` to **`/v1/chat/completions`**. It shares the ChatGPT (OpenAI format) request builder and response parsing. |
| D2 | OpenAI API | ChatGPT stays on **Chat Completions** for v1. The Responses API (OpenAI and xAI) is a later item. |
| D3 | Conversation history | **Resolved (rev 3).** The library owns history in a separate **`cAIConversation`** object (`cAIConversation.pkg`) that holds neutral `tAIMessage` turns. Attach one with `Set phoConversation of ghoClaudeAI to oConv`; with none attached, the provider uses its own internal default conversation. Each view or task can own its own conversation and switch between them. AI-to-AI uses one conversation per participant plus a relay helper, and an optional shared transcript (`cAITranscript`) that is never sent to the models. Saving to a table is a later item. See "Conversation history storage". |
| D4 | Errors | Add a **silent-errors option**: `pbSilentErrors`, plus `psLastError`/`piLastErrorNumber`/`piLastHttpStatus`. When it is on, the library sets these instead of showing `Stop_Box`/`UserError`/`Info_Box`. This applies to every provider call, not only tool loops. |
| D5 | Confirmation | v1 includes a **"requires confirmation" option** for tools (`pbRequiresConfirmation` on `cAITool`, or a parameter on `AddTool`). |
| D6 | DataFlex version | The library **must compile and run under DataFlex 19.1** as well as 25.0. See "DataFlex 19.1 Compatibility" for the review and the design changes it caused. |

## How Tool Calling Works (all providers)
1. The request includes the list of tool definitions.
2. The model either answers with text or stops with one or more **tool calls** (name plus JSON arguments).
3. The client runs each tool and sends a new request. That request holds the full conversation so far, plus the assistant's tool-call turn and a **tool result** for every call.
4. Repeat until the model returns a normal answer, or a loop limit is reached.

Every provider is stateless here (no server-side conversation on the endpoints DTAI uses). Step 3 therefore needs **multi-turn conversation history**, which DTAI does not have today (see findings).

---

## Current Architecture Findings

### Base class: `cAiInterface` (`AppSrc\ai.pkg`)
- `cAiInterface is a cdtJsonHttpTransfer`. It mixes in `cMarkdown_mixin` and `cBase64Attachment_mixin`.
- Properties: `paModels`, `psApiKey`, `psModelResponseJson`, `psModelRequestJson` and `pLastCallStats`.
- It overrides `HttpPostJson` to record timing in `pLastCallStats`.
- The "standard interface" is four abstract functions that subclasses override:
  - `CreateRequest String sPrompt tAIAttachment[] Attachments Returns Handle`
  - `MakeRequest Handle hoRequest Returns tAIResponse`
  - `MakeRequestJSON Handle hoRequest Returns Handle`
  - `ModelList Returns tAIModel[]`
- **The interface is single-turn.** `CreateRequest` takes one prompt string. No class holds conversation history.
  - `AIChatExample.vw` (`SubmitPrompt`) fakes a conversation: it joins the whole transcript into one big user prompt (`psTranscriptRelay`) and sends it as a single message.
  - Tool calling can't work that way, because providers require real assistant/tool turns.

### Shared structs (`AppSrc\ai.h`)
- `tAIResponse` → `tAIChoice[] Choices` → `tAIResponseContentPart[] ContentParts`.
- `tAIResponseContentPart` already has `sType` (comment: `"functionCall"`), `sFunctionName`, `sFunctionArgs` and `sFunctionContent`. No translator fills them in.
- **There is no tool call id field.** Claude, OpenAI and Grok all need one.
- `tAIChoice` keeps the raw `sFinishReason` (ChatGPT/Gemini) and `sStopReason` (Claude). There is no normalized stop reason.

### Response translation (`AppSrc\cAIResponseTranslator.pkg`)
- `cChatGPTTranslator`, `cClaudeTranslator`, `cGrokTranslator` (an empty subclass of `cClaudeTranslator`) and `cGeminiTranslator` each have a `TranslateToUnified` that maps a provider struct to `tAIResponse`.
- Each `MakeRequest` follows the same steps:
  1. Calls `JsonToDataType` on the response into a provider struct.
  2. Calls `Send Destroy of hoResponse`.
  3. Translates.
- **Tool data is lost when the response is deserialized:**
  - `tClaudeResponseContent` (`claudeai.h`) has only `type` and `text`, so `tool_use` `id`, `name` and `input` are dropped.
  - `tChatGPTMessage` (`chatgptai.h`) has only `role` and `content` (both String), so `tool_calls` is dropped.
  - `tGeminiContentPart` (`geminiai.h`) has only `text`, so `functionCall` and `thoughtSignature` are dropped.
  - `cGeminiTranslator` hardcodes `sType` to `"text"` for every part.
- Tool arguments are arbitrary JSON objects (Claude `input`, Gemini `args`). A DataFlex struct can't hold an object of unknown shape. Tool calls must therefore be read **from the `cJsonObject` before it is destroyed**, using `Stringify` on the `input`/`args` member. They should not go through `JsonToDataType`.

### ChatGPT: `cChatGPTInterface` (`AppSrc\cChatGPTInterface.pkg`) and `cChatGPTRequest` (`AppSrc\cChatGPTRequest.pkg`)
- Endpoint: `POST api.openai.com/v1/chat/completions` (Chat Completions, **not** the Responses API).
  - Used in `MakeRequestJSON` and the older `CreateChatCompletion`.
- `CreateRequest` builds `tChatGPTMessage[]`. Attachments become extra user messages whose content is base64 text.
- `cChatGPTRequest.ConstructRequest` writes `model`, `max_tokens` and `messages[]`, with `content` always a string.
  - It can't produce an assistant message with `tool_calls`, a `role:"tool"` message, or a null/array `content`.
- `MakeRequestJSON` calls `RemoveNullMembers`. This is fine, but note it: an assistant message with tool calls has `content: null`.
- Side note: `ModelList` writes the raw model list JSON to the clipboard (`Direct_Output "CLIPBOARD:"`). It looks like leftover debug code.

### Claude: `cClaudeInterface` (`AppSrc\cClaudeInterface.pkg`) and `cClaudeRequest` (`AppSrc\cClaudeRequest.pkg`)
- Endpoint: `POST api.anthropic.com/v1/messages`, with headers from `AddStandardHeaders` (`x-api-key`, `anthropic-version` = `psAnthropicVersion`, and the optional files beta).
- `cClaudeRequest.CreateClaudeApiRequest` builds `model`, `max_tokens` and **one** user message. The content array holds text, document and image blocks.
  - It has no `system`, `tools`, `tool_choice` or multi-message support.
- `CreateClaudeApiRequest` reads `psModelId`/`piMaxTokens` from the parent object through `Register_Function`. It is declared `Function` but ends with `End_Procedure`, so tidy that up while editing.

### Grok: `cGrokInterface` (`AppSrc\cGrokInterface.pkg`), `grokai.pkg` and `grokai.h`
- It reuses the Claude request builder: `Object oGrokRequest is a cClaudeRequest`, which posts Anthropic-format JSON to **`api.x.ai/v1/messages`** with a Bearer token. The translator is `cGrokTranslator` (Claude format).
- `CreateRequest` takes `tClaudeAttachment[]` instead of `tAIAttachment[]`, which differs from the base signature.
- **xAI now marks `/v1/messages` (Anthropic compatibility) as "fully deprecated"** and tells clients to move to the Responses API (`/v1/responses`) or gRPC.
  - Sources: xAI docs, *Legacy & Deprecated*, plus a third-party compatibility check from Sept 2026.
  - That check also found tools/`tool_use`/`tool_result` still work on `/v1/messages`, but `disable_parallel_tool_use` is rejected and PDFs/documents are not supported.
  - xAI's function-calling guide also documents the OpenAI-compatible `/v1/chat/completions` and `/v1/responses` with OpenAI-style `tools`.
- **Decision D1:** move `cGrokInterface` to `/v1/chat/completions` as part of this work, and share the ChatGPT (OpenAI format) request builder and translator.
- `MakeRequestJSON` is the only place that calls `SetTimeout 45` (from `cdtJsonHttpTransfer`).

### Gemini: `cGeminiInterface` (`AppSrc\cGeminiInterface.pkg`) and `cGeminiRequest` (`AppSrc\cGeminiRequest.pkg`)
- Endpoint: `POST generativelanguage.googleapis.com/v1beta/{psModelId}:generateContent?key=...`. The key goes in the query string, and `psModelId` defaults to `models/gemini-2.5-flash`.
- `cGeminiRequest.CreateGeminiApiJsonRequest String sModelId tGeminiPart[] aParts tGenerationConfig tGenConfig` already has `functionCall` and `functionResponse` branches, **but they don't match the current API**:
  - `functionCall.args` is sent as a **string** (`jsonTypeString`). The API expects a JSON **object**.
  - `functionResponse` sends `"content": "<string>"`. The API needs `"response": { ...object... }`, plus `id` when the call had one.
  - **Each `tGeminiPart` becomes its own `contents[]` entry** (one part per content), so a turn can't hold several parts. Parallel calls need one `model` content with N `functionCall` parts, followed by one `user` content with N `functionResponse` parts.
  - It has no `tools`, `toolConfig` or `systemInstruction`.
  - The function is declared `Returns String` but returns a `cJsonObject` handle.
- `tGeminiPart` (`geminiai.h`) already carries `sFunctionName`, `sFunctionArgs` and `sFunctionContent`. Extend it rather than replace it.
- Note: Google's newest docs lead with a new *Interactions API*. `generateContent` is still the documented `v1beta` method, and DTAI should stay on it for now.

### HTTP and errors (`AppSrc\cdtJsonHttpTransfer.pkg`)
- All calls are synchronous: `HttpPostJson`/`HttpVerbJson` from `cJsonHttpTransfer`. There is **no streaming support**.
- `SetTimeout` adjusts the WinINet receive timeout. A tool loop makes several calls in a row, so total wait time grows.
- Every `MakeRequestJSON` shows UI on error (`UserError`, `Stop_Box`, `Info_Box`) and returns 0. The README TODO already lists "Remove UI code from interface libraries".
  - A tool loop running in a batch process or a WebApp needs an error that is set in a property instead of a modal box.

### Example views
- `AIDemo.vw` and `AIChatExample.vw` call `CreateRequest` then `MakeRequest` through a provider handle (`ghoChatGPTAI`, `ghoClaudeAI`, `ghoGeminiAI`, `ghoGrokAI`), picked by a radio group.
- The new test view should copy that pattern.

---

## Proposed Common Design

### Design principles
- **The app owns the tools.** The library only sends definitions the app registered, and only dispatches calls to app code that was registered.
- **Neutral in, neutral out.** Apps see only `tAITool*` structs and the `cAiInterface` methods. Each provider converts to and from its own JSON.
- **Keep provider JSON for replay.** Store each assistant turn's raw provider JSON next to its neutral form and send it back unchanged in the next request. This keeps fields DTAI doesn't model, such as Gemini `thoughtSignature`, Claude `thinking` blocks and future additions. The neutral form is used when the history is replayed to a *different* provider.
- **No breaking changes.** `CreateRequest` and `MakeRequest` keep working as they do now. Tool support is added through new methods.
- **Compiles on 19.1 and 25.0.** Only language and class features available in DataFlex 19.1 are used. Where encodings differ, small `#IF (!@>191)` blocks are used, as `cdtJsonHttpTransfer.DataReceived` already does. See "DataFlex 19.1 Compatibility".

### New structs (`AppSrc\ai.h`)

```dataflex
// Normalized stop reasons
Define AI_STOP_UNKNOWN        for 0
Define AI_STOP_END_TURN       for 1   // normal final answer (stop / end_turn / STOP)
Define AI_STOP_TOOL_CALLS     for 2   // model wants tools run (tool_calls / tool_use / functionCall parts)
Define AI_STOP_MAX_TOKENS     for 3   // length / max_tokens / MAX_TOKENS
Define AI_STOP_CONTENT_FILTER for 4   // content_filter / refusal / SAFETY etc.
Define AI_STOP_ERROR          for 5   // transport or API error

// Tool choice
Define AI_TOOLCHOICE_AUTO     for 0   // model decides (default)
Define AI_TOOLCHOICE_NONE     for 1   // tools sent but must not be called
Define AI_TOOLCHOICE_REQUIRED for 2   // must call at least one tool
Define AI_TOOLCHOICE_SPECIFIC for 3   // must call psToolChoiceName

Struct tAIToolDefinition
    String  sName            // ^[a-zA-Z0-9_-]{1,64}$ (strictest common rule, OpenAI 64)
    String  sDescription     // required by xAI, strongly recommended everywhere
    String  sParametersJson  // JSON Schema, root must be {"type":"object",...}
    Boolean bStrict          // OpenAI/Claude strict schema mode (ignored elsewhere)
End_Struct

Struct tAIToolCall
    String  sId              // provider call id; Gemini: id if returned, else generated "gemini-call-<n>"
    String  sName
    String  sArgumentsJson   // ALWAYS a JSON object string, normalized ("{}" when empty); see 19.1 note
    Integer iIndex           // order within the assistant turn
    String  sProviderData    // opaque per-provider extras (e.g. Gemini thoughtSignature)
End_Struct

Struct tAIToolResult
    String  sCallId          // = tAIToolCall.sId
    String  sName            // = tAIToolCall.sName (Gemini needs it)
    String  sContent         // text or JSON text returned by the app
    Boolean bIsError         // tool failed; content holds the error message
End_Struct

// One conversation turn, provider neutral
Struct tAIMessage
    String          sRole          // "user" | "assistant" | "tool"
    String          sText          // text for user/assistant turns
    tAIAttachment[] Attachments    // user turns only
    tAIToolCall[]   ToolCalls      // assistant turns that requested tools
    tAIToolResult[] ToolResults    // "tool" turn: results for the previous assistant turn
    String          sProvider      // "claude" | "chatgpt" | "grok" | "gemini" (who produced it)
    UChar[]         ucProviderJson // raw provider message JSON, UTF-8 (StringifyUtf8), for exact replay
    String          sSpeaker       // AI-to-AI: who said it (relayed turns)
    Boolean         bRelayed       // True when the turn was relayed from another AI
End_Struct

// Shared transcript entry (display/logging only, never sent to a model)
Struct tAITranscriptEntry
    String   sSpeaker
    String   sRole
    String   sText
    DateTime dtWhen
End_Struct
```

Additions to existing structs (all backward compatible):
- `tAIResponseContentPart`: add `String sToolCallId`. For tool calls, set `sType = "tool_call"` and fill `sToolCallId`, `sFunctionName` and `sFunctionArgs`.
- `tAIResponse`:
  - Add `Integer eStopReason` (`AI_STOP_*`).
  - Add `tAIToolCall[] ToolCalls`, a flat list for choice 0 so apps don't have to walk content parts.
  - Add `String sText`, the joined text of choice 0's text parts, for convenience.
  - Add `Integer iToolIterations`, the number of round trips the loop used.
  - Add `tAIToolCall[] PendingConfirmations`: calls held back until the app approves them (see "Tool confirmation").

The new `AI_STOP_*` list gains one value:

```dataflex
Define AI_STOP_CONFIRMATION   for 6   // loop paused: calls need the app/user to approve them
```

`sProviderJson` from revision 1 is now `ucProviderJson` (UTF-8 `UChar[]`). On 19.1, a `String` holds OEM text and is capped by the argument size, so a `String` copy of the raw JSON could alter characters. Changed characters would break Claude `thinking` replay, whose signature must match the original text. `StringifyUtf8`/`ParseUtf8` exist in 19.0 and later and keep the bytes exactly.

### Tool registry and choice (`cAiInterface`, `AppSrc\ai.pkg`)

```dataflex
Property tAIToolDefinition[] paTools
Property Integer peToolChoice        AI_TOOLCHOICE_AUTO
Property String  psToolChoiceName    ''
Property Boolean pbParallelToolCalls True
Property Integer piMaxToolIterations 8
Property Boolean pbAutoExecuteTools  True   // False = manual mode
Property Handle  phoToolSet          0      // optional cAIToolSet object
Property String  psSystemPrompt      ''     // needed by most tool apps; maps to system/systemInstruction
Property Handle  phoConversation      0      // attached cAIConversation (0 = use the internal default)
Property Handle  phoDefaultConversation      // internal default cAIConversation (child object)
Function paPendingConfirmations Returns tAIToolCall[] // read-only: the active conversation's pending calls (rev 6)

Procedure AddTool String sName String sDescription String sParametersJson Boolean bRequiresConfirmation  // validates name + JSON; last param optional (num_arguments)
Procedure RemoveTool String sName
Procedure ClearTools
Function  ToolIndex String sName Returns Integer                           // -1 if not registered
Procedure SetToolChoice Integer eChoice String sToolName                   // sToolName only for SPECIFIC
Function  ActiveConversation Returns Handle                                // phoConversation, or the default
Procedure ClearConversation
Procedure AddUserMessage String sText
Procedure AddUserMessageWithAttachments String sText tAIAttachment[] Attachments
Procedure AddToolResults tAIToolResult[] Results                           // manual mode
Function  ConversationMessages Returns tAIMessage[]                       // replay form for this provider
Procedure SetConversationMessages tAIMessage[] Messages
Function  EffectiveSystemPrompt Returns String                            // conversation prompt overrides psSystemPrompt
```

### Silent errors (decision D4)
This applies to the whole library, not only to tool calls. It is added to `cAiInterface` and used by all four `MakeRequestJSON` overrides, the `ModelList` overrides, and the Claude Files API calls (`ClaudeFileList`, `UploadFile` and the others).

```dataflex
Property Boolean pbSilentErrors    False  // default keeps today's behavior (boxes)
Property String  psLastError       ''     // human-readable message of the last error
Property Integer piLastErrorNumber 0      // AI_ERR_* below
Property Integer piLastHttpStatus  0      // ResponseStatusCode when known
Property String  psLastErrorDetail ''     // provider error type/code, or the raw body excerpt

Define AI_ERR_NONE        for 0
Define AI_ERR_NO_API_KEY  for 1
Define AI_ERR_TRANSFER    for 2   // WinINet/transfer failure, timeout
Define AI_ERR_API         for 3   // provider returned an error object
Define AI_ERR_PARSE       for 4   // response not JSON / unexpected shape
Define AI_ERR_TOOL_LOOP   for 5   // loop limit, repeated call, etc.

Procedure ClearLastError
Function  HasError Returns Boolean
Procedure ReportAIError Integer iErr String sMessage String sDetail   // the single place errors go
Procedure OnAIError Integer iErr String sMessage                      // event for app logging
```

How it works:
- Every place that now calls `Send Stop_Box`, `Send UserError`, `Send Info_Box` or `Error DFERR_PROGRAM` for a provider or transfer problem calls `ReportAIError` instead.
- `ReportAIError` sets the properties and sends `OnAIError`. Only if `pbSilentErrors` is False does it show the box, exactly as today.
- `CheckApiKeyExists` uses `ReportAIError` with `AI_ERR_NO_API_KEY` rather than `Error DFERR_PROGRAM`.
- Each public call starts with `ClearLastError`.
- Callers test `HasError` (or a 0 handle, or `eStopReason = AI_STOP_ERROR`).
- Programming errors, such as an abstract method that isn't implemented, still raise `Error DFERR_PROGRAM`.

### Tool confirmation (decision D5)
- `cAITool` gets `Property Boolean pbRequiresConfirmation False`. `AddTool` takes it as an optional last parameter.
- Mark any tool that changes data or has outside effects (post, update, delete, email, print) as requiring confirmation.
- In the tool loop, before a call to such a tool is run, the base class asks:

```dataflex
// Return True to run, False to decline. Default implementation is below.
Function OnConfirmToolCall tAIToolCall Call Returns Integer   // AI_CONFIRM_YES | AI_CONFIRM_NO | AI_CONFIRM_DEFER

Define AI_CONFIRM_YES   for 1
Define AI_CONFIRM_NO    for 2
Define AI_CONFIRM_DEFER for 3   // pause the loop and hand the decision to the app
```

- **Default behavior:**
  - If `pbSilentErrors` is False (a Windows UI app), show a `YesNo_Box` with the tool name and a readable argument summary.
  - Otherwise return `AI_CONFIRM_DEFER`. WebApps and batch processes can't show a modal box.
- **Yes:** the tool runs normally.
- **No:** the tool isn't run. Its result is an error result, `"The user declined to run <tool>."`, and the loop continues so the model can respond.
- **Defer:** the loop stops and returns `eStopReason = AI_STOP_CONFIRMATION`, with the waiting calls in `Response.PendingConfirmations` and `paPendingConfirmations`.
  - Calls in the same turn that don't need confirmation have already run, and their results are held.
  - The app then calls `ApproveToolCall String sCallId` / `DeclineToolCall String sCallId String sReason` for each pending call, then `ContinueConversation`.
  - `ContinueConversation` runs the approved calls, adds the single `tool` turn with every result for that assistant turn, and resumes the loop.
- The provider rule that every tool call must get a result in the next turn is kept: declined calls always produce an error result.
- **Where the state lives (rev 6):** `paPendingConfirmations`, the held results and the approve/decline lists are properties of the `cAIConversation`, not the provider. `paPendingConfirmations` on the provider is a read-only function that returns the active conversation's list. Attach the conversation before calling `ApproveToolCall`/`DeclineToolCall`/`ContinueConversation`. `ClearMessages` also clears the state. A second conversation on the same provider object neither sees nor clears another conversation's pending calls.
- `OnBeforeToolCall` (veto) still exists for app-wide policy. Confirmation is the per-tool, user-facing step.

### Two ways for the app to implement tools

**A. Tool objects (recommended, DataFlex style).** New package `AppSrc\cAIToolSet.pkg`. A tool's definition and code sit together in one object:

```dataflex
Use cAIToolSet.pkg

Object oDemoTools is a cAIToolSet
    Object oGetWeather is a cAITool
        Set psName to "get_weather"
        Set psDescription to "Current weather for a city. Use when the user asks about weather."
        Set psParametersJson to '{"type":"object","properties":{"city":{"type":"string","description":"City name"},"unit":{"type":"string","enum":["celsius","fahrenheit"]}},"required":["city"]}'

        // hoArgs is a cJsonObject already parsed from the call's arguments (library destroys it)
        Function Execute Handle hoArgs tAIToolCall ToolCall Returns String
            String sCity
            Get MemberValue of hoArgs "city" to sCity
            Function_Return ('{"city":"'+sCity+'","temperature":59,"unit":"fahrenheit","conditions":"fog"}')
        End_Function
    End_Object
End_Object

Set phoToolSet of ghoClaudeAI to oDemoTools   // same tool set works on ghoChatGPTAI, ghoGeminiAI, ghoGrokAI
```

- `cAITool is a cObject`:
  - Properties: `psName`, `psDescription`, `psParametersJson`, `pbStrict`, `pbEnabled` and `pbRequiresConfirmation`.
  - `Function Execute Handle hoArgs tAIToolCall ToolCall Returns String` must be overridden.
  - `Procedure ToolError String sMessage` marks the result as an error.
- `cAIToolSet is a cObject`:
  - Each `cAITool` registers itself with its parent in `End_Construct_Object` (`Delegate Send RegisterAITool Self`). The set keeps a `Handle[]` of tools and builds `tAIToolDefinition[]` from it (`Function Definitions`). Self-registration avoids version-specific child-object enumeration and works the same on 19.1 and 25.0.
  - `Function ExecuteToolCall tAIToolCall Call Returns tAIToolResult` finds the tool by name and runs it.
- One tool set can be shared by several provider objects. Tools can be switched on or off per request with `pbEnabled`.

**B. Event override.** For apps that build tool lists on the fly (for example from a table):
- Call `AddTool` directly.
- Override the event on the provider object or a subclass:

```dataflex
// in cAiInterface, default implementation delegates to phoToolSet
Function OnToolCall tAIToolCall ToolCall Returns tAIToolResult
```

The default `OnToolCall` works like this:
- If `phoToolSet` is set, it calls `ExecuteToolCall of phoToolSet`.
- Otherwise it returns an error result: `"No handler for tool <name>"`.

The tools sent in a request are `paTools` plus the enabled tools in `phoToolSet`. Name collisions are reported as errors.

### Running a conversation: auto and manual mode

New high-level entry point on `cAiInterface`. This shared loop is written once in the base class:

```dataflex
// Adds the user turn to the active conversation, then loops:
//   BuildConversationRequest -> post -> ParseConversationResponse -> append assistant turn
//   if eStopReason = AI_STOP_TOOL_CALLS and pbAutoExecuteTools:
//        run every call (OnToolCall), append one "tool" turn with all results, repeat
//   stop on final answer, error, or piMaxToolIterations
Function Chat String sPrompt tAIAttachment[] Attachments Returns tAIResponse

// Manual mode / step: send the active conversation as-is (one round trip), append assistant turn, return.
Function ContinueConversation Returns tAIResponse
```

**Manual mode:** set `pbAutoExecuteTools` to False. `Chat` returns after the first response with `eStopReason = AI_STOP_TOOL_CALLS` and `Response.ToolCalls` filled in. The app can then:
- show or confirm the calls, then
- run them itself, then
- call `AddToolResults` and `ContinueConversation`.

This suits WebApps and calls that need user approval. Tools marked `pbRequiresConfirmation` pause the loop even in auto mode (see Tool confirmation).

**Events for logging and UI:**
- `Function OnBeforeToolCall tAIToolCall ToolCall Returns Boolean` can veto a call (return True). Implemented as a function rather than ByRef parameters.
- `OnAfterToolCall tAIToolCall Call tAIToolResult Result`.
- `OnToolLoopIteration Integer iIteration`.

`psModelRequestJson`/`psModelResponseJson` keep holding the **last** round trip. A new `paToolLoopLog` (String[] of request/response pairs) keeps every round trip, for the test view and for the README's "log requests" TODO.

### Conversation history storage (D3, resolved)

History lives in a **`cAIConversation`** object (`AppSrc\cAIConversation.pkg`), not in a property of the provider. The provider objects (`ghoClaudeAI` and the others) are global singletons, so storing history on them would make every view share one conversation.

```dataflex
Object oConv is a cAIConversation
    Set psSystemPrompt to "You are an order-desk assistant."   // optional; overrides the provider's
End_Object
...
Set phoConversation of ghoClaudeAI to oConv     // attach
Get Chat of ghoClaudeAI "Where is order 1234?" to Response
Set phoConversation of ghoClaudeAI to 0         // detach: back to the internal default
```

- **Attach or default.** `phoConversation` points at the conversation to use. When it is 0, the provider uses `phoDefaultConversation`, an internal `cAIConversation` child, so simple apps never need to create one. `ActiveConversation` returns whichever applies. Every history call (`ClearConversation`, `AddUserMessage`, `AddToolResults`, `ConversationMessages`, `SetConversationMessages`, and later `Chat`/`ContinueConversation`) works on the active conversation.
- **Per view or task.** Each view (or batch task) owns its own `cAIConversation` and attaches it before calling the provider. Switching views or tasks is just a different `Set phoConversation`, and conversations never leak into each other. A view can hold several conversations and switch between them (for example one per customer).
- **Neutral turns.** `paMessages` is a `tAIMessage[]`:

| Turn | `sRole` | Filled |
|---|---|---|
| user prompt | `user` | `sText`, `Attachments` |
| relayed turn from another AI | `user` | `sText` (optionally prefixed "Speaker: "), `sSpeaker`, `bRelayed` = True |
| model asks for tools | `assistant` | `sText` (may be empty), `ToolCalls[]`, `sProvider`, `ucProviderJson` |
| app returns results | `tool` | `ToolResults[]` (one per call, same order) |
| final answer | `assistant` | `sText`, `sProvider`, `ucProviderJson` |

- **Methods** (implemented in Phase 1): `ClearMessages`, `MessageCount`, `MessageAt`, `LastMessage`, `SetMessages`, `AddMessage`, `AddUserMessage`, `AddUserMessageWithAttachments`, `AddAssistantMessage`, `AddToolResults`, `AddRelayedMessage`, `RemoveLastMessage`, `LastAssistantText`, `HasUnansweredToolCalls`, `MessagesForProvider`. Properties: `psSystemPrompt`, `psUserLabel`, `psAssistantLabel`, `phoTranscript`.

Rules for each provider's builder:
- The builder gets `MessagesForProvider(sProvider)`. For turns produced by the **same** provider, `ucProviderJson` is kept and replayed (`ParseUtf8`), which keeps signatures and thinking blocks.
- For turns from a **different** provider, `MessagesForProvider` clears `ucProviderJson` and every `ToolCalls[].sProviderData` (thinking blocks, Gemini thought signatures). The builder rebuilds them from the neutral fields: text, tool calls and tool results carry over.
- **One `tool` turn holds all results for the preceding assistant turn.** Each provider then splits or merges as needed: OpenAI uses N `role:"tool"` messages, Claude uses one user message with N `tool_result` blocks, and Gemini uses one `user` content with N `functionResponse` parts.

**Moving a conversation between providers.** Attach the same `cAIConversation` to another provider and continue. Replay uses the neutral form, so text, tool calls and tool results move; provider-only extras are dropped as above. Tool call ids from one provider are passed through as-is (Gemini matches by name and order when an id isn't usable).

**AI-to-AI conversations.** Each participant gets **its own** conversation, because roles are mirrored (A's reply is a `user` turn for B) and provider extras aren't portable:

```dataflex
Object oClaudeSide is a cAIConversation
    Set psAssistantLabel to "Claude"
    Set phoTranscript to oTranscript
End_Object
Object oGrokSide is a cAIConversation
    Set psAssistantLabel to "Grok"
    Set phoTranscript to oTranscript
End_Object
Object oTranscript is a cAITranscript    // shared, for display/logging only
End_Object
...
// after Claude answers in oClaudeSide:
Send AddRelayedMessage of oGrokSide "Claude" sClaudeReply True   // True = prefix "Claude: "
```

- `AddRelayedMessage sSpeaker sText bPrefixLabel` adds a `user` turn marked `bRelayed`, with an optional "Speaker: " label so a model can tell several speakers apart.
- **Phase 3** adds a `cAIDialogue` helper (or a `RelayTurn` method) that runs the exchange: ask A, relay A's reply into B's conversation, ask B, relay back, for N turns or until a stop phrase. It needs `Chat`, so it belongs with the tool loop. Tool calls stay inside each participant's own conversation and are never relayed.
- **Shared transcript.** `cAITranscript` (`paEntries` of `tAITranscriptEntry`: speaker, role, text, time; `AddEntry`, `ClearEntries`, `EntryCount`, `AsMarkdown`) records who said what. Conversations with `phoTranscript` set write their user and assistant text turns to it, skipping relayed turns (so each utterance appears once) and tool turns. The transcript is **never sent to a model**.

**Later items:** saving conversations and transcripts to a table (audit and replay; `ucProviderJson` stored as binary), and trimming long histories to fit token limits.

Plain `CreateRequest`/`MakeRequest` stay single-turn for compatibility. `AIChatExample.vw` can later move to `Chat` and drop the transcript joining.

### Base class versus provider changes

| Where | Change |
|---|---|
| `ai.h` | New structs and constants; additions to `tAIResponseContentPart` and `tAIResponse`. |
| `ai.pkg` (`cAiInterface`) | Registry and choice properties, conversation, `Chat`/`ContinueConversation` loop, `OnToolCall` and the other events, tool confirmation (`OnConfirmToolCall`, `ApproveToolCall`, `DeclineToolCall`), error capture, and silent errors (`pbSilentErrors`, `ReportAIError`, `psLastError` and the related properties). Two new abstract functions per provider: `BuildConversationRequest tAIMessage[] Messages tAIToolDefinition[] Tools Returns Handle` and `ParseConversationResponse Handle hoResponse Returns tAIResponse` (fills `ToolCalls`, `eStopReason` and the new assistant `tAIMessage`, including `ucProviderJson`). Shared helpers: `NormalizeArgumentsJson`, `ValidateToolName`, `ParseJsonText`. |
| `cAIToolSet.pkg` (new) | `cAITool` (with `pbRequiresConfirmation`) and `cAIToolSet` (tools register themselves). |
| All four `*Interface.pkg` | Replace `Stop_Box`/`UserError`/`Info_Box` in `MakeRequestJSON`, `ModelList` and the file calls with `ReportAIError` (D4). |
| `cAIResponseTranslator.pkg` | Each translator maps the normalized stop reason. Tool calls come from the JSON handle (see above), so translators gain a `ParseToolCalls Handle hoResponse` helper each. |
| `cChatGPTRequest.pkg` | New `ConstructConversationRequest`: messages with `tool_calls`, `role:"tool"` messages, `tools`, `tool_choice` and `parallel_tool_calls`. `ConstructRequest` stays as it is. |
| `cChatGPTInterface.pkg` | Overrides `BuildConversationRequest` and `ParseConversationResponse`. |
| `cClaudeRequest.pkg` | New `CreateClaudeConversationRequest`: `system`, multi-message, `tool_use`/`tool_result` blocks, `tools` and `tool_choice`. |
| `cClaudeInterface.pkg` | Overrides the two functions. |
| `cGrokInterface.pkg` | Endpoint moves to `v1/chat/completions` (D1). `oGrokRequest` becomes a `cChatGPTRequest`, and the translator becomes an OpenAI-format translator. Fix the `CreateRequest` signature to `tAIAttachment[]`. |
| `cGeminiRequest.pkg` | Group parts into turns (`tGeminiContent` with `tGeminiPart[]`). Fix `functionCall.args` (object) and `functionResponse.response` (object, plus `id`). Add `tools.functionDeclarations`, `toolConfig` and `systemInstruction`. Fix the `Returns String` → `Returns Handle`. |
| `cGeminiInterface.pkg` | Overrides the two functions. |
| `geminiai.h` | Add `sFunctionCallId` and `sThoughtSignature` to `tGeminiPart`, and a new `tGeminiContent` (`sRole`, `tGeminiPart[] Parts`). |
| Views | New `AIToolCallTest.vw`, plus a menu entry in `ai.src`. |

---

## Per-Provider Mapping

The same example is used for every provider: tool `get_weather(city)`, a user asking "Weather in Paris and Oslo?" and two parallel calls.

### OpenAI ChatGPT: Chat Completions (`/v1/chat/completions`, the endpoint the class uses now)

Definitions and choice:
```json
{
  "model": "gpt-4.1-mini",
  "messages": [{"role":"system","content":"..."},{"role":"user","content":"Weather in Paris and Oslo?"}],
  "tools": [{"type":"function","function":{
      "name":"get_weather","description":"Current weather for a city",
      "parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]},
      "strict": false}}],
  "tool_choice": "auto",
  "parallel_tool_calls": true
}
```
`tool_choice` values: `"auto"`, `"none"`, `"required"`, or `{"type":"function","function":{"name":"get_weather"}}`.

Response with tool calls (`finish_reason: "tool_calls"`):
```json
{"choices":[{"index":0,"finish_reason":"tool_calls","message":{"role":"assistant","content":null,
  "tool_calls":[
    {"id":"call_abc","type":"function","function":{"name":"get_weather","arguments":"{\"city\":\"Paris\"}"}},
    {"id":"call_def","type":"function","function":{"name":"get_weather","arguments":"{\"city\":\"Oslo\"}"}}]}}]}
```
Sending results: replay the assistant message exactly as received, then add **one `tool` message per call**:
```json
{"role":"tool","tool_call_id":"call_abc","content":"{\"temperature\":12}"},
{"role":"tool","tool_call_id":"call_def","content":"{\"temperature\":3}"}
```

Quirks:
- `arguments` is a **JSON string**, not an object. Parse it with `ParseString` of a `cJsonObject`, and handle invalid JSON.
- `content` is `null` on tool-call turns. `RemoveNullMembers` drops it, so treat a missing value as "".
- There is no error flag on tool messages. Encode errors in the content, for example `{"error":"..."}`.
- `strict: true` needs `additionalProperties:false` and every property listed in `required`. Default it to off.
- Not in scope: reasoning models want `max_completion_tokens` instead of `max_tokens`. Note this for the request builder.

**Responses API (`/v1/responses`): later item (D2), not part of v1.** OpenAI recommends it for new work. Its shapes differ:
- Tools are flat: `{"type":"function","name","description","parameters"}`.
- Output items are `{"type":"function_call","call_id","name","arguments"}`.
- Results are input items `{"type":"function_call_output","call_id","output"}`.
- The conversation is either replayed in `input` or chained with `previous_response_id`.

xAI supports the same API. The neutral design covers it unchanged.

### Anthropic Claude: Messages (`/v1/messages`)

Definitions and choice:
```json
{
  "model": "claude-sonnet-4-20250514", "max_tokens": 8192,
  "system": "...",
  "tools": [{"name":"get_weather","description":"Current weather for a city",
             "input_schema":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}],
  "tool_choice": {"type":"auto", "disable_parallel_tool_use": false},
  "messages": [{"role":"user","content":[{"type":"text","text":"Weather in Paris and Oslo?"}]}]
}
```
`tool_choice` types: `auto`, `any` (required), `tool` plus `name` (specific), and `none`.

Response (`stop_reason: "tool_use"`):
```json
{"role":"assistant","stop_reason":"tool_use","content":[
  {"type":"text","text":"Let me check."},
  {"type":"tool_use","id":"toolu_01","name":"get_weather","input":{"city":"Paris"}},
  {"type":"tool_use","id":"toolu_02","name":"get_weather","input":{"city":"Oslo"}}]}
```
Sending results: replay the **entire** assistant `content` array. Then add **one `user` message** containing all results:
```json
{"role":"user","content":[
  {"type":"tool_result","tool_use_id":"toolu_01","content":"{\"temperature\":12}"},
  {"type":"tool_result","tool_use_id":"toolu_02","content":"Weather service unavailable","is_error":true}]}
```

Quirks:
- `tool_result` goes **inside a user message**, never in a separate role.
- `tool_result` blocks must come **first** in that content array. Any extra text goes after them.
- Every `tool_use` must get a matching result in the very next user message, or the API returns a 400 error.
- `input` is a JSON **object**: `Stringify` it.
- `is_error: true` is supported natively.
- When extended thinking is on, the `thinking` blocks must be sent back unchanged with the tool-use turn. Replaying `ucProviderJson` handles this.
- With manual extended thinking, `tool_choice` `any`/`tool` (forced) is not supported. Fall back to `auto` and report the change.
- `stop_reason: "max_tokens"` can cut off a `tool_use` block. Treat this as `AI_STOP_MAX_TOKENS`, not as tool calls.
- Tool names must match `^[a-zA-Z0-9_-]{1,128}$`. Optional `strict: true` gives schema-exact inputs on supported models.

### xAI Grok

**Target (D1): `/v1/chat/completions` (OpenAI-compatible).**
- Request and response JSON match the OpenAI Chat Completions section exactly: `tools[].function`, `tool_calls`, `role:"tool"` and `tool_call_id`.
- `tool_choice` supports `auto`, `required`, `none` or a specific function. `parallel_tool_calls` defaults to true.
- `cGrokInterface` can then reuse `cChatGPTRequest` and an OpenAI-format translator. Most of the Grok work is just switching the endpoint.

Quirks:
- `description` must be provided.
- The `parameters` root must be an object, or `anyOf`/`oneOf` of objects. Anything else returns a 400 error that names the tool.
- With streaming, a function call arrives whole in one chunk.
- Up to 350 tools are allowed on Chat Completions and 1000 on Responses.
- Grok models reason by default and can be slow, so keep `SetTimeout`.
- Grok accepts PDFs only by URL. That limitation is unchanged.

**For reference only, `/v1/messages` (deprecated, being removed from DTAI):**
- The Claude mapping above applies, with Bearer auth.
- `disable_parallel_tool_use` returns a 400 error, so never send it to Grok.
- Document blocks are rejected.
- DTAI no longer uses it after Phase 5.

### Google Gemini: `generateContent` (`v1beta`)

Definitions and choice:
```json
{
  "systemInstruction": {"parts":[{"text":"..."}]},
  "contents": [{"role":"user","parts":[{"text":"Weather in Paris and Oslo?"}]}],
  "tools": [{"functionDeclarations":[{
      "name":"get_weather","description":"Current weather for a city",
      "parametersJsonSchema":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}]}],
  "toolConfig": {"functionCallingConfig":{"mode":"AUTO"}}
}
```
- `mode` options: `AUTO`, `ANY` (required), `NONE` and `VALIDATED`.
- For a specific tool, use `mode: "ANY"` plus `"allowedFunctionNames":["get_weather"]`.
- Use **`parametersJsonSchema`**, which takes standard JSON Schema. Avoid `parameters`, which uses the older OpenAPI-subset `Schema`. The two can't be combined.

Response (`finishReason` is `STOP` even for function calls, so detect calls by the parts):
```json
{"candidates":[{"finishReason":"STOP","content":{"role":"model","parts":[
  {"functionCall":{"id":"fc_1","name":"get_weather","args":{"city":"Paris"}},"thoughtSignature":"Cq0..."},
  {"functionCall":{"id":"fc_2","name":"get_weather","args":{"city":"Oslo"}}}]}}]}
```
Sending results: replay the model content **exactly**, including `thoughtSignature`. Then add one `user` content with all responses:
```json
{"role":"user","parts":[
  {"functionResponse":{"id":"fc_1","name":"get_weather","response":{"result":{"temperature":12}}}},
  {"functionResponse":{"id":"fc_2","name":"get_weather","response":{"error":"Weather service unavailable"}}}]}
```

Quirks:
- `functionCall.id` is **optional**. When it's missing (older models), there is no call id: match results **by name and order**. The library makes a synthetic `sId` (`gemini-call-<n>`), keeps the original order, and leaves `id` out when replaying.
- `args` and `response` are **objects**. The tool's result string must be wrapped:
  - If it parses as a JSON object, send it as `{"result": <object>}`.
  - Otherwise send `{"result": "<text>"}`.
  - On error send `{"error": "<message>"}`. There is no `is_error` flag; the key name is the convention.
- `finishReason` doesn't flag tool calls. Set `AI_STOP_TOOL_CALLS` when any `functionCall` part exists.
- **Thought signatures:** Gemini 2.5/3 thinking models attach `thoughtSignature` to parts. Gemini 3 rejects (400) a function-calling turn whose signature isn't sent back. Exact replay of `ucProviderJson` keeps it. Neutral rebuilds keep it in `tAIToolCall.sProviderData`.
- Role names are `user`/`model`. Function responses go in `user` content (older docs used role `function`).
- Max name length is 128 characters, using `a-zA-Z0-9_-`.

### Normalized stop reason mapping

| Provider value | `eStopReason` |
|---|---|
| OpenAI/xAI `stop`; Claude `end_turn`, `stop_sequence`; Gemini `STOP` with no functionCall | `AI_STOP_END_TURN` |
| OpenAI/xAI `tool_calls` (and the legacy `function_call`); Claude `tool_use`; Gemini any `functionCall` part | `AI_STOP_TOOL_CALLS` |
| `length`; `max_tokens`; `MAX_TOKENS` | `AI_STOP_MAX_TOKENS` |
| `content_filter`; Claude `refusal`; Gemini `SAFETY`, `RECITATION`, `PROHIBITED_CONTENT`, `BLOCKLIST`, `SPII`, `MALFORMED_FUNCTION_CALL`* | `AI_STOP_CONTENT_FILTER` (*`MALFORMED_FUNCTION_CALL` → `AI_STOP_ERROR`) |
| Claude `pause_turn` (server tools, not used) | `AI_STOP_UNKNOWN` |

### Parallel calls, tool choice and streaming summary

| | OpenAI | Claude | Grok (chat/completions) | Gemini |
|---|---|---|---|---|
| Parallel by default | yes | yes | yes | yes |
| Disable parallel | `parallel_tool_calls:false` | `tool_choice.disable_parallel_tool_use:true` | `parallel_tool_calls:false` | no switch (instruct in prompt; `pbParallelToolCalls` ignored) |
| Required | `"required"` | `{"type":"any"}` | `"required"` | `mode:"ANY"` |
| Specific | `{"type":"function","function":{"name"}}` | `{"type":"tool","name"}` | same as OpenAI | `ANY` + `allowedFunctionNames` |
| None | `"none"` | `{"type":"none"}` | `"none"` | `mode:"NONE"` |
| Call id | yes | yes | yes | optional |
| Streaming args | arrive in fragments | arrive as `input_json_delta` fragments | one whole chunk | whole |

**Streaming is out of scope.** DTAI is synchronous (`cJsonHttpTransfer`). If streaming is added later, the parser must build up argument fragments per call index or id before the loop runs. The neutral `tAIToolCall` stays the same.

---

## Error Handling

| Case | Behavior |
|---|---|
| **Invalid JSON arguments** | `NormalizeArgumentsJson` tries `ParseString`. If it fails, the tool is **not** run. An error result is sent back (`bIsError`, content `"Invalid JSON arguments: <parser message>"`) so the model can retry. A blank argument becomes `{}`. |
| **Unknown tool** (name not registered or disabled) | Not run. Error result `"Unknown tool: <name>"`. Logged. |
| **Missing required arguments / wrong types** | Optional `ValidateArguments`: a light check of `required` keys and top-level `type`s against `sParametersJson`. Failures go back as error results. Tools must still check their own inputs (see Security). |
| **Tool raises a DataFlex error** | During `OnToolCall`, the loop swaps in a capturing error handler (an object whose `Error_Report` records `iErrNum`/`sErrText` into `psLastToolError` instead of showing a box) and restores the original afterwards. If an error was captured, the result is `bIsError` with that text. A tool can also call `ToolError "msg"` on purpose. |
| **Tool takes too long** | Synchronous, so the tool is responsible. Document it. The HTTP timeout (`SetTimeout`) applies only to model calls. |
| **Loop limit** | After `piMaxToolIterations` round trips that still end in `AI_STOP_TOOL_CALLS`, stop. Return the last response with `eStopReason = AI_STOP_TOOL_CALLS` and set `psLastError = "Tool loop limit reached"`. Optional `pbFinalAnswerOnLimit`: send one last request with `tool_choice` none so the model sums up. |
| **Repeated identical calls** | Track name plus arguments. If the same call repeats three times, stop early with the same error as the loop limit. |
| **HTTP/API error mid-loop** | The response has `eStopReason = AI_STOP_ERROR` and `psLastError` is set. The active conversation is kept up to the last good turn so the app can retry with `ContinueConversation`. When `pbSilentErrors` is True, no `Stop_Box`/`UserError` appears and `psLastError`/`piLastErrorNumber`/`piLastHttpStatus` are set (D4). |
| **Tool declined by the user** | Not run. The error result `"The user declined to run <tool>."` is sent so the model can adjust (D5). |
| **Confirmation deferred** | The loop returns `AI_STOP_CONFIRMATION`. The conversation is kept, and nothing is sent to the provider until the app approves or declines every pending call. |
| **max_tokens during a tool call** | `AI_STOP_MAX_TOKENS`. The partial tool calls are **not** run. |
| **Result too large** | `piMaxToolResultLength` (default 100 000 characters) trims the result and adds a "…[truncated]" note to protect context size. |

---

## Security
- **Allow-list only.** Only tools the app registered are sent, and only registered names are dispatched. The model can't name its way into anything else. There is no "eval", and no dynamic `Send`/`Get` by message name built from model output.
- **Treat arguments as untrusted input**, like a web form:
  - Check types, ranges and lengths in `Execute`.
  - Never build SQL, file paths or `Runprogram` command lines from raw arguments.
  - Use DataFlex finds/constraints or parameterized SQL.
- **Least privilege.** Tools should be read-only unless the app has a reason. For tools with side effects (post, update, delete, email), use:
  - manual mode, or
  - `OnBeforeToolCall` with `bCancel` to require user confirmation.
  - `pbRequiresConfirmation` on `cAITool` makes this declarative (D5, in v1).
- **Data exposure.** Whatever a tool returns is sent to the AI provider. Return only the fields needed; don't return whole records with sensitive columns.
- **Prompt injection.** Tool results (documents, emails, DocuPipe output) may contain instructions. Keep tool outputs as data. Don't let a tool result switch on more tools or raise permissions.
- **Logging.** `paToolLoopLog` may contain business data. It must never contain API keys: headers are not logged, and the Gemini key in the URL query must be left out of any logged URL.
- **Limits.** Enforce `piMaxToolIterations`, the result size cap and the repeated-call stop, so a confused model can't run up cost.

---

## DataFlex 19.1 Compatibility (decision D6)

**Summary: there is no blocker to supporting 19.1.** All the core building blocks exist in 19.0/19.1, and the existing code already targets 19.1 in places (`#IF (!@>191)` in `cdtJsonHttpTransfer.DataReceived`, and `Set_Argument_Size` in `cBase64Attachment_mixin.CreateAttachment`). Two real limits need design care, both caused by 19.1 strings: **character encoding** and **string size**. Neither stops the feature.

### Checked and OK on 19.1
| Feature the plan uses | 19.1 status |
|---|---|
| `cJsonObject` (`ParseString`, `Stringify`, `ParseUtf8`, `StringifyUtf8`, `JsonToDataType`, `DataTypeToJson`, `pbRequireAllMembers`, `peWhiteSpace`) and `cJsonHttpTransfer` | **Available from 19.0** (DataFlex 2017), the release that introduced the JSON parser and JSON transfer class. |
| Structs with struct-array and `UChar[]` members, struct arrays as properties (`Property tAIToolDefinition[] paTools`), functions returning structs, `ByRef` parameters | Available well before 19.0. The library already uses them (`Property tAIModel[] paModels`, `tAIResponse`). |
| `Define ... for` constants, `RefClass`, `Create`, `Delegate`, `num_arguments` (optional params) | Available. |
| Error capture through `Error_Object_Id` and a custom `Error_Report` | Long-standing runtime mechanism; works the same in 19.1 and 25.0. |
| WinINet timeout (`SetTimeout`), headers, `HttpPostJson` | Already used in the 19.1-compatible code. |
| `YesNo_Box` for the confirmation prompt | Available. |

### Concerns and how the design handles them
1. **Encoding: strings are OEM on 19.1, UTF-8 on 20.0+. (Moderate: real but contained.)**
   - Before DataFlex 2021 (20.0), DataFlex strings are OEM, not Unicode. `ParseString`/`Stringify` and `MemberValue`/`SetMemberValue` convert between the parser's internal UTF-8 and OEM.
   - Characters outside the OEM code page (curly quotes, "→", "€" on some code pages, emoji, CJK) become `?` or another wrong character in any `String`.
   - **Effect on tools:**
     - Model text and tool arguments read into `String`s can lose such characters on 19.1. This already happens today with `Response...sText`.
     - Raw replay would be corrupted if it went through a `String`.
   - **Design changes made:**
     - The history keeps raw provider JSON as UTF-8 `UChar[]` (`ucProviderJson`, via `StringifyUtf8`/`ParseUtf8`), so replay is byte-exact on both versions.
     - Tools get `hoArgs` parsed directly from the response JSON (no `String` round trip).
     - `sArgumentsJson` is for display and logging only.
   - **Remaining limits on 19.1 (documented, not fixed):**
     - App code reading values with `MemberValue` gets OEM strings.
     - Tool results built as `String`s can only hold OEM characters.
     - For English and Western European business data this is acceptable. Asian-language or emoji content requires 20.0+.
   - Where an OEM/ANSI conversion is needed (for example showing text in Windows controls), use `#IF (!@>191)` blocks. `ToOEM`/`ToANSI` exist on 19.1; on 20+ they are replaced by `Utf8ToOem`/`Utf8ToAnsi`.
2. **String size: limited by the argument size on 19.1. (Moderate.)**
   - A 19.1 `String` is capped by the maximum argument size. The library already raises it with `Set_Argument_Size` when base64-encoding attachments.
   - A multi-turn tool conversation, especially one with a PDF attachment, can produce request JSON much larger than a single prompt. These spots are affected:
     - `psModelRequestJson`/`psModelResponseJson` (`Stringify` of the whole request);
     - `paToolLoopLog`;
     - `Stringify` of large tool `input`/`args` objects.
   - **Design changes made:**
     - The HTTP body is already sent from the `cJsonObject` (no `String` needed).
     - History replay uses `UChar[]`.
     - On 19.1 the debug and log copies (`psModelRequestJson`, `paToolLoopLog`) are filled using `StringifyUtf8` into `UChar[]`, or truncated when bigger than a set limit (`piMaxLogLength`).
     - The tool result size cap (`piMaxToolResultLength`) also keeps `String` results small.
     - `Chat` raises the argument size around its work on 19.1 and restores it afterwards, using the same pattern as `CreateAttachment`.
3. **Child-object enumeration for `cAIToolSet`. (Minor.)** Revision 1 assumed the tool set walks its child objects. It now uses self-registration (`Delegate Send RegisterAITool Self` in `cAITool.End_Construct_Object`). This is plain DataFlex and works the same on every version.
4. **Features to avoid (20.0+ only).** Don't use these in library code:
   - `WString`, `SizeOfString`, `Utf8ToOem`/`OemToUtf8`/`Utf8ToAnsi`/`AnsiToUtf8` (outside `#IF` blocks);
   - 64-bit-only types or behavior;
   - any class or property added after 19.1. Check the class reference "available since" notes when in doubt.
5. **Existing code to verify on a 19.1 compile.** Not part of the plan, but the first 19.1 build may show it:
   - The headers use the `{ Name="object" }` struct-member meta-data tag (`claudeai.h`, `grokai.h`, `chatgptai.h`). I could not confirm from the docs which release added it.
   - New tool structs don't use it, so it doesn't affect this plan.
   - If 19.1 rejects it, those few members need renaming or manual parsing.

**Recommendation:** keep a 19.1 Studio workspace or a command-line compile next to the 25.0 one, and compile both at the end of every phase (added to the checklist).

## Test Plan

### 1. Offline parser tests (no network, no credits)
Add a small test procedure set, run from a button in the test view or a `TestToolCalls` routine. It feeds **saved response JSON fixtures** to each provider's `ParseConversationResponse` and checks:
- the tool call count, ids, names and normalized `sArgumentsJson`;
- `eStopReason`;
- text plus tool calls in one turn (Claude);
- OpenAI `arguments` with escaped quotes and unicode;
- Gemini with and without `functionCall.id`, and with `thoughtSignature` kept;
- invalid JSON arguments giving an error result.

It also builds requests from a fixed `cAIConversation` and compares them to expected JSON for each provider: tool turns, result placement, and Gemini grouping.

Fixtures go in `AppSrc\Tests\ToolCallFixtures\*.json`, captured from real calls in phase 7.

**Implemented so far:** `AppSrc\DTAIOfflineTests.src`, a console-style program with no UI and no network. It writes `PASS`/`FAIL` lines and a `TOTAL` line to `DTAIOfflineTests.txt` in the workspace Data folder, then exits. It covers stop reason mapping, `AIFinalizeResponse`, tool name and schema validation, the registry and tool set, `ExecuteToolCall` error paths, conversation isolation (default versus attached, two providers), relay and transcript, provider switching dropping extras, silent errors, and the Gemini request builder. `AppSrc\DTAILibCompileCheck.src` compiles the library alone (no views), which is how the 19.1 build is checked.

### 2. Live test view: `AppSrc\AIToolCallTest.vw` ("View > AI Tool Call Test" in `ai.src`)
- A provider radio group (ChatGPT/Claude/Gemini/Grok) like `AIChatExample.vw`, a prompt box and a Run button.
- Check boxes: auto-execute, parallel calls and max iterations.
- A tool-choice combo: auto/none/required/specific.
- Output grid: one row per round trip and tool call (iteration, tool, arguments, result, error, elapsed time). It also shows the final answer, the request/response JSON for each round trip (from `paToolLoopLog`) and token usage.
- Demo tool set `oDemoTools`:

| Tool | Purpose |
|---|---|
| `get_weather(city, unit?)` | Fixed fake data. Tests parallel calls. |
| `calculate(a, b, operation enum add/subtract/multiply/divide)` | Deterministic, easy to check, and divide-by-zero gives a tool error. |
| `lookup_customer(customer_id)` | Searches an in-memory array. Shows a business-data lookup and the unknown-id error path. |
| `always_fails()` | Raises a DataFlex error. Tests error capture. |
| `post_note(text)` | `pbRequiresConfirmation` True. Appends to an in-memory list. Tests confirmation (approve, decline, defer). |

Scenarios, run against **every provider**:

| # | Prompt / setting | Expected |
|---|---|---|
| 1 | "What is 1234 * 5678?" | One `calculate` call, then the final answer 7006652 |
| 2 | "Weather in Paris and Oslo?" | Two parallel `get_weather` calls in one turn (Gemini/Claude/OpenAI/Grok), one round trip for results |
| 3 | "Weather in Paris in celsius, then add 10 to the temperature" | Calls in sequence: `get_weather` → `calculate` (2+ iterations) |
| 4 | "Say hello" | No tool calls, `AI_STOP_END_TURN` |
| 5 | Tool choice = specific `calculate`, prompt "Hi" | Forced `calculate` call |
| 6 | Tool choice = none | No calls, even when the prompt asks for weather |
| 7 | "Divide 5 by 0" | The tool error goes back (`is_error` / `{"error":...}`), and the model explains it |
| 8 | "Call always_fails" | The DataFlex error is captured with no error popup, and the loop continues |
| 9 | Max iterations = 1 with scenario 3 | Stops with "Tool loop limit reached" |
| 10 | Manual mode with scenario 2 | `Chat` returns tool calls, the test view runs them through a "Run tools" button, then `ContinueConversation` gives the final answer |
| 11 | Parallel off with scenario 2 | OpenAI/Claude/Grok make one call per turn; Gemini is noted as unsupported |
| 12 | Unknown tool (unregister `get_weather` after it is sent, via the `OnBeforeToolCall` test hook) | "Unknown tool" error result |
| 13 | New tool `post_note(text)` with `pbRequiresConfirmation`; answer **Yes** | The tool runs after the prompt, and the final answer confirms it |
| 14 | Same, answer **No** | The tool isn't run; the declined error result goes back and the model says it didn't post |
| 15 | Same with `pbSilentErrors` True (defer) | `Chat` returns `AI_STOP_CONFIRMATION` with one pending call; `ApproveToolCall` + `ContinueConversation` finishes |
| 16 | Parallel: `get_weather` + `post_note` in one turn, defer | `get_weather` runs at once and its result is held; one `tool` turn with both results is sent after approval |
| 17 | `pbSilentErrors` True with a wrong model id (forces an API error) | No popup; `HasError`, `piLastErrorNumber = AI_ERR_API`, `psLastError` and `piLastHttpStatus` are set |
| 18 | Per-view isolation: two test views (or two `cAIConversation` objects in one view) on the same provider, alternating prompts | Each conversation only contains its own turns; detaching falls back to the default conversation, which is untouched |
| 19 | Switch provider mid-conversation: start on Claude with a tool call, attach the same conversation to Gemini, ask a follow-up | Gemini answers with the earlier context; Claude-only extras are dropped without errors |
| 20 | AI-to-AI: Claude and Grok, own conversations, `cAIDialogue` for 3 exchanges with speaker labels | Each side sees the other's replies as user turns; the shared transcript lists 6 turns in order with speakers; no transcript text is sent to either model |
| 21 | AI-to-AI where one side uses a tool (`calculate`) | The tool call and result stay in that side's conversation; only the final text is relayed |

Record the results per provider in this document (a matrix of pass/fail and notes) before merging.

### 3. Regression
Run every test (offline and live) from a **19.1 build and a 25.0 build** of the test workspace (D6). Include a prompt and a tool result with accented characters (for example "Zürich", "Café") and one with characters outside the code page (for example "→" or "東京") to document the 19.1 behavior.

With `pbSilentErrors` False, error boxes must look the same as today. `AIDemo.vw` and `AIChatExample.vw` (single-turn `CreateRequest`/`MakeRequest`) must work as before on all four providers. Grok needs special attention if its endpoint changes.

---

## Implementation Phases and Checklist

Every phase ends with: **compile on DataFlex 19.1 and 25.0** (D6), then run the regression views.

### Phase 0: Prep
- [x] Answer the first round of open questions (D1 to D6).
- [x] Set up a 19.1 compile of the DTAI test workspace next to 25.0. Do a baseline compile of the current code on 19.1 and fix any existing issues.
  - Baseline: 25.0 `ai.src` 0 errors / 3 warnings (the existing obsolete `Get/Set_Argument_Size` warnings).
  - The `{ Name="object" }` struct tags compile fine on 19.1.
  - **Fixed a real 19.1 bug:** `cdtJsonHttpTransfer.SetTimeout` called `WinAPI_InternetQueryOption`/`WinAPI_InternetSetOption`, which only exist in 25.0's `cHttpTransfer.pkg`. It now calls its own `InternetQueryOption` declaration and `InternetSetOption`.
  - The full `ai.src` demo app does **not** compile on 19.1 for reasons outside the library: UTF-8 BOMs in `ai.src`, `AIDemo.vw` and `LocalResourceManager.wo`, and 20.0+ classes in the views (`cWebView2Browser`, `cLocalWebControlHost`). Only the library has to compile on 19.1, so `DTAILibCompileCheck.src` (library only) is the 19.1 check.
- [x] Fix the existing Gemini request bugs: `args` and `response` as objects, `Returns Handle`, and grouping parts by turn. (`functionResponse` is `{"result":<object or text>}`.)
- [x] Remove the clipboard debug write in `cChatGPTInterface.ModelList`.

### Phase 1: Neutral types, silent errors and base API (done)
- [x] `ai.h`:
  - `tAIToolDefinition`, `tAIToolCall`, `tAIToolResult`, `tAIMessage` (with `ucProviderJson`);
  - the `AI_STOP_*` constants (including `AI_STOP_CONFIRMATION`), `AI_TOOLCHOICE_*`, `AI_ERR_*` and `AI_CONFIRM_*`;
  - the new fields on `tAIResponseContentPart`/`tAIResponse`.
- [x] Silent errors (D4):
  - `pbSilentErrors`, `psLastError`, `piLastErrorNumber`, `piLastHttpStatus`, `psLastErrorDetail`, `ClearLastError`, `HasError`, `ReportAIError` and `OnAIError` in `cAiInterface`;
  - convert `CheckApiKeyExists`, and every `MakeRequestJSON`/`ModelList`/Claude file call in the four interface classes, to `ReportAIError`;
  - confirm the default behavior is unchanged.
- [x] `ai.pkg`:
  - the registry (`AddTool` with the optional confirmation flag, `RemoveTool`, `ClearTools`, `ToolIndex`, `SetToolChoice`);
  - `psSystemPrompt`;
  - the abstract `BuildConversationRequest`/`ParseConversationResponse`.
- [x] Conversation history (D3): new `cAIConversation.pkg` (`cAIConversation` and `cAITranscript`), `phoConversation`/`phoDefaultConversation` on `cAiInterface`, and the provider methods `ActiveConversation`, `ClearConversation`, `AddUserMessage`, `AddUserMessageWithAttachments`, `AddToolResults`, `ConversationMessages`/`SetConversationMessages` and `EffectiveSystemPrompt`. `AddRelayedMessage` for AI-to-AI. `tAIMessage` gains `sSpeaker` and `bRelayed`; new `tAITranscriptEntry`.
- [x] New `cAIToolSet.pkg`: `cAITool` (`pbRequiresConfirmation`, self-registration) and `cAIToolSet`.
- [x] Shared helpers: `NormalizeJsonObjectText` and `ValidToolName` (in `ai.pkg`), global `AIStopReasonFromProvider` and `AIFinalizeResponse` (in `cAIResponseTranslator.pkg`; every translator now fills `eStopReason` and `sText`).
- [ ] Moved to Phase 3: the error-capture handler (it wraps tool execution in the loop) and 19.1 argument-size handling for large tool results.
- [x] Offline tests `DTAIOfflineTests.src` and the library compile check `DTAILibCompileCheck.src`. Both compile with 0 errors on 25.0 and 19.1, and the tests pass on both.

### Phase 2: Claude (reference implementation; closest to the neutral model) (done, offline-tested)
- [x] `cClaudeRequest.CreateClaudeConversationRequest Messages Tools sSystem eToolChoice sToolChoiceName bParallel`:
  - `system` (omitted when blank), `tools` with `input_schema` (a blank schema becomes `{"type":"object","properties":{}}`; `strict` only when set);
  - `tool_choice` only when it differs from the default: `none`, `any` (required), `tool` + `name` (specific), plus `disable_parallel_tool_use` when parallel calls are off;
  - user turns: text plus attachments (images, PDFs, text; file ids use `"source":{"type":"file"}`);
  - assistant turns: the raw Claude message is replayed when present (keeps `thinking` blocks and signatures), otherwise text plus `tool_use` blocks with `input` as an object;
  - tool turns: one `user` message with every `tool_result` (`is_error` when set; empty content omitted).
  - The old single-turn `CreateClaudeApiRequest` is unchanged.
- [x] `cClaudeInterface.BuildConversationRequest` and `ParseConversationResponse`: tool calls from the `content` array (`input` stringified as the arguments), `tool_use` content parts become `sType = "tool_call"` with `sToolCallId`/`sFunctionName`/`sFunctionArgs`, and `Response.AssistantMessage` (new field on `tAIResponse`) carries `{"role":"assistant","content":[...]}` as UTF-8 in `ucProviderJson`.
- [x] Stop reasons: `AIFinalizeResponse` now lets tool parts force `AI_STOP_TOOL_CALLS` only when the turn ended normally, so `max_tokens` with a cut-off `tool_use` stays `AI_STOP_MAX_TOKENS`.
- [ ] Live check against the Claude API (scenarios 1 to 17); see Phase 3's test view.

### Phase 3: Tool loop and confirmation (done, offline-tested)
- [x] `cAIDialogue` (`cAIDialogue.pkg`) for AI-to-AI: `phoFirstAI`/`phoSecondAI`, internal conversations and transcript (or your own), `psFirstLabel`/`psSecondLabel`, `pbPrefixLabels`, `psStopPhrase`, `Run sOpening iTurns`, `ContinueDialogue iTurns`, `RunTurn`, `ResetDialogue`, `OnDialogueTurn`. Each turn attaches the side's conversation, calls `ContinueConversation`, restores the provider's previous conversation and relays the reply. Errors, confirmation pauses and manual tool calls stop the dialogue (`pbStopped`, `peLastStopReason`).
- [x] `Chat sPrompt [Attachments]`, `ContinueConversation`, `SendConversationTurn` (one round trip), `RunConversation` (the loop), `OnToolCall` (tool set, else `phoToolHandler`), `OnBeforeToolCall`/`OnAfterToolCall`/`OnToolLoopIteration`, the iteration guard (`piMaxToolIterations`) and repeat guard (`piMaxRepeatedToolCalls`, default 3), the result size cap and `paToolLoopLog`.
  - When a guard stops the loop, the unanswered calls get "Not run" error results so the history stays valid; `AI_ERR_TOOL_LOOP` is reported.
  - `Chat` answers calls left open (manual mode, abandoned confirmation) as "Not run" before adding the new user turn.
- [x] Tool confirmation (D5): `OnConfirmToolCall` (default `YesNo_Box`, or defer when silent), `AI_STOP_CONFIRMATION`, `paPendingConfirmations`, `ApproveToolCall`/`DeclineToolCall sCallId [sReason]`, held results for the same turn, and resume in `ContinueConversation`.
- [x] Capturing DataFlex errors inside tools: `cAIToolErrorCapture` (in `cAIToolSet.pkg`) is swapped into `Error_Object_Id` while a tool runs; a captured error becomes an error result ("The tool raised an error: ...").
- [x] Log limits: `piMaxLogLength` (default 60000 characters on 19.x, 0 = none on 20+) cuts each `paToolLoopLog` entry and the `psModelRequestJson`/`psModelResponseJson` copies; `piMaxLogEntries` (default 40) drops the oldest entries.
- [x] `AIToolCallTest.vw` (View > AI Tool Call Test in `ai.src`; compiles on 25.0 only, like the other views):
  - provider radio (Claude, ChatGPT, Grok working; Gemini pending), Silent errors, Manual mode, Parallel and Max iterations;
  - demo tools `get_weather`, `calculate` (divide by zero is a tool error), `lookup_customer` (C001 to C003), `always_fails` (raises a DataFlex error), `post_note` (requires confirmation);
  - Send, Run tools (manual mode), Approve pending, Decline pending, New conversation; tabs for the conversation, the tool loop log and tool activity/notes;
  - uses its own `cAIConversation` and restores the provider's settings after every call.
- [ ] Live run of scenarios 1 to 21 (needs the user's API keys).

Offline coverage (`DTAIOfflineTests.src`, fake transports `cFakeClaude`/`cFakeChatGPT`/`cFakeGrok`, plus `cAIDialogue` and log-limit tests): auto loop with parallel calls and thinking replay, error capture, confirmation defer/approve/decline/moved-on, loop limit, repeat guard, manual mode, unknown tool, a transfer error mid-loop, and per-view isolation on one provider object.

### Phase 4: ChatGPT (Chat Completions, D2) (done, offline-tested)
- [x] `cChatGPTRequest.ConstructConversationRequest sModel iMaxTokens Messages Tools sSystem eToolChoice sToolChoiceName bParallel`:
  - `system` message first (when set); user turns as a string, or a content array with `image_url` data URLs and, when `pbFileParts` is True, PDF `file` parts;
  - assistant turns always rebuilt from the neutral form (`tool_calls` with `arguments` as a string); the raw message is still stored in `ucProviderJson` for logging;
  - one `tool` message per result; error results are sent as `{"error":"..."}`;
  - `tools` as `{"type":"function","function":{...}}`; `tool_choice` only when not auto; `parallel_tool_calls:false` only when off; `max_tokens` left out when 0.
- [x] Shared parser `cChatGPTTranslator.TranslateConversationResponse hoResponse sProvider`: tool calls from `choices[0].message.tool_calls`, `arguments` normalized (kept as received when invalid, so the loop answers with an "Invalid JSON arguments" error result), `tool_call` content parts, stop reasons (`length` -> max tokens). New global `AINormalizeJsonObject`.
- [x] `cChatGPTInterface.BuildConversationRequest`/`ParseConversationResponse`. Single-turn `CreateRequest`/`MakeRequest` unchanged.
- [ ] Reasoning models want `max_completion_tokens` (not yet).

### Phase 5: Grok on `/v1/chat/completions` (D1)
- [x] `cGrokInterface.MakeRequestJSON` posts to `v1/chat/completions`. Errors in both shapes (`{"code","error"}` and `{"error":{"message","type"}}`) go through `ReportAIError`, and the response is destroyed and 0 returned (before, the error JSON was returned and translated).
- [x] `oGrokRequest` is a `cChatGPTRequest` (`pbFileParts` False); `cGrokTranslator` is now a subclass of `cChatGPTTranslator`.
- [x] `grokai.pkg` also uses `chatgptai.h`/`cChatGPTRequest.pkg` (the Claude uses stay because `tGrokModelList` uses `tClaudeModel`). `CreateRequest` now takes `tAIAttachment[]` and builds a Chat Completions request; `MakeRequest` reads `tChatGPTResponse`.
- [x] Attachments: images as `image_url` data URLs; PDFs are skipped for Grok.
- [ ] Re-test single-turn prompts in `AIDemo.vw`/`AIChatExample.vw` live. Keep `SetTimeout`. Check `piMaxTokens` 256000 is accepted by chat completions for the chosen model.

### Phase 6: Gemini (done, offline-tested)
- [x] No `geminiai.h` changes were needed: the conversation builder works straight from `tAIMessage[]` (the old `tGeminiPart` builder `CreateGeminiApiJsonRequest` is unchanged for single prompts).
- [x] `cGeminiRequest.CreateGeminiConversationRequest`: `systemInstruction`, `contents` with consecutive same-role turns merged (a tool turn and the next user prompt become one `user` content, since Gemini wants roles to alternate), `tools[0].functionDeclarations` with `parametersJsonSchema`, `toolConfig.functionCallingConfig` only when the choice isn't auto (`NONE`, `ANY`, `ANY` + `allowedFunctionNames`), and `generationConfig` with only the members that are set (`maxOutputTokens` falls back to `piMaxTokens`). Gemini has no switch for parallel calls, so `pbParallelToolCalls` is ignored. User attachments: text/JSON as text parts, files with `sFileID` as `fileData.fileUri`, others as `inlineData`.
- [x] Model turns: the raw candidate content is replayed part for part (thought parts and `thoughtSignature` included). Without it (history from another provider), text + `functionCall` parts are rebuilt; a Gemini call's `thoughtSignature` (`sProviderData`) is added back. Call ids go back only when Gemini made them; generated `gemini-call-<n>` ids and other providers' ids are left out.
- [x] Tool turns: one `functionResponse` per result, in call order; `{"result": <object or text>}` or `{"error": "<message>"}`; the name comes from the result, else the matching call by id, else by position.
- [x] `cGeminiInterface.ParseConversationResponse`: `functionCall` parts -> `ToolCalls` (id or `gemini-call-<n>` from a per-object counter, args object as text, `thoughtSignature` in `sProviderData`), `thought: true` parts left out of `sText`, `usageMetadata`, `modelVersion`, `responseId`, blocked prompts (`promptFeedback.blockReason`, no candidates) -> `AI_STOP_CONTENT_FILTER`. `UNEXPECTED_TOOL_CALL`/`TOO_MANY_TOOL_CALLS` map to `AI_STOP_ERROR`, `IMAGE_SAFETY` to content filter.
- [x] Non-JSON responses go through `ReportAIError`; the `Showln` of the raw response is gone.
- [x] Offline tests: request building (system, attachments, cross-provider history, merged turns, tool choice, native ids, signatures, error results), parsing, the tool loop with and without Gemini ids, confirmation with id echo, error capture.
- [ ] Live test in `AIToolCallTest.vw`. Check whether `models/gemini-2.5-flash` returns `functionCall.id` and thought signatures, and that `parametersJsonSchema` is accepted on `v1beta`.

### Phase 7: Test and harden
- [ ] Capture fixtures and write the offline parser/builder tests.
- [ ] Run scenarios 1 to 17 on all four providers, **on both 19.1 and 25.0**, and record the matrix here.
- [ ] Regression on `AIDemo.vw` and `AIChatExample.vw`.

### Phase 8: Documentation
- [ ] README section "Tool calls":
  - a quick start with `cAIToolSet`;
  - manual mode, confirmation and silent errors;
  - the security notes and provider quirks;
  - the 19.1 limits (OEM characters, size).
- [ ] Optionally move `AIChatExample.vw` to `Chat` with a `cAIConversation` per provider.
- [ ] Document `cAIConversation` (attach, default, per-view, switching providers) and AI-to-AI with `cAITranscript`.

### Later (not v1)
- Saving conversations and transcripts to a table.
- Trimming long histories to fit token limits.
- OpenAI/xAI Responses API support (D2).
- Streaming.
- Provider built-in tools (web search, code execution).
- MCP servers.
- Multimodal tool results.

## Pending Items
- Live-check the new defaults, Grok `piMaxTokens` 256000 with `grok-4.7`, and Claude Sonnet 5.5's adaptive thinking against `piMaxTokens` 8192.
- OpenAI Responses API (D2) would allow tools on `gpt-6.1-sol`/`gpt-6.1-terra`/`gpt-6-astra`.

## Open Questions
1. **Handler style.**
   - Are you happy with tool objects (`cAIToolSet`/`cAITool` with an `Execute` function) as the main pattern?
   - Is the `AddTool` + `OnToolCall` override enough on its own?
   - Should we support both, as proposed?
2. **Defaults.**
   - Is `piMaxToolIterations` = 8 right?
   - Should parallel calls be on by default?
   - Should strict schemas be off by default?
3. **Tool result format.** Should `Execute` return plain text, or should we strongly encourage JSON text? Gemini needs an object either way, and the library would wrap plain text as `{"result":"..."}`.
4. **WebApp use.** Will tool calls run in WebApps? If so, the test view also needs a web version, every tool must stay UI-free, and WebApps would use deferred confirmation.
5. **Default models.** Resolved in revision 7 (checked against the providers' deprecation pages on Nov 16, 2026):
   - Claude `claude-sonnet-4-20250514` (retired June 15, 2026) -> `claude-sonnet-5-5`, Anthropic's listed replacement.
   - ChatGPT `gpt-4.1-nano` (shut down Oct 23, 2026) -> `gpt-6-luna`. Of the current OpenAI models only Luna supports function calling on Chat Completions (with `reasoning_effort: "none"`); `gpt-6.1-sol`, `gpt-6.1-terra` need the Responses API for tools.
   - Grok `grok-3` (retired May 15, 2026, redirected to `grok-4.3`) -> `grok-4.7`, xAI's recommended chat/code model.
   - Gemini `models/gemini-2.5-flash` (deprecated; routed to `gemini-3.5-flash-lite` from Dec 1, 2026) -> `models/gemini-3.8-flash` (stable).
6. **Confirmation default (new).** Is a `YesNo_Box` the right default for Windows apps when `pbSilentErrors` is False? Or should confirmation always defer to the app, which would keep UI out of the library entirely, in line with the README TODO?
7. **19.1 character limits (new).** Is it acceptable that on 19.1, text outside the OEM code page (emoji, CJK, some symbols) can't pass through tool arguments and results as `String`s? Do any 19.1 customers need non-Western-European text?

## References
- OpenAI, Function calling (Chat Completions `tools`/`tool_calls`, and the Responses API `function_call`/`function_call_output`).
- Anthropic, Tool use: define tools, `tool_choice`, and handle `tool_use`/`tool_result`.
- xAI, Function Calling: https://docs.x.ai/developers/tools/function-calling. Legacy & Deprecated (`/v1/messages`): https://docs.x.ai/developers/rest-api-reference/inference/legacy
- Google, Gemini API reference (`FunctionCall.id`, `FunctionResponse.response`, `parametersJsonSchema`, `FunctionCallingConfig` modes `AUTO`/`ANY`/`NONE`/`VALIDATED`, `thoughtSignature`): https://ai.google.dev/api/caching and https://ai.google.dev/gemini-api/docs/function-calling
