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
                    Set Location to 10 66
                End_Object
            
                Object oRadio2 is a Radio
                    Set Label to "Gemini"
                    Set Size to 10 32
                    Set Location to 10 127
                End_Object
            
                Object oRadio3 is a Radio
                    Set Label to "Grok"
                    Set Size to 10 32
                    Set Location to 10 188
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
                    If (iToItem<>iFromItem) Send Combo_Fill_List of oSelectModel
                End_Procedure
        
                Object oSelectModel is a ComboForm
                    Property tAIModel[] paModelList
                    
                    Set Location to 9 262
                    Set Size to 12 100
                    Set Label to "Model:"
                    Set Label_Col_Offset to 2
                    Set Label_Justification_Mode to JMode_Right
                
                    Procedure Combo_Fill_List
                        // Fill the combo list with Send Combo_Add_Item
                        Send Combo_Delete_Data
                        tAIModel[] aModelList
                        Handle hoAI
                        Get phoAI to hoAI
                        Integer i iCnt
                        
                        If (hoAI) begin
                            Get ModelList of hoAi to aModelList
                            Set paModelList to aModelList
                            For i from 0 to (SizeOfArray(aModelList)-1)
                                Send Combo_Add_Item aModelList[i].display_name
                            Loop
                        End
                        
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
            
            
            End_Object

            Object oTextEdit1 is a cTextEdit
                Set Location to 32 2
                Set Size to 126 292
                Set peAnchors to anTopBottomLeft
            End_Object

            Object oCJGrid1 is a cCJGrid
                Set Location to 32 298
                Set Size to 126 100
                Set peAnchors to anAll

                Object oCJGridColumn1 is a cCJGridColumn
                    Set piWidth to 100
                    Set psCaption to "Files"
                End_Object
            End_Object
        End_Object

        Object oSplitterContainerChild2 is a cSplitterContainerChild
            Object oResponse is a cWebView2Browser
                Set psLocationURL to "https://www.dataaccess.com/"
                Set Location to 0 0
                Set Size to 189 399
                Set peAnchors to anAll
            End_Object
        End_Object
    End_Object

Cd_End_Object
