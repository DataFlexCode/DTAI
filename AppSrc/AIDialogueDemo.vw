// AIDialogueDemo.vw - demo of cAIDialogue: two AI participants talking to each other.
// View > AI Dialogue Demo in ai.src. See docs\cAIDialogue.md.
//
// Each participant has its own provider, model, name, persona (system prompt) and,
// optionally, the demo tools (cAIDemoToolSet.pkg). Each keeps its own
// cAIConversation inside oDialogue; the shared transcript shows who said what.
// The provider objects are global: per-side settings are put on the provider in
// OnBeforeSideTurn and restored in OnAfterSideTurn, so other views are unaffected.
// Errors are silent (shown in the Error line) and tool calls that need
// confirmation (post_note) pause the dialogue until Approve or Decline.
Use Windows.pkg
Use DFClient.pkg
Use cTimer.pkg

Use chatgptai.pkg
Use geminiai.pkg
Use grokai.pkg
Use claudeai.pkg

Use cTextEdit.pkg
Use cAIDemoToolSet.pkg

Register_Object oSideNameForm
Register_Object oSideProviderCombo
Register_Object oSideModelCombo
Register_Object oSideToolsCheck
Register_Object oSidePersonaEdit
Register_Procedure FillModels
Register_Procedure FillProviderList
Register_Procedure OnProviderChanged
Register_Procedure ShowStatus String sText
Register_Procedure ApplySideSettings Integer iSide Handle hoAI
Register_Procedure RestoreSideSettings Handle hoAI
Register_Procedure LogActivity String sText
Register_Procedure RunNextTurn

//=============================================================================
// One participant: name, provider, model, demo tools and persona
//=============================================================================
// (DataFlex doesn't allow methods in child objects of a class, so the two combos
// are small classes that hand their events to the group)
Class cDialogueProviderCombo is a ComboForm
    Procedure Combo_Fill_List
        Delegate Send FillProviderList
    End_Procedure

    // a new provider has its own models (as in AIDemo.vw)
    Procedure OnChange
        Delegate Send OnProviderChanged
    End_Procedure
End_Class

// filled when the view activates (after the provider combo) and again whenever
// the provider changes
Class cDialogueModelCombo is a ComboForm
    Procedure Combo_Fill_List
        Delegate Send FillModels
    End_Procedure
End_Class

Class cDialogueSideGroup is a Group

    Procedure Construct_Object
        Forward Send Construct_Object
        Property tAIModel[] paModelList
        Property Boolean    pbReady False   // True once the model list is first filled
        Property String     psDefaultName ''
        Property String     psDefaultProvider 'Claude'
        Property String     psDefaultPersona ''

        Set Size to 122 256

        Object oSideNameForm is a Form
            Set Location to 10 46
            Set Size to 12 80
            Set Label to "Name:"
            Set Label_Col_Offset to 2
            Set Label_Justification_Mode to JMode_Right
        End_Object

        Object oSideProviderCombo is a cDialogueProviderCombo
            Set Location to 10 168
            Set Size to 12 82
            Set Label to "Provider:"
            Set Label_Col_Offset to 2
            Set Label_Justification_Mode to JMode_Right
            Set Entry_State to False
            Set Combo_Sort_State to False
        End_Object

        Object oSideModelCombo is a cDialogueModelCombo
            Set Location to 26 46
            Set Size to 12 204
            Set Label to "Model:"
            Set Label_Col_Offset to 2
            Set Label_Justification_Mode to JMode_Right
            Set Combo_Sort_State to False
        End_Object

        Object oSideToolsCheck is a CheckBox
            Set Location to 42 46
            Set Size to 10 200
            Set Label to "Give this participant the demo tools"
        End_Object

        Object oSidePersonaEdit is a cTextEdit
            Set Location to 56 46
            Set Size to 60 204
            Set Label to "Persona:"
            Set Label_Col_Offset to 2
            Set Label_Justification_Mode to JMode_Right
        End_Object
    End_Procedure

    // provider object for a provider name
    Function AIForName String sName Returns Handle
        If (sName="Claude") Function_Return ghoClaudeAI
        If (sName="ChatGPT") Function_Return ghoChatGPTAI
        If (sName="Gemini") Function_Return ghoGeminiAI
        If (sName="Grok") Function_Return ghoGrokAI
        Function_Return 0
    End_Function

    Function SideAI Returns Handle
        String sProvider
        Get Value of (oSideProviderCombo(Self)) to sProvider
        Function_Return (AIForName(Self,sProvider))
    End_Function

    Function SideName Returns String
        String sName
        Get Value of (oSideNameForm(Self)) to sName
        Move (Trim(sName)) to sName
        If (sName='') Get Value of (oSideProviderCombo(Self)) to sName
        Function_Return sName
    End_Function

    Function Persona Returns String
        String sText
        Get Value of (oSidePersonaEdit(Self)) to sText
        Function_Return (Trim(sText))
    End_Function

    Function UseTools Returns Boolean
        Function_Return (Checked_State(oSideToolsCheck(Self)))
    End_Function

    Procedure FillProviderList
        Handle hoCombo
        Move (oSideProviderCombo(Self)) to hoCombo
        Send Combo_Delete_Data of hoCombo
        Send Combo_Add_Item of hoCombo "Claude"
        Send Combo_Add_Item of hoCombo "ChatGPT"
        Send Combo_Add_Item of hoCombo "Gemini"
        Send Combo_Add_Item of hoCombo "Grok"
        Set Value of hoCombo to (psDefaultProvider(Self))
    End_Procedure

    Procedure OnProviderChanged
        If (pbReady(Self)) Send FillModels
    End_Procedure

    // name and persona defaults (sent once by the view's Activating)
    Procedure ApplyDefaultTexts
        Set Value of (oSideNameForm(Self)) to (psDefaultName(Self))
        Set Value of (oSidePersonaEdit(Self)) to (psDefaultPersona(Self))
    End_Procedure

    // static list used when ModelList fails or returns nothing (same list as
    // AIToolCallTest.vw, checked Nov 16, 2026). The first entry is the library default.
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
            Move "gpt-6-luna"    to aIds[0]
            Move "gpt-6.1-sol"   to aIds[1]
            Move "gpt-6.1-terra" to aIds[2]
            Move "gpt-6-astra"   to aIds[3]
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
    // embedding and similar models (same rules as AIToolCallTest.vw)
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

    // fills the model dropdown from the provider's ModelList (silent errors),
    // falling back to the built-in list; the provider's psModelId is selected
    Procedure FillModels
        tAIModel[] aModelList aAll
        tAIModel Model
        Handle hoAI hoCombo
        Integer i
        String sModelId sValue sSource
        Boolean bSavedSilent

        Move (oSideModelCombo(Self)) to hoCombo
        Send Combo_Delete_Data of hoCombo
        Get SideAI to hoAI
        If (hoAI=0) Begin
            Set paModelList to aModelList
            Set Value of hoCombo to ''
            Procedure_Return
        End
        Get psModelId of hoAI to sModelId

        Get pbSilentErrors of hoAI to bSavedSilent
        Set pbSilentErrors of hoAI to True
        Get ModelList of hoAI to aAll
        Set pbSilentErrors of hoAI to bSavedSilent
        For i from 0 to (SizeOfArray(aAll)-1)
            If (IsChatModelId(Self,hoAI,aAll[i].id)) Begin
                If (aAll[i].display_name='') Move aAll[i].id to aAll[i].display_name
                Move aAll[i] to aModelList[SizeOfArray(aModelList)]
            End
        Loop
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
            Send Combo_Add_Item of hoCombo aModelList[i].display_name
        Loop
        Set paModelList to aModelList
        If (sValue<>'') Set Value of hoCombo to sValue
        Set pbReady to True
        Send ShowStatus (SideName(Self)+" ("+ProviderName(hoAI)+"): "+sSource+"; default model"*sModelId)
    End_Procedure

    // id of the selected model; text typed into the combo is used as an id
    Function SelectedModelId Returns String
        String sValue
        Integer iCombo
        Handle hoCombo
        tAIModel[] aModelList
        Move (oSideModelCombo(Self)) to hoCombo
        Get Value of hoCombo to sValue
        Move (Trim(sValue)) to sValue
        If (sValue='') Function_Return ''
        Get Combo_Item_Matching of hoCombo sValue to iCombo
        Get paModelList to aModelList
        If (iCombo>=0 and iCombo<SizeOfArray(aModelList)) Function_Return aModelList[iCombo].id
        Function_Return sValue
    End_Function

End_Class

//=============================================================================
Deferred_View Activate_oAIDialogueDemo for ;
Object oAIDialogueDemo is a dbView
    Property Boolean pbInitialized False
    Property Boolean pbStarted False    // StartDialogue done (opening added)
    Property Boolean pbAutoRun False    // Start: keep running turns until done
    Property Boolean pbBusy False       // a turn is running
    Property Integer piTurnLimit 6
    // provider settings saved by ApplySideSettings
    Property Handle  phoSavedToolSet 0
    Property Boolean pbSavedSilent False
    Property Boolean pbSavedAuto True
    Property String  psSavedModel ''

    Set Border_Style to Border_Thick
    Set Size to 400 520
    Set Location to 2 2
    Set Label to "AI Dialogue Demo"
    Set piMinSize to 400 520

    //=========================================================================
    // dialogue and demo tools
    //=========================================================================
    Object oDemoTools is a cAIDemoToolSet
        Procedure OnToolActivity String sText
            Send LogActivity sText
        End_Procedure
    End_Object

    Object oDialogue is a cAIDialogue
        // the speaking side's settings go on its provider for this turn only
        Procedure OnBeforeSideTurn Integer iSide Handle hoAI
            Send ApplySideSettings iSide hoAI
        End_Procedure

        Procedure OnAfterSideTurn Integer iSide Handle hoAI
            Send RestoreSideSettings hoAI
        End_Procedure

        Procedure OnDialogueTurn Integer iTurn String sSpeaker String sText
            Send LogActivity ("turn"*String(iTurn)+":"*sSpeaker*"answered ("+String(Length(sText))+" characters)")
        End_Procedure
    End_Object

    // runs the turns one at a time so the view repaints and Stop works between turns
    Object oTurnTimer is a cTimer
        Set piTimeout to 100
        Procedure OnTimer
            Set pbEnabled to False
            Send RunNextTurn
        End_Procedure
    End_Object

    //=========================================================================
    // controls
    //=========================================================================
    Object oFirstSide is a cDialogueSideGroup
        Set Location to 2 2
        Set Label to "First participant (answers the topic)"
        Set psDefaultName to "Optimist"
        Set psDefaultProvider to "Claude"
        Set psDefaultPersona to "You are an enthusiastic optimist who sees the opportunities in every idea. Answer in at most 80 words. When you both agree, end your answer with the word AGREED."
    End_Object

    Object oSecondSide is a cDialogueSideGroup
        Set Location to 2 262
        Set Label to "Second participant"
        Set psDefaultName to "Skeptic"
        Set psDefaultProvider to "Grok"
        Set psDefaultPersona to "You are a friendly but critical skeptic who points out risks and costs. Answer in at most 80 words. When you both agree, end your answer with the word AGREED."
    End_Object

    Object oTopicEdit is a cTextEdit
        Set Location to 128 46
        Set Size to 30 472
        Set Label to "Topic:"
        Set Label_Col_Offset to 2
        Set Label_Justification_Mode to JMode_Right
        Set peAnchors to anTopLeftRight
    End_Object

    Object oMaxTurnsForm is a Form
        Set Location to 162 46
        Set Size to 12 30
        Set Label to "Max turns:"
        Set Label_Col_Offset to 2
        Set Label_Justification_Mode to JMode_Right
        Set Numeric_Mask 0 to 3 0
        Set Value to 6
    End_Object

    Object oStopPhraseForm is a Form
        Set Location to 162 136
        Set Size to 12 100
        Set Label to "Stop phrase:"
        Set Label_Col_Offset to 2
        Set Label_Justification_Mode to JMode_Right
    End_Object

    Object oPrefixCheck is a CheckBox
        Set Location to 163 246
        Set Size to 10 200
        Set Label to "Prefix relayed text with the speaker's name"
        Set Checked_State to True
    End_Object

    Object oStartButton is a Button
        Set Location to 178 2
        Set Label to "Start"
        Set Size to 14 60
        Procedure OnClick
            Send DoStart
        End_Procedure
    End_Object

    Object oStepButton is a Button
        Set Location to 178 66
        Set Label to "Step (one turn)"
        Set Size to 14 64
        Procedure OnClick
            Send DoStep
        End_Procedure
    End_Object

    Object oStopButton is a Button
        Set Location to 178 134
        Set Label to "Stop"
        Set Size to 14 50
        Procedure OnClick
            Send DoStop
        End_Procedure
    End_Object

    Object oResetButton is a Button
        Set Location to 178 188
        Set Label to "Reset"
        Set Size to 14 50
        Procedure OnClick
            Send DoReset
        End_Procedure
    End_Object

    Object oApproveButton is a Button
        Set Location to 178 300
        Set Label to "Approve pending"
        Set Size to 14 70
        Set Enabled_State to False
        Procedure OnClick
            Send DoDecide True
        End_Procedure
    End_Object

    Object oDeclineButton is a Button
        Set Location to 178 374
        Set Label to "Decline pending"
        Set Size to 14 70
        Set Enabled_State to False
        Procedure OnClick
            Send DoDecide False
        End_Procedure
    End_Object

    Object oStatusForm is a Form
        Set Location to 196 46
        Set Size to 12 472
        Set Label to "Status:"
        Set Label_Col_Offset to 2
        Set Label_Justification_Mode to JMode_Right
        Set Enabled_State to False
        Set peAnchors to anTopLeftRight
    End_Object

    Object oErrorForm is a Form
        Set Location to 210 46
        Set Size to 12 472
        Set Label to "Error:"
        Set Label_Col_Offset to 2
        Set Label_Justification_Mode to JMode_Right
        Set Enabled_State to False
        Set peAnchors to anTopLeftRight
    End_Object

    Object oTabs is a TabDialog
        Set Location to 226 2
        Set Size to 170 516
        Set peAnchors to anAll

        Object oTranscriptPage is a TabPage
            Set Label to "Transcript"
            Object oTranscriptEdit is a cTextEdit
                Set Location to 2 2
                Set Size to 150 508
                Set peAnchors to anAll
                Set Read_Only_State to True
            End_Object
        End_Object

        Object oActivityPage is a TabPage
            Set Label to "Activity / tools"
            Object oActivityEdit is a cTextEdit
                Set Location to 2 2
                Set Size to 150 508
                Set peAnchors to anAll
                Set Read_Only_State to True
            End_Object
        End_Object
    End_Object

    //=========================================================================
    // logic
    //=========================================================================
    Procedure ShowStatus String sText
        Set Value of oStatusForm to sText
    End_Procedure

    Procedure ShowError String sText
        Set Value of oErrorForm to sText
    End_Procedure

    Procedure LogActivity String sText
        String sOld
        Get Value of oActivityEdit to sOld
        If (sOld<>'') Move (sOld+Character(13)+Character(10)) to sOld
        Set Value of oActivityEdit to (sOld+String(CurrentDateTime())+"  "+sText)
    End_Procedure

    Procedure Activating
        Forward Send Activating
        If (not(pbInitialized(Self))) Begin
            Set pbInitialized to True
            Send ApplyDefaultTexts of oFirstSide
            Send ApplyDefaultTexts of oSecondSide
            Set Value of oTopicEdit to "Should a small family business move its accounting system to the cloud? Start the discussion with your opening view."
            Set Value of oStopPhraseForm to "AGREED"
        End
    End_Procedure

    Function SideGroup Integer iSide Returns Handle
        If (iSide=0) Function_Return (oFirstSide(Self))
        Function_Return (oSecondSide(Self))
    End_Function

    Function ProviderReady Handle hoAI Returns Boolean
        Function_Return (hoAI<>0 and (hoAI=ghoClaudeAI or hoAI=ghoChatGPTAI or hoAI=ghoGeminiAI or hoAI=ghoGrokAI))
    End_Function

    Function TopicText Returns String
        String sTopic
        Get Value of oTopicEdit to sTopic
        Function_Return (Trim(sTopic))
    End_Function

    // copies the participants and options onto oDialogue; False (with an error
    // shown) when a participant has no provider
    Function ConfigureDialogue Returns Boolean
        Handle hoFirst hoSecond
        Integer iMax
        String sStop
        Get SideAI of oFirstSide to hoFirst
        Get SideAI of oSecondSide to hoSecond
        If (not(ProviderReady(Self,hoFirst)) or not(ProviderReady(Self,hoSecond))) Begin
            Send ShowError "Select a provider for both participants."
            Function_Return False
        End
        Set phoFirstAI of oDialogue to hoFirst
        Set phoSecondAI of oDialogue to hoSecond
        Set psFirstLabel of oDialogue to (SideName(oFirstSide(Self)))
        Set psSecondLabel of oDialogue to (SideName(oSecondSide(Self)))
        Set pbPrefixLabels of oDialogue to (Checked_State(oPrefixCheck(Self)))
        Get Value of oStopPhraseForm to sStop
        Set psStopPhrase of oDialogue to (Trim(sStop))
        Set psUserLabel of (phoFirstConversation(oDialogue(Self))) to "Topic"
        Get Value of oMaxTurnsForm to iMax
        If (iMax<1) Move 6 to iMax
        Set piTurnLimit to iMax
        Function_Return True
    End_Function

    // the speaking side's persona, model and tools go on its provider for one turn
    // (called from oDialogue's OnBeforeSideTurn; its conversation is attached)
    Procedure ApplySideSettings Integer iSide Handle hoAI
        Handle hoSide hoConv
        String sModel sPrompt sCRLF
        Move (Character(13)+Character(10)) to sCRLF
        Get SideGroup iSide to hoSide
        Set phoSavedToolSet to (phoToolSet(hoAI))
        Set pbSavedSilent to (pbSilentErrors(hoAI))
        Set pbSavedAuto to (pbAutoExecuteTools(hoAI))
        Set psSavedModel to (psModelId(hoAI))

        Set pbSilentErrors of hoAI to True     // errors go to the Error line; confirmations defer
        Set pbAutoExecuteTools of hoAI to True
        If (UseTools(hoSide)) Set phoToolSet of hoAI to oDemoTools
        Else Set phoToolSet of hoAI to 0
        Get SelectedModelId of hoSide to sModel
        If (sModel<>'') Set psModelId of hoAI to sModel

        // the persona plus the context: the second side never sees the opening prompt
        Get Persona of hoSide to sPrompt
        If (sPrompt<>'') Move (sPrompt+sCRLF+sCRLF) to sPrompt
        Move (sPrompt+"You are "+SideName(hoSide)+", talking with "+SideName(SideGroup(Self,1-iSide))+". The topic is: "+TopicText(Self)) to sPrompt
        Get SideConversation of oDialogue iSide to hoConv
        Set psSystemPrompt of hoConv to sPrompt
        Send LogActivity (SideName(hoSide)+" is answering ("+ProviderName(hoAI)*psModelId(hoAI)+")")
    End_Procedure

    Procedure RestoreSideSettings Handle hoAI
        Set phoToolSet of hoAI to (phoSavedToolSet(Self))
        Set pbSilentErrors of hoAI to (pbSavedSilent(Self))
        Set pbAutoExecuteTools of hoAI to (pbSavedAuto(Self))
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

    Procedure ShowTranscript
        tAITranscriptEntry[] aEntries
        String sText sCRLF
        Integer i
        Move (Character(13)+Character(10)) to sCRLF
        Get paEntries of (phoTranscript(oDialogue(Self))) to aEntries
        For i from 0 to (SizeOfArray(aEntries)-1)
            Move (sText+"["+String(aEntries[i].dtWhen)+"]  "+aEntries[i].sSpeaker+":"+sCRLF+aEntries[i].sText+sCRLF+sCRLF) to sText
        Loop
        Set Value of oTranscriptEdit to sText
    End_Procedure

    Procedure UpdateButtons
        Boolean bWaiting bBusy
        Get pbBusy to bBusy
        Get IsWaitingForConfirmation of oDialogue to bWaiting
        Set Enabled_State of oApproveButton to (bWaiting and not(bBusy))
        Set Enabled_State of oDeclineButton to (bWaiting and not(bBusy))
        Set Enabled_State of oStartButton to (not(bBusy))
        Set Enabled_State of oStepButton to (not(bBusy))
    End_Procedure

    // status and error lines after a turn
    Procedure ShowTurnResult tAIResponse Response
        String sStatus sStopPhrase
        tAIToolCall[] aPending
        Integer i iDone

        Get piTurnsDone of oDialogue to iDone
        Move ("Turn"*String(iDone)+" of"*String(piTurnLimit(Self))+"  |  stop:"*StopReasonName(Self,Response.eStopReason)) to sStatus
        Move (sStatus+"  |  tokens in/out:"*String(Response.Usage.iInputTokens)+"/"+String(Response.Usage.iOutputTokens)) to sStatus
        If (Response.iToolIterations>1) Move (sStatus+"  |  tool round trips:"*String(Response.iToolIterations)) to sStatus

        Send ShowError (psLastError(oDialogue(Self)))
        Get PendingConfirmations of oDialogue to aPending
        If (SizeOfArray(aPending)>0) Begin
            Move (NextSideLabel(oDialogue(Self))+" wants to run:") to sStatus
            For i from 0 to (SizeOfArray(aPending)-1)
                Move (sStatus*aPending[i].sName+aPending[i].sArgumentsJson) to sStatus
            Loop
            Move (sStatus+"  -> Approve or Decline") to sStatus
        End
        Else If (pbStopped(oDialogue(Self)) and Response.eStopReason=AI_STOP_END_TURN) Begin
            Get psStopPhrase of oDialogue to sStopPhrase
            If (sStopPhrase<>'') Move (sStatus+"  |  stop phrase"*sStopPhrase*"found: finished") to sStatus
        End
        Else If (iDone>=piTurnLimit(Self) and not(pbStopped(oDialogue(Self)))) Move (sStatus+"  |  max turns reached") to sStatus
        Else If (not(pbStopped(oDialogue(Self)))) Move (sStatus+"  |  next:"*NextSideLabel(oDialogue(Self))) to sStatus
        Send ShowStatus sStatus
    End_Procedure

    // one turn of the side whose turn it is
    Procedure DoOneTurn
        tAIResponse Response
        If (pbBusy(Self)) Procedure_Return
        If (not(ConfigureDialogue(Self))) Begin
            Set pbAutoRun to False
            Procedure_Return
        End
        Set pbBusy to True
        Send UpdateButtons
        Send ShowError ''
        Send ShowStatus ("Waiting for"*NextSideLabel(oDialogue(Self))+"...")
        Get StepDialogue of oDialogue to Response
        Set pbBusy to False
        Send ShowTranscript
        Send ShowTurnResult Response
        Send UpdateButtons
    End_Procedure

    // timer tick while running: one turn, then schedule the next unless finished
    Procedure RunNextTurn
        If (not(pbAutoRun(Self))) Procedure_Return
        If (piTurnsDone(oDialogue(Self))>=piTurnLimit(Self)) Begin
            Set pbAutoRun to False
            Procedure_Return
        End
        Send DoOneTurn
        // a confirmation pause keeps pbAutoRun: Approve/Decline resumes the run
        If (IsWaitingForConfirmation(oDialogue(Self))) Procedure_Return
        If (pbStopped(oDialogue(Self)) or piTurnsDone(oDialogue(Self))>=piTurnLimit(Self)) Set pbAutoRun to False
        If (pbAutoRun(Self)) Set pbEnabled of oTurnTimer to True
    End_Procedure

    Function StartNew Returns Boolean
        String sTopic
        Get TopicText to sTopic
        If (sTopic='') Begin
            Send ShowError "Enter a topic first."
            Function_Return False
        End
        If (not(ConfigureDialogue(Self))) Function_Return False
        Send StartDialogue of oDialogue sTopic
        Set pbStarted to True
        Set Value of oActivityEdit to ''
        Send ShowTranscript
        Send ShowError ''
        Function_Return True
    End_Function

    // Start: a new dialogue, run until max turns, the stop phrase, an error or a pause
    Procedure DoStart
        If (pbBusy(Self)) Procedure_Return
        Set pbEnabled of oTurnTimer to False
        If (not(StartNew(Self))) Procedure_Return
        Set pbAutoRun to True
        Send ShowStatus "Starting..."
        Set pbEnabled of oTurnTimer to True
    End_Procedure

    // Step: one turn (starts a new dialogue first if needed); a further turn after
    // max turns or the stop phrase is allowed
    Procedure DoStep
        If (pbBusy(Self)) Procedure_Return
        Set pbAutoRun to False
        Set pbEnabled of oTurnTimer to False
        If (not(pbStarted(Self))) Begin
            If (not(StartNew(Self))) Procedure_Return
        End
        If (IsWaitingForConfirmation(oDialogue(Self))) Begin
            Send Info_Box "A tool call is waiting: press Approve pending or Decline pending."
            Procedure_Return
        End
        Send DoOneTurn
    End_Procedure

    // Stop: no further turns (a turn in progress finishes first)
    Procedure DoStop
        Set pbAutoRun to False
        Set pbEnabled of oTurnTimer to False
        Send StopDialogue of oDialogue
        Send ShowStatus ("Stopped after"*String(piTurnsDone(oDialogue(Self)))*"turns. Step continues, Start begins again.")
    End_Procedure

    Procedure DoReset
        If (pbBusy(Self)) Procedure_Return
        Send DoStop
        Send ResetDialogue of oDialogue
        Set pbStarted to False
        Set Value of oTranscriptEdit to ''
        Set Value of oActivityEdit to ''
        Send ShowStatus ''
        Send ShowError ''
        Send UpdateButtons
    End_Procedure

    // approve or decline every pending call, then the same side continues its turn;
    // a dialogue started with Start keeps running afterwards
    Procedure DoDecide Boolean bApprove
        tAIToolCall[] aPending
        Integer i
        Boolean bResume
        If (pbBusy(Self)) Procedure_Return
        Get PendingConfirmations of oDialogue to aPending
        If (SizeOfArray(aPending)=0) Begin
            Send Info_Box "No tool calls are waiting for confirmation."
            Procedure_Return
        End
        For i from 0 to (SizeOfArray(aPending)-1)
            If (bApprove) Begin
                Send ApproveToolCall of oDialogue aPending[i].sId
                Send LogActivity ("approved"*aPending[i].sName)
            End
            Else Begin
                Send DeclineToolCall of oDialogue aPending[i].sId "Declined by the user in the dialogue demo."
                Send LogActivity ("declined"*aPending[i].sName)
            End
        Loop
        Get pbAutoRun to bResume
        Send DoOneTurn
        If (IsWaitingForConfirmation(oDialogue(Self))) Procedure_Return   // paused again
        If (bResume and not(pbStopped(oDialogue(Self))) and piTurnsDone(oDialogue(Self))<piTurnLimit(Self)) Set pbEnabled of oTurnTimer to True
        Else Set pbAutoRun to False
    End_Procedure

Cd_End_Object
