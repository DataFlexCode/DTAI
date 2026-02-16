Use Windows.pkg
Use DFClient.pkg

Use chatgptai.pkg
Use geminiai.pkg
Use grokai.pkg
Use claudeai.pkg

Use cTextEdit.pkg
Use cLocalWebControlHost.pkg
Use cWebHtmlBox.pkg

Deferred_View Activate_oAIChatExample for ;
Object oAIChatExample is a dbView
    Property Integer piSelectedAI 0
    Property Handle phoAI 0
    Property String psTranscriptRelay ""
    Property String psTranscriptMarkdown ""

    Set Border_Style to Border_Thick
    Set Size to 320 460
    Set Location to 2 2
    Set Label to "AI Chat Example"
    Set piMinSize to 260 360

    Object oSelectAI is a RadioGroup
        Set Size to 26 456
        Set Location to 2 2
        Set Label to 'Select AI...'

        Object oRadio0 is a Radio
            Set Label to "ChatGPT"
            Set Size to 10 40
            Set Location to 10 5
        End_Object

        Object oRadio1 is a Radio
            Set Label to "Claude"
            Set Size to 10 32
            Set Location to 10 53
        End_Object

        Object oRadio2 is a Radio
            Set Label to "Gemini"
            Set Size to 10 32
            Set Location to 10 93
        End_Object

        Object oRadio3 is a Radio
            Set Label to "Grok"
            Set Size to 10 32
            Set Location to 10 133
        End_Object

        Procedure Notify_Select_State Integer iToItem Integer iFromItem
            Handle hoAI

            Forward Send Notify_Select_State iToItem iFromItem
            Set piSelectedAI to iToItem

            If (iToItem=0) Move ghoChatGPTAI to hoAI
            If (iToItem=1) Move ghoClaudeAI to hoAI
            If (iToItem=2) Move ghoGeminiAI to hoAI
            If (iToItem=3) Move ghoGrokAI to hoAI

            Set phoAI to hoAI
            Send RenderConversation
        End_Procedure
    End_Object

    Object oPromptTextEdit is a cTextEdit
        Set Location to 31 2
        Set Size to 70 456
        Set peAnchors to anTopLeftRight
    End_Object

    Object oSubmitButton is a Button
        Set Location to 104 2
        Set Label to "Send"
        Set Size to 14 70
        Set peAnchors to anTopLeft

        Procedure OnClick
            Send SubmitPrompt
        End_Procedure
    End_Object

    Object oConversationHost is a cLocalWebControlHost
        Set Location to 120 2
        Set Size to 198 456
        Set peAnchors to anAll

        Object oConversationHtml is a cWebHtmlBox
        End_Object
    End_Object

    Procedure Activating
        Handle hoAI

        Forward Send Activating

        Get phoAI to hoAI
        If (hoAI=0) Begin
            // Codex's error
            // Send Select_State of oSelectAI 0
            Set Current_Radio of oSelectAI to 0
        End

        Send RenderConversation
    End_Procedure

    Procedure AppendTranscript String sRole String sText
        String sRelay sMarkdown sCRLF

        Move (Character(13)+Character(10)) to sCRLF
        Get psTranscriptRelay to sRelay
        Get psTranscriptMarkdown to sMarkdown

        If (sRelay<>'') Move (sRelay+sCRLF+sCRLF) to sRelay
        Move (sRelay+sRole+': '+sText) to sRelay

        If (sMarkdown<>'') Move (sMarkdown+sCRLF+sCRLF) to sMarkdown
        Move (sMarkdown+'**'+sRole+':**'+sCRLF+sText) to sMarkdown

        Set psTranscriptRelay to sRelay
        Set psTranscriptMarkdown to sMarkdown
    End_Procedure

    Procedure RenderConversation
        Handle hoAI
        String sMarkdown sHtml

        Get phoAI to hoAI
        Get psTranscriptMarkdown to sMarkdown

        If (sMarkdown='') Begin
            Move '_No messages yet._' to sMarkdown
        End

        If (hoAI) Begin
            Get Markdown2Html of hoAI sMarkdown to sHtml
        End
        Else Begin
            Move ('<p>'+sMarkdown+'</p>') to sHtml
        End

        // Set psHtml of oConversationHtml to sHtml
        Send UpdateHtml of oConversationHtml sHtml
    End_Procedure

    Procedure SubmitPrompt
        String sPrompt sRelayPrompt sAssistantReply
        tAIAttachment[] aAttachments
        tAIResponse Response
        Handle hoAI hoRequest

        Get phoAI to hoAI
        If (hoAI=0) Begin
            Send Stop_Box "Please select an AI provider first."
            Procedure_Return
        End

        Get Value of oPromptTextEdit to sPrompt
        Move (Trim(sPrompt)) to sPrompt
        If (sPrompt='') Procedure_Return

        Send AppendTranscript 'User' sPrompt
        Get psTranscriptRelay to sRelayPrompt

        Get CreateRequest of hoAI sRelayPrompt aAttachments to hoRequest
        Get MakeRequest of hoAI hoRequest to Response
        Send Destroy of hoRequest
        
        If (SizeOfArray(Response.Choices)>0 and SizeOfArray(Response.Choices[0].ContentParts)>0) Begin
            Move Response.Choices[0].ContentParts[0].sText to sAssistantReply
            Send AppendTranscript 'Assistant' sAssistantReply
            Set Value of oPromptTextEdit to ''
            Send RenderConversation
        End
        Else Begin
            Send Stop_Box 'No response received!'
            Send RenderConversation
        End
    End_Procedure

Cd_End_Object
