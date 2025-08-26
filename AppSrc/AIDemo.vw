Use Windows.pkg
Use DFClient.pkg

Use chatgptai.pkg
Use geminiai.pkg
Use grokai.pkg
Use claudeai.pkg
Use cSplitterContainer.pkg
Use cTextEdit.pkg
Use cCJGrid.pkg
Use cCJGridColumn.pkg
Use cWebView2Browser.pkg

Deferred_View Activate_oAIDemo for ;
Object oAIDemo is a dbView
    Property Integer piSelectedAI 0
    Property Handle phoAI 0
    
    
    Set Border_Style to Border_Thick
    Set Size to 350 400
    Set Location to 2 2
    Set Label to "AI Prompt Demo"
    Set piMinSize to 350 400

    Object oSplitterContainer1 is a cSplitterContainer
        Set pbSplitVertical to False
        Object oSplitterContainerChild1 is a cSplitterContainerChild
            Set pbAcceptDropFiles to True
            Object oSelectAI is a RadioGroup
                Set Size to 26 396
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
                    Integer iMaxTokens
                    Forward Send Notify_Select_State iToItem iFromItem
                    Set piSelectedAI to iToItem
                    If (iToItem=0) Move ghoChatGPTAI to hoAI
                    If (iToItem=1) Move ghoClaudeAI to hoAI
                    If (iToItem=2) Move ghoGeminiAI to hoAI
                    If (iToItem=3) Move ghoGrokAI to hoAI
                    Set phoAI to hoAI
                    If (iToItem<>iFromItem) Begin
                        Send Combo_Fill_List of oSelectModel
                        // Update max tokens form when AI changes
                        If (hoAI) Begin
                            Get piMaxTokens of hoAI to iMaxTokens
                            Set Value of oMaxTokensForm to iMaxTokens
                        End
                    End
                End_Procedure
        
                Object oSelectModel is a ComboForm
                    Property tAIModel[] paModelList
                    
                    Set Location to 9 197
                    Set Size to 12 100
                    Set Label to "Model:"
                    Set Label_Col_Offset to 2
                    Set Label_Justification_Mode to JMode_Right
                
                    Procedure Combo_Fill_List
                        tAIModel[] aModelList
                        Handle hoAI
                        Integer i iCnt
                        String sModelId sValue
                        
                        Get phoAi to hoAi
                        If (hoAI) Get psModelId of hoAI to sModelId

                        Send Combo_Delete_Data
                        
                        If (hoAI) begin
                            Get ModelList of hoAi to aModelList
                            Set paModelList to aModelList
                            For i from 0 to (SizeOfArray(aModelList)-1)
                                Send Combo_Add_Item aModelList[i].display_name
                                If (sModelId=aModelList[i].id) Move aModelList[i].display_name to sValue
                            Loop
                        End
                        If (sValue<>'') Set Value to sValue
                    End_Procedure
                  
                    // OnChange is called on every changed character
                    Procedure OnChange
                        String sValue
                        Integer iCombo
                        Handle hoAI
                        tAIModel[] aModelList
                        
                        Get Value to sValue 
                        Get Combo_Item_Matching sValue to iCombo
                        Get paModelList to aModelList    
                        Get phoAI to hoAI
                        
                        Set psModelId of hoAi to aModelList[iCombo].id
                    End_Procedure
                End_Object
                
                Object oMaxTokensForm is a Form
                    Set Location to 9 355
                    Set Size to 12 32
                    Set Label to "Max Tokens:"
                    Set Label_Col_Offset to 2
                    Set Label_Justification_Mode to JMode_Right
                    Set Form_Datatype to Mask_Numeric_Window
                    
                    // OnChange is called when the value changes
                    Procedure OnChange
                        Integer iMaxTokens
                        Handle hoAI
                        
                        Get Value to iMaxTokens
                        Get phoAI to hoAI
                        
                        If (hoAI) Set piMaxTokens of hoAI to iMaxTokens
                    End_Procedure
                End_Object
            
            
            End_Object

            Object oPromptTextEdit is a cTextEdit
                Set Location to 32 2
                Set Size to 126 292
                Set peAnchors to anTopBottomLeft
            End_Object

            Object oFileAttachmentGrid is a cCJGrid
                Set Location to 32 298
                Set Size to 126 100
                Set peAnchors to anAll
                Set pbReadOnly to True

                Set piSelectedRowBackColor to clYellow
                Set piSelectedRowForeColor to clBlack
                // color when control does have focus
                Set piHighlightBackColor to clYellow
                Set piHighlightForeColor to clBlack
                // color of current cell when control has the focus
                Set pbSelectionEnable to True
                Set pbMultiSelectionMode to False
                Set piFocusCellBackColor to clYellow
                Set piFocusCellForeColor to clBlack

                Object oFileAttachmentGridColumn is a cCJGridColumn
                    Set piWidth to 100
                    Set psCaption to "Files"
                End_Object

                                
                Procedure Removefile
                    Handle hoDataSource
                    tDataSourceRow[] GridData
                    Integer iRow
                                        
                    Get phoDataSource to hoDataSource
                    Get DataSource of hoDataSource to GridData
                    Get SelectedRow of hoDataSource to iRow
                    Move (RemoveFromArray(GridData,iRow)) to GridData
                    If (SizeOfArray(GridData)=0) Send InitializeData GridData
                    Else Send ReInitializeData GridData False
                    
                End_Procedure

                Procedure OnRowDoubleClick Integer iRow Integer iCol
                    Forward Send OnRowDoubleClick iRow iCol
                    tDataSourceRow[] GridData
                    Handle hoDataSource
                                        
                    Get phoDataSource to hoDataSource
                    Get DataSource of hoDataSource to GridData
                    Get SelectedRow of hoDataSource to iRow
                    If (iRow>=0) Send DoStartDocument "OPEN" GridData[iRow].sValue[0]
                End_Procedure

                On_Key Key_Delete Send RemoveFile
                
            End_Object

            Object oSubmitButton is a Button
                Set Location to 160 244
                Set Label to "Submit"
                Set Size to 12 50
            
                // fires when the button is clicked
                Procedure OnClick
                    Send SubmitPrompt (oPromptTextEdit(Self)) (oFileAttachmentGrid(Self))
                End_Procedure
            
            End_Object

            procedure OnFileDropped String sFilename
                tDataSourceRow[] GridData
                handle hoDataSource
                Get phoDataSource of oFileAttachmentGrid to hoDataSource
                get DataSource of hoDataSource to GridData
                Move sFilename to GridData[Sizeofarray(GridData)].sValue[0]
                Send ReinitializeData of oFileAttachmentGrid GridData False
            End_Procedure
        End_Object

        Object oSplitterContainerChild2 is a cSplitterContainerChild
            Object oTabDialog1 is a TabDialog
                Set Location to 0 0
                Set Size to 173 399
                Set peAnchors to anAll

                Object oTabPage1 is a TabPage
                    Set Label to 'Response'

                    Object oResponseHtml is a cWebView2Browser
                        Set psLocationURL to "https://www.dataaccess.com/"
                        Set Location to 0 0
                        Set Size to 161 396
                        Set peAnchors to anAll
                    End_Object
                End_Object

                Object oTabPage2 is a TabPage
                    Set Label to 'HTML Source'

                    Object oHTMLSource is a cTextEdit
                        Set Location to 0 0
                        Set Size to 161 396
                        Set peAnchors to anAll
                        Set psTypeFace to "Consolas"
                    End_Object
                End_Object

                Object oTabPage3 is a TabPage
                    Set Label to 'Raw Response'

                    Object oRawResponse is a cTextEdit
                        Set Location to 0 0
                        Set Size to 161 396
                        Set peAnchors to anAll
                        Set psTypeFace to "Consolas"
                    End_Object
                End_Object
            End_Object
        End_Object
    End_Object
    
    Procedure Activating
        Handle hoAI
        Integer iMaxTokens
        Forward Send Activating
        
        // Initialize the max tokens form with the current AI's max tokens
        Get phoAI to hoAI
        If (hoAI) Begin
            Get piMaxTokens of hoAI to iMaxTokens
            Set Value of (oMaxTokensForm(oSelectAI(Self))) to iMaxTokens
        End
    End_Procedure

    Procedure SubmitPrompt handle hoPromptTextEdit handle hoFileAttachmentGrid
        String sPrompt
        String sFileAttachments sHtml
        Handle hoDataSource hoRequest
        integer i iCnt
        tDataSourceRow[] GridData
        String[] asFileAttachments
        tAIAttachment[] aAttachments
        tAIResponse Response
        handle hoAI

        get phoAI to hoAI
        // text prompt
        Get Value of hoPromptTextEdit to sPrompt

        // file attachments
        get phoDataSource of hoFileAttachmentGrid to hoDataSource
        get DataSource of hoDataSource to GridData
        for i from 0 to (Sizeofarray(GridData)-1)
            Move GridData[i].sValue[0] to asFileAttachments[i]
            Get CreateAttachment of hoAI asFileAttachments[i] to aAttachments[i]
        loop
        
        Get CreateRequest of hoAi sPrompt aAttachments to hoRequest

        // debugging purposes, take out or log in a console
        // Set peWhiteSpace of hoRequest to jpWhitespace_Pretty
        // Get Stringify of hoRequest to sRequest
        
        
        Get MakeRequest of hoAi hoRequest to Response
        If (SizeOfArray(Response.Choices)>0) Begin
            Get Markdown2Html of hoAi Response.Choices[0].ContentParts[0].sText to sHtml
            Set Value of oRawResponse to Response.Choices[0].ContentParts[0].sText 
            Set value of oHTMLSource to sHtml
            Send NavigateToString of oResponseHtml sHtml
        End
        Else Begin
            Send Stop_Box "No response received!"
        End
    End_Procedure

Cd_End_Object