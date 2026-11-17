// AIToolCallTest.vw - live test view for tool calls (tool_calls_plan.md, Phase 3)
// View > AI Tool Call Test in ai.src. Uses its own cAIConversation, so it never
// shares history with the other views. Provider settings changed for a call are
// restored afterwards (the provider objects are global).
Use Windows.pkg
Use DFClient.pkg

Use chatgptai.pkg
Use geminiai.pkg
Use grokai.pkg
Use claudeai.pkg

Use cTextEdit.pkg
Use cAIDemoToolSet.pkg

Register_Procedure LogToolActivity String sText
Register_Object oModelCombo

Deferred_View Activate_oAIToolCallTest for ;
Object oAIToolCallTest is a dbView
    Property Handle  phoAI 0
    // provider settings saved by ApplySettings
    Property Handle  phoSavedConversation 0
    Property Handle  phoSavedToolSet 0
    Property Boolean pbSavedSilent False
    Property Boolean pbSavedAuto True
    Property Boolean pbSavedParallel True
    Property Integer piSavedMaxIterations 8
    Property String  psSavedModel ''
    Property Boolean pbModelComboReady False   // set once oModelCombo exists

    Set Border_Style to Border_Thick
    Set Size to 380 520
    Set Location to 2 2
    Set Label to "AI Tool Call Test"
    Set piMinSize to 300 420

    //=========================================================================
    // conversation and demo tools
    //=========================================================================
    Object oConversation is a cAIConversation
        Set psSystemPrompt to "You are a test assistant for a DataFlex application. Use the provided tools when they help. Keep answers short."
    End_Object

    // the demo tools (cAIDemoToolSet.pkg, shared with AIDialogueDemo.vw)
    Object oDemoTools is a cAIDemoToolSet
        Procedure OnToolActivity String sText
            Send LogToolActivity sText
        End_Procedure
    End_Object

    // provider and model helpers (used by the controls below)
    Function ProviderReady Handle hoAI Returns Boolean
        Function_Return (hoAI=ghoClaudeAI or hoAI=ghoChatGPTAI or hoAI=ghoGeminiAI or hoAI=ghoGrokAI)
    End_Function

    // provider object for the radio item (0 Claude, 1 ChatGPT, 2 Gemini, 3 Grok)
    Function AIForItem Integer iItem Returns Handle
        If (iItem=0) Function_Return ghoClaudeAI
        If (iItem=1) Function_Return ghoChatGPTAI
        If (iItem=2) Function_Return ghoGeminiAI
        If (iItem=3) Function_Return ghoGrokAI
        Function_Return 0
    End_Function

    // static list used when ModelList fails or returns nothing (checked Nov 16, 2026).
    // The first entry is the library default.
    Function FallbackModels Handle hoAI Returns tAIModel[]
        String[] aIds
        tAIModel[] aModels
        Integer i
        If (hoAI=ghoClaudeAI) Begin
            Move "claude-sonnet-5-5" to aIds[0]
            Move "claude-opus-5-5"   to aIds[1]
            Move "claude-haiku-5-5"  to aIds[2]
            Move "claude-fable-5-2"  to aIds[3]
            Move "claude-opus-4-8"   to aIds[4]
            Move "claude-sonnet-4-6" to aIds[5]
        End
        If (hoAI=ghoChatGPTAI) Begin
            // only gpt-6-luna supports function calling on Chat Completions;
            // the others need the Responses API for tools (plain chat works)
            Move "gpt-6-luna"   to aIds[0]
            Move "gpt-6.1-sol"  to aIds[1]
            Move "gpt-6.1-terra" to aIds[2]
            Move "gpt-6-astra"  to aIds[3]
        End
        If (hoAI=ghoGeminiAI) Begin
            Move "models/gemini-3.8-flash"      to aIds[0]
            Move "models/gemini-4-hydrogen"     to aIds[1]
            Move "models/gemini-4-argon"        to aIds[2]
            Move "models/gemini-4-carbon"       to aIds[3]
            Move "models/gemini-3.6-flash"      to aIds[4]
            Move "models/gemini-3.5-flash-lite" to aIds[5]
        End
        If (hoAI=ghoGrokAI) Begin
            Move "grok-4.7" to aIds[0]
            Move "grok-4.6" to aIds[1]
            Move "grok-4.5" to aIds[2]
            Move "grok-4.3" to aIds[3]
        End
        For i from 0 to (SizeOfArray(aIds)-1)
            Move aIds[i] to aModels[i].id
            Move aIds[i] to aModels[i].display_name
        Loop
        Function_Return aModels
    End_Function

    // keeps text models out of ModelList results that also list image, audio,
    // embedding and similar models
    Function IsChatModelId Handle hoAI String sId Returns Boolean
        String s s2
        Move (Lowercase(Trim(sId))) to s
        If (s='') Function_Return False
        If (Pos('image',s)>0 or Pos('audio',s)>0 or Pos('tts',s)>0 or Pos('embedding',s)>0 or Pos('video',s)>0) Function_Return False
        If (hoAI=ghoChatGPTAI) Begin
            Move (Mid(s,1,2)) to s2
            If (Left(s,4)<>'gpt-' and not(Left(s,1)='o' and s2>='0' and s2<='9')) Function_Return False
            If (Pos('realtime',s)>0 or Pos('transcribe',s)>0 or Pos('search',s)>0 or Pos('live',s)>0 or Pos('codex',s)>0 or Pos('cyber',s)>0) Function_Return False
        End
        If (hoAI=ghoGeminiAI) Begin
            If (Pos('gemini',s)=0 or Pos('live',s)>0) Function_Return False
        End
        If (hoAI=ghoGrokAI) Begin
            If (Pos('imagine',s)>0 or Pos('voice',s)>0) Function_Return False
        End
        Function_Return True
    End_Function

    //=========================================================================
    // controls
    //=========================================================================
    Object oSelectAI is a RadioGroup
        Set Size to 26 300
        Set Location to 2 2
        Set Label to 'Provider'

        Object oRadio0 is a Radio
            Set Label to "Claude"
            Set Size to 10 34
            Set Location to 10 5
        End_Object
        Object oRadio1 is a Radio
            Set Label to "ChatGPT"
            Set Size to 10 74
            Set Location to 10 45
        End_Object
        Object oRadio2 is a Radio
            Set Label to "Gemini"
            Set Size to 10 70
            Set Location to 10 125
        End_Object
        Object oRadio3 is a Radio
            Set Label to "Grok"
            Set Size to 10 64
            Set Location to 10 201
        End_Object

        Procedure Notify_Select_State Integer iToItem Integer iFromItem
            Handle hoAI
            Forward Send Notify_Select_State iToItem iFromItem
            If (iToItem=0) Move ghoClaudeAI to hoAI
            If (iToItem=1) Move ghoChatGPTAI to hoAI
            If (iToItem=2) Move ghoGeminiAI to hoAI
            If (iToItem=3) Move ghoGrokAI to hoAI
            Set phoAI to hoAI
            // a new provider has its own models (as in AIDemo.vw)
            If (iToItem<>iFromItem and pbModelComboReady(Self)) Send Combo_Fill_List of oModelCombo
        End_Procedure
    End_Object

    Object oSilentCheck is a CheckBox
        Set Location to 4 310
        Set Size to 10 150
        Set Label to "Silent errors (confirmations wait for Approve)"
    End_Object

    Object oManualCheck is a CheckBox
        Set Location to 16 310
        Set Size to 10 110
        Set Label to "Manual mode (Run tools button)"
    End_Object

    Object oParallelCheck is a CheckBox
        Set Location to 4 466
        Set Size to 10 50
        Set Label to "Parallel"
        Set Checked_State to True
    End_Object

    Object oMaxIterationsForm is a Form
        Set Location to 16 490
        Set Size to 12 24
        Set Label to "Max:"
        Set Label_Col_Offset to 2
        Set Label_Justification_Mode to JMode_Right
        Set Numeric_Mask 0 to 3 0
        Set Value to 8
    End_Object

    Object oPromptTextEdit is a cTextEdit
        Set Location to 32 2
        Set Size to 50 516
        Set peAnchors to anTopLeftRight
    End_Object

    Object oSendButton is a Button
        Set Location to 86 2
        Set Label to "Send"
        Set Size to 14 60
        Procedure OnClick
            Send SubmitPrompt
        End_Procedure
    End_Object

    Object oRunToolsButton is a Button
        Set Location to 86 66
        Set Label to "Run tools"
        Set Size to 14 60
        Procedure OnClick
            Send RunPendingTools
        End_Procedure
    End_Object

    Object oApproveButton is a Button
        Set Location to 86 130
        Set Label to "Approve pending"
        Set Size to 14 70
        Procedure OnClick
            Send DecidePending True
        End_Procedure
    End_Object

    Object oDeclineButton is a Button
        Set Location to 86 204
        Set Label to "Decline pending"
        Set Size to 14 70
        Procedure OnClick
            Send DecidePending False
        End_Procedure
    End_Object

    Object oNewButton is a Button
        Set Location to 86 278
        Set Label to "New conversation"
        Set Size to 14 74
        Procedure OnClick
            Send NewConversation
        End_Procedure
    End_Object

    Object oStatusForm is a Form
        Set Location to 104 30
        Set Size to 12 488
        Set Label to "Status:"
        Set Label_Col_Offset to 2
        Set Label_Justification_Mode to JMode_Right
        Set Enabled_State to False
        Set peAnchors to anTopLeftRight
    End_Object

    // Model dropdown, modeled on oSelectModel in AIDemo.vw: filled from the
    // provider's ModelList, showing display_name, with the provider's psModelId
    // selected. Unlike AIDemo it doesn't change the global provider on OnChange:
    // ApplySettings uses the selected id for this view's calls and RestoreSettings
    // puts the provider's own psModelId back.
    Object oModelCombo is a ComboForm
        Property tAIModel[] paModelList

        Set Location to 86 386
        Set Size to 13 132
        Set Label to "Model:"
        Set Label_Col_Offset to 2
        Set Label_Justification_Mode to JMode_Right
        Set Combo_Sort_State to False
        Set peAnchors to anTopLeftRight

        Procedure End_Construct_Object
            Forward Send End_Construct_Object
            Set pbModelComboReady to True
        End_Procedure

        // ModelList is a live call (cached by the provider). Its errors follow the
        // "Silent errors" box; when it returns nothing the built-in list is used.
        Procedure Combo_Fill_List
            tAIModel[] aModelList aAll
            tAIModel Model
            Handle hoAI
            Integer i
            String sModelId sValue sSource
            Boolean bSavedSilent

            Get phoAI to hoAI
            If (hoAI=0) Begin
                Get AIForItem (Current_Radio(oSelectAI(Self))) to hoAI
                Set phoAI to hoAI
            End
            If (hoAI) Get psModelId of hoAI to sModelId

            Send Combo_Delete_Data

            If (hoAI) Begin
                If (ProviderReady(Self,hoAI)) Begin
                    Get pbSilentErrors of hoAI to bSavedSilent
                    Set pbSilentErrors of hoAI to (Checked_State(oSilentCheck(Self)))
                    Get ModelList of hoAI to aAll
                    Set pbSilentErrors of hoAI to bSavedSilent
                    For i from 0 to (SizeOfArray(aAll)-1)
                        If (IsChatModelId(Self,hoAI,aAll[i].id)) Begin
                            If (aAll[i].display_name='') Move aAll[i].id to aAll[i].display_name
                            Move aAll[i] to aModelList[SizeOfArray(aModelList)]
                        End
                    Loop
                End
                Move ("models from the API:"*String(SizeOfArray(aModelList))) to sSource
                If (SizeOfArray(aModelList)=0) Begin
                    Get FallbackModels hoAI to aModelList
                    Move "ModelList returned nothing; using the built-in model list" to sSource
                End
                // the provider's default is always in the list
                For i from 0 to (SizeOfArray(aModelList)-1)
                    If (sModelId=aModelList[i].id) Move aModelList[i].display_name to sValue
                Loop
                If (sValue='' and sModelId<>'') Begin
                    Move sModelId to Model.id
                    Move sModelId to Model.display_name
                    Move (InsertInArray(aModelList,0,Model)) to aModelList
                    Move sModelId to sValue
                End
                For i from 0 to (SizeOfArray(aModelList)-1)
                    Send Combo_Add_Item aModelList[i].display_name
                Loop
                Set Value of oStatusForm to (ProviderName(hoAI)+": "+sSource+"; default model"*sModelId)
            End
            Set paModelList to aModelList
            If (sValue<>'') Set Value to sValue
        End_Procedure

        // id of the selected model; text typed into the combo is used as an id
        Function SelectedModelId Returns String
            String sValue
            Integer iCombo
            tAIModel[] aModelList
            Get Value to sValue
            Move (Trim(sValue)) to sValue
            If (sValue='') Function_Return ''
            Get Combo_Item_Matching sValue to iCombo
            Get paModelList to aModelList
            If (iCombo>=0 and iCombo<SizeOfArray(aModelList)) Function_Return aModelList[iCombo].id
            Function_Return sValue
        End_Function
    End_Object

    Object oTabs is a TabDialog
        Set Location to 120 2
        Set Size to 256 516
        Set peAnchors to anAll

        Object oConversationPage is a TabPage
            Set Label to "Conversation"
            Object oResultEdit is a cTextEdit
                Set Location to 2 2
                Set Size to 236 508
                Set peAnchors to anAll
                Set Read_Only_State to True
            End_Object
        End_Object

        Object oLogPage is a TabPage
            Set Label to "Tool loop log"
            Object oLogEdit is a cTextEdit
                Set Location to 2 2
                Set Size to 236 508
                Set peAnchors to anAll
                Set Read_Only_State to True
                Set psTypeFace to "Consolas"
            End_Object
        End_Object

        Object oActivityPage is a TabPage
            Set Label to "Tool activity / notes"
            Object oActivityEdit is a cTextEdit
                Set Location to 2 2
                Set Size to 236 508
                Set peAnchors to anAll
                Set Read_Only_State to True
            End_Object
        End_Object
    End_Object

    //=========================================================================
    // logic
    //=========================================================================
    Procedure LogToolActivity String sText
        String sOld
        Get Value of oActivityEdit to sOld
        If (sOld<>'') Move (sOld+Character(13)+Character(10)) to sOld
        Set Value of oActivityEdit to (sOld+String(CurrentDateTime())+"  "+sText)
    End_Procedure

    Procedure Activating
        Forward Send Activating
        If (phoAI(Self)=0) Set Current_Radio of oSelectAI to 0
    End_Procedure

    // providers with conversation/tool support so far




    Function SelectedAI Returns Handle
        Handle hoAI
        Get phoAI to hoAI
        If (hoAI=0) Begin
            Send Info_Box "Select a provider first."
            Function_Return 0
        End
        If (not(ProviderReady(Self,hoAI))) Begin
            Send Info_Box "Tool calls are not supported for this provider."
            Function_Return 0
        End
        Function_Return hoAI
    End_Function

    // put this view's settings on the (global) provider; RestoreSettings undoes it
    Procedure ApplySettings Handle hoAI
        Integer iMax
        String sModel
        Set phoSavedConversation to (phoConversation(hoAI))
        Set phoSavedToolSet to (phoToolSet(hoAI))
        Set pbSavedSilent to (pbSilentErrors(hoAI))
        Set pbSavedAuto to (pbAutoExecuteTools(hoAI))
        Set pbSavedParallel to (pbParallelToolCalls(hoAI))
        Set piSavedMaxIterations to (piMaxToolIterations(hoAI))
        Set psSavedModel to (psModelId(hoAI))

        Set phoConversation of hoAI to oConversation
        Set phoToolSet of hoAI to oDemoTools
        Set pbSilentErrors of hoAI to (Checked_State(oSilentCheck(Self)))
        Set pbAutoExecuteTools of hoAI to (not(Checked_State(oManualCheck(Self))))
        Set pbParallelToolCalls of hoAI to (Checked_State(oParallelCheck(Self)))
        Get Value of oMaxIterationsForm to iMax
        If (iMax<1) Move 8 to iMax
        Set piMaxToolIterations of hoAI to iMax
        Get SelectedModelId of oModelCombo to sModel
        If (sModel<>'') Set psModelId of hoAI to sModel
    End_Procedure

    Procedure RestoreSettings Handle hoAI
        Set phoConversation of hoAI to (phoSavedConversation(Self))
        Set phoToolSet of hoAI to (phoSavedToolSet(Self))
        Set pbSilentErrors of hoAI to (pbSavedSilent(Self))
        Set pbAutoExecuteTools of hoAI to (pbSavedAuto(Self))
        Set pbParallelToolCalls of hoAI to (pbSavedParallel(Self))
        Set piMaxToolIterations of hoAI to (piSavedMaxIterations(Self))
        Set psModelId of hoAI to (psSavedModel(Self))
    End_Procedure

    Function StopReasonName Integer eStop Returns String
        If (eStop=AI_STOP_END_TURN) Function_Return "end of turn"
        If (eStop=AI_STOP_TOOL_CALLS) Function_Return "tool calls"
        If (eStop=AI_STOP_MAX_TOKENS) Function_Return "max tokens"
        If (eStop=AI_STOP_CONTENT_FILTER) Function_Return "content filter"
        If (eStop=AI_STOP_ERROR) Function_Return "error"
        If (eStop=AI_STOP_CONFIRMATION) Function_Return "waiting for confirmation"
        Function_Return "unknown"
    End_Function

    Procedure ShowConversation
        tAIMessage[] aMsgs
        String sText sCRLF sLine
        Integer i j
        Move (Character(13)+Character(10)) to sCRLF
        Get paMessages of oConversation to aMsgs
        For i from 0 to (SizeOfArray(aMsgs)-1)
            If (aMsgs[i].sRole='tool') Begin
                For j from 0 to (SizeOfArray(aMsgs[i].ToolResults)-1)
                    Move ("   <- "+aMsgs[i].ToolResults[j].sName+" ["+aMsgs[i].ToolResults[j].sCallId+"]") to sLine
                    If (aMsgs[i].ToolResults[j].bIsError) Move (sLine+" ERROR") to sLine
                    Move (sText+sLine+": "+aMsgs[i].ToolResults[j].sContent+sCRLF) to sText
                Loop
            End
            Else Begin
                If (aMsgs[i].sRole='assistant') Move (sText+"Assistant ("+aMsgs[i].sProvider+"): ") to sText
                Else Move (sText+"User: ") to sText
                Move (sText+aMsgs[i].sText+sCRLF) to sText
                For j from 0 to (SizeOfArray(aMsgs[i].ToolCalls)-1)
                    Move (sText+"   -> "+aMsgs[i].ToolCalls[j].sName+aMsgs[i].ToolCalls[j].sArgumentsJson+" ["+aMsgs[i].ToolCalls[j].sId+"]"+sCRLF) to sText
                Loop
            End
            Move (sText+sCRLF) to sText
        Loop
        Set Value of oResultEdit to sText
    End_Procedure

    Procedure ShowResult Handle hoAI tAIResponse Response
        String sStatus sLog sCRLF sNotes
        String[] aLog
        tAIToolCall[] aPending
        Integer i iTrip

        Move (Character(13)+Character(10)) to sCRLF
        Move ("Model:"*psModelId(hoAI)+"  |  Stop:"*StopReasonName(Self,Response.eStopReason)+"  |  round trips:"*String(Response.iToolIterations)) to sStatus
        Move ("tokens in/out:"*String(Response.Usage.iInputTokens)+"/"+String(Response.Usage.iOutputTokens)) to sLog
        Move (sStatus+"  |  "+sLog) to sStatus
        If (HasError(hoAI)) Move (sStatus+"  |  ERROR:"*psLastError(hoAI)) to sStatus
        Get paPendingConfirmations of oConversation to aPending
        If (SizeOfArray(aPending)>0) Begin
            Move (sStatus+"  |  pending:") to sStatus
            For i from 0 to (SizeOfArray(aPending)-1)
                Move (sStatus*aPending[i].sName+aPending[i].sArgumentsJson) to sStatus
            Loop
            Move (sStatus+"  -> Approve or Decline") to sStatus
        End
        If (Response.eStopReason=AI_STOP_TOOL_CALLS and not(pbAutoExecuteTools(hoAI))) Move (sStatus+"  |  manual mode: press Run tools") to sStatus
        Set Value of oStatusForm to sStatus

        Send ShowConversation

        Move '' to sLog
        Get paToolLoopLog of hoAI to aLog
        For i from 0 to (SizeOfArray(aLog)-1)
            Move ((i-Mod(i,2))/2+1) to iTrip
            If (Mod(i,2)=0) Move (sLog+"===== request "+String(iTrip)+" ====="+sCRLF) to sLog
            Else Move (sLog+"===== response "+String(iTrip)+" ====="+sCRLF) to sLog
            Move (sLog+aLog[i]+sCRLF+sCRLF) to sLog
        Loop
        Set Value of oLogEdit to sLog
    End_Procedure

    Procedure SubmitPrompt
        Handle hoAI
        String sPrompt
        tAIResponse Response

        Get SelectedAI to hoAI
        If (hoAI=0) Procedure_Return
        Get Value of oPromptTextEdit to sPrompt
        Move (Trim(sPrompt)) to sPrompt
        If (sPrompt='') Procedure_Return

        Set Value of oStatusForm to "Waiting for the model..."
        Send ApplySettings hoAI
        Get Chat of hoAI sPrompt to Response
        Send ShowResult hoAI Response
        Send RestoreSettings hoAI
        Set Value of oPromptTextEdit to ''
    End_Procedure

    // manual mode: run the calls of the last assistant turn here, then continue
    Procedure RunPendingTools
        Handle hoAI
        tAIMessage LastMsg
        tAIToolResult[] aResults
        tAIToolResult Result
        tAIResponse Response
        Integer i

        Get SelectedAI to hoAI
        If (hoAI=0) Procedure_Return
        If (not(HasUnansweredToolCalls(oConversation(Self)))) Begin
            Send Info_Box "There are no tool calls waiting to be run."
            Procedure_Return
        End
        Send ApplySettings hoAI
        Get LastMessage of oConversation to LastMsg
        For i from 0 to (SizeOfArray(LastMsg.ToolCalls)-1)
            Get RunToolCall of hoAI LastMsg.ToolCalls[i] to Result
            Move Result to aResults[i]
        Loop
        Send AddToolResults of hoAI aResults
        Get ContinueConversation of hoAI to Response
        Send ShowResult hoAI Response
        Send RestoreSettings hoAI
    End_Procedure

    // approve or decline every pending confirmation, then continue
    Procedure DecidePending Boolean bApprove
        Handle hoAI
        tAIToolCall[] aPending
        tAIResponse Response
        Integer i

        Get SelectedAI to hoAI
        If (hoAI=0) Procedure_Return
        Get paPendingConfirmations of oConversation to aPending
        If (SizeOfArray(aPending)=0) Begin
            Send Info_Box "No tool calls are waiting for confirmation."
            Procedure_Return
        End
        // the confirmation state is on this view's conversation: attach it first
        Send ApplySettings hoAI
        For i from 0 to (SizeOfArray(aPending)-1)
            If (bApprove) Send ApproveToolCall of hoAI aPending[i].sId
            Else Send DeclineToolCall of hoAI aPending[i].sId "Declined in the test view."
        Loop
        Get ContinueConversation of hoAI to Response
        Send ShowResult hoAI Response
        Send RestoreSettings hoAI
    End_Procedure

    Procedure NewConversation
        Handle hoAI
        // also clears the conversation's pending confirmations
        Send ClearMessages of oConversation
        Set Value of oResultEdit to ''
        Set Value of oLogEdit to ''
        Set Value of oStatusForm to ''
    End_Procedure

Cd_End_Object
