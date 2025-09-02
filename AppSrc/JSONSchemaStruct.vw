Use Windows.pkg
Use DFClient.pkg
Use cSplitterContainer.pkg
Use cTextEdit.pkg
Use cJSON_Mixin.pkg

Deferred_View Activate_oJSONSchemaStruct for ;
Object oJSONSchemaStruct is a dbView
    Property String psCurrentFile ""
    Property Handle phoJsonSchema 0
    
    Set Border_Style to Border_Thick
    Set Size to 450 600
    Set Location to 2 2
    Set Label to "JSON Schema to DataFlex Struct Generator"
    Set piMinSize to 450 600

    Object oSplitterContainer1 is a cSplitterContainer
        Set pbSplitVertical to False
        Set piSplitterLocation to 120
        
        Object oSplitterContainerChild1 is a cSplitterContainerChild
            Set pbAcceptDropFiles to True
            
            Object oInstructionGroup is a Group
                Set Size to 50 596
                Set Location to 2 2
                Set Label to "Instructions"
                
                Object oInstructionText is a TextBox
                    Set Size to 35 590
                    Set Location to 10 5
                    Set Label to "Drag and drop a JSON Schema file (.json) onto this area to generate DataFlex struct definitions."
                    Set Auto_Size_State to False
                    Set Enabled_State to False
                End_Object
            End_Object
            
            Object oCurrentFileGroup is a Group
                Set Size to 60 596
                Set Location to 55 2
                Set Label to "Current File"
                
                Object oCurrentFileText is a Form
                    Set Size to 12 580
                    Set Location to 15 8
                    Set Label to "File:"
                    Set Label_Col_Offset to 2
                    Set Label_Justification_Mode to JMode_Right
                    Set Enabled_State to False
                End_Object
                
                Object oGenerateButton is a Button
                    Set Size to 14 100
                    Set Location to 35 8
                    Set Label to "Generate Struct"
                    Set Enabled_State to False
                    
                    Procedure OnClick
                        Send GenerateStructFromSchema
                    End_Procedure
                End_Object
                
                Object oClearButton is a Button
                    Set Size to 14 80
                    Set Location to 35 115
                    Set Label to "Clear"
                    
                    Procedure OnClick
                        Send ClearAll
                    End_Procedure
                End_Object
            End_Object
            
            procedure OnFileDropped String sFilename
                Set psCurrentFile to sFilename
                Set Value of oCurrentFileText to sFilename
                Set Enabled_State of oGenerateButton to True
                Send LoadJsonSchema sFilename
            End_Procedure
        End_Object

        Object oSplitterContainerChild2 is a cSplitterContainerChild
            Object oSplitterContainer2 is a cSplitterContainer
                Set pbSplitVertical to False
                Set piSplitterLocation to 150
                
                Object oSplitterContainerChild3 is a cSplitterContainerChild
                    Object oSchemaPreviewGroup is a Group
                        Set Size to 148 594
                        Set Location to 0 0
                        Set Label to "JSON Schema Preview"
                        Set peAnchors to anAll
                        
                        Object oSchemaPreview is a cTextEdit
                            Set Size to 130 588
                            Set Location to 12 3
                            Set peAnchors to anAll
                            Set psTypeFace to "Consolas"
                        End_Object
                    End_Object
                End_Object
                
                Object oSplitterContainerChild4 is a cSplitterContainerChild
                    Object oStructCodeGroup is a Group
                        Set Size to 148 594
                        Set Location to 0 0
                        Set Label to "Generated DataFlex Struct"
                        Set peAnchors to anAll
                        
                        Object oStructCode is a cTextEdit
                            Set Size to 110 588
                            Set Location to 12 3
                            Set peAnchors to anAll
                            Set psTypeFace to "Consolas"
                        End_Object
                        
                        Object oCopyButton is a Button
                            Set Size to 14 100
                            Set Location to 128 3
                            Set Label to "Copy to Clipboard"
                            Set peAnchors to anBottomLeft
                            
                            Procedure OnClick
                                String sCode
                                Get Value of oStructCode to sCode
                                If (sCode <> "") Begin
//                                    Send SetClipboard sCode
                                    Direct_Output "CLIPBOARD:"
                                    Write sCode
                                    Close_Output
                                    Send Info_Box "Struct code copied to clipboard!"
                                End
                                Else Begin
                                    Send Info_Box "No struct code to copy."
                                End
                            End_Procedure
                        End_Object
                    End_Object
                End_Object
            End_Object
        End_Object
    End_Object

     Function Capitalize String sText Returns String
         String sFirst sRest
         If (Length(sText) = 0) Function_Return sText
         Move (Uppercase(Left(sText, 1))) to sFirst
         If (Length(sText) > 1) Move (Right(sText, Length(sText) - 1)) to sRest
         Function_Return (sFirst + sRest)
     End_Function
     
    
     Procedure LoadJsonSchema String sFilename
         Boolean bOk
         String sContent
         Handle hoJson
         UChar[] uaJson
         
         // Clear previous content
         Set Value of oSchemaPreview to ""
         Set Value of oStructCode to ""
         
         // Read the JSON file
         Direct_Input sFilename
         If (not(err)) Begin
             Read_Block uaJson -1
             Close_Input 
             
             // Convert UChar array to string for display
             Move (UCharArrayToString(uaJson)) to sContent
             
             // Display the JSON content
             Set Value of oSchemaPreview to sContent
             
             // Parse JSON
             Get Create (RefClass(cJsonObject)) to hoJson
             Get ParseUtf8 of hoJson uaJson to bOk
             
             // assume valid
             If (bOk) Begin
                 Set phoJsonSchema to hoJson
             End
             Else Begin
                 Send Info_Box "Invalid JSON format in file."
                 Send Destroy of hoJson
                 Set phoJsonSchema to 0
             End
         End
         Else Begin
             Send Info_Box ("Could not read file: " + sFilename)
         End
     End_Procedure
    
    Procedure GenerateStructFromSchema
        Handle hoJson
        String sStructCode
        
        Get phoJsonSchema to hoJson
        If (hoJson = 0) Begin
            Send Info_Box "No valid JSON schema loaded."
            Procedure_Return
        End
        
        Get GenerateStructCode hoJson to sStructCode
        Set Value of oStructCode to sStructCode
    End_Procedure
    
     Function GenerateStructCode Handle hoJson Returns String
         String sStructName sResult sProperties sNestedStructs
         
         // Get struct name from schema title or use default
         Get MemberValue of hoJson "title" to sStructName
         If (sStructName = "") Begin
             Move "tGeneratedStruct" to sStructName
         End
         Else Begin
             // Remove spaces and special characters from title
             Move (Replaces(" ", sStructName, "")) to sStructName
             Move (Replaces("-", sStructName, "")) to sStructName
             Move (Replaces("_", sStructName, "")) to sStructName
             Move ("t" + sStructName) to sStructName
         End
         
         // Generate nested structs first (they need to be defined before use)
         Get GenerateNestedStructs hoJson "" to sNestedStructs
         
         // Start with nested structs
         Move "" to sResult
         If (sNestedStructs <> "") Begin
             Move ("// Nested Structs (defined first):" + (Character(13)) + (Character(10))) to sResult
             Move (sResult + sNestedStructs + (Character(13)) + (Character(10))) to sResult
         End
         
         // Add the main struct last
         Move (sResult + "// Main Struct:" + (Character(13)) + (Character(10))) to sResult
         Move (sResult + "Struct " + sStructName + (Character(13)) + (Character(10))) to sResult
         
         // Process properties
         Get ProcessPropertiesWithPrefix hoJson 1 "" to sProperties
         Move (sResult + sProperties) to sResult
         
         // End the struct
         Move (sResult + "End_Struct" + (Character(13)) + (Character(10))) to sResult
         
         Function_Return sResult
     End_Function
    
     Function ProcessPropertiesWithPrefix Handle hoJson Integer iIndentLevel String sPrefix Returns String
         Handle hoProperties hoProperty
         String sResult sPropertyName sType sIndent sComment
         Integer i iCount
         Boolean bHasProperties
         
         Move "" to sResult
         Move (Repeat("    ", iIndentLevel)) to sIndent
         
         // Check if properties member exists
         Get HasMember of hoJson "properties" to bHasProperties
         If (not(bHasProperties)) Begin
             // Debug: add a comment showing what members exist
             Move (sResult + sIndent + "// No 'properties' found in schema" + (Character(13)) + (Character(10))) to sResult
             Function_Return sResult
         End
         
         // Get the properties object
         Get Member of hoJson "properties" to hoProperties
         If (hoProperties = 0) Begin
             Move (sResult + sIndent + "// Properties object is null" + (Character(13)) + (Character(10))) to sResult
             Function_Return sResult
         End
         
         // Iterate through all properties
         Get MemberCount of hoProperties to iCount
         If (iCount = 0) Begin
             Move (sResult + sIndent + "// Properties object is empty" + (Character(13)) + (Character(10))) to sResult
         End
         
         For i from 0 to (iCount - 1)
             Get MemberNameByIndex of hoProperties i to sPropertyName
             Get MemberByIndex of hoProperties i to hoProperty
             
             Get ProcessSinglePropertyWithPrefix hoProperty sPropertyName iIndentLevel sPrefix to sType
             If (sType <> "") Begin
                 // Add description as comment if available
                 Get AddPropertyComment hoProperty to sComment
                 
                 Move (sResult + sIndent + sType + " " + sPropertyName + sComment) to sResult
                 Move (sResult + (Character(13)) + (Character(10))) to sResult
             End
             
             Send Destroy of hoProperty
         Loop
         
         Send Destroy of hoProperties
         Function_Return sResult
     End_Function
    
     Function ProcessProperties Handle hoJson Integer iIndentLevel Returns String
         Function_Return (ProcessPropertiesWithPrefix(Self, hoJson, iIndentLevel, ""))
     End_Function
     
    
     Function ProcessSinglePropertyWithPrefix Handle hoProperty String sPropertyName Integer iIndentLevel String sPrefix Returns String
         String sType sItemType sFirstType
         Handle hoItems hoAnyOf hoOneOf hoTypeArray
         Integer i iCount iTypeCount
         
         // Check if type is an array (like ["string", "null"])
         Get Member of hoProperty "type" to hoTypeArray
         If (hoTypeArray <> 0) Begin
             Get JsonType of hoTypeArray to i
             If (i = jsonTypeArray) Begin
                 Get MemberCount of hoTypeArray to iTypeCount
                 If (iTypeCount > 0) Begin
                     Get MemberByIndex of hoTypeArray 0 to hoItems
                     Get JsonValue of hoItems to sFirstType
                     Send Destroy of hoItems
                     Send Destroy of hoTypeArray
                     Move sFirstType to sType
                 End
                 Else Begin
                     Send Destroy of hoTypeArray
                     Move "string" to sType
                 End
             End
             Else Begin
                 Get JsonValue of hoTypeArray to sType
                 Send Destroy of hoTypeArray
             End
         End
         Else Begin
             Get MemberValue of hoProperty "type" to sType
         End
        
        // Handle different JSON schema types
        Case Begin
            Case (sType = "string")
                Function_Return "String"
                Case Break
                
            Case (sType = "integer")
                Function_Return "Integer"
                Case Break
                
            Case (sType = "number")
                Function_Return "Number"
                Case Break
                
            Case (sType = "boolean")
                Function_Return "Boolean"
                Case Break
                
             Case (sType = "array")
                 Get Member of hoProperty "items" to hoItems
                 If (hoItems <> 0) Begin
                     Get MemberValue of hoItems "type" to sItemType
                     If (sItemType = "object") Begin
                         Send Destroy of hoItems
                         Function_Return ("t" + sPrefix + (Capitalize(Self,sPropertyName)) + "Item[]")
                     End
                     Else Begin
                         Get ProcessSinglePropertyWithPrefix hoItems "items" iIndentLevel sPrefix to sItemType
                         Send Destroy of hoItems
                         If (sItemType <> "") Begin
                             Function_Return (sItemType + "[]")
                         End
                     End
                 End
                 Function_Return "String[]"  // Default for arrays
                 Case Break
                
             Case (sType = "object")
                 // For nested objects, generate a struct name based on full prefix path
                 Function_Return ("t" + sPrefix + (Capitalize(Self, sPropertyName)))
                 Case Break
                
            Case (sType = "")
                // Check for anyOf/oneOf
                Get Member of hoProperty "anyOf" to hoAnyOf
                Get Member of hoProperty "oneOf" to hoOneOf
                
                 If (hoAnyOf <> 0) Begin
                     Send Destroy of hoAnyOf
                     Function_Return "Variant"
                 End
                 
                 If (hoOneOf <> 0) Begin
                     Send Destroy of hoOneOf
                     Function_Return "Variant"
                 End
                
                Function_Return "String"  // Default fallback
                Case Break
                
            Case Else
                Function_Return "String"  // Default for unknown types
                Case Break
        Case End
     End_Function

     Function ProcessSingleProperty Handle hoProperty String sPropertyName Integer iIndentLevel Returns String
         Function_Return (ProcessSinglePropertyWithPrefix(Self, hoProperty, sPropertyName, iIndentLevel, ""))
     End_Function
     
     
    
     Function ProcessSinglePropertyType Handle hoProperty Returns String
         String sType sFirstType
         Handle hoTypeArray hoItems
         Integer i iTypeCount
         
         // Check if type is an array (like ["array", "null"])
         Get Member of hoProperty "type" to hoTypeArray
         If (hoTypeArray <> 0) Begin
             Get JsonType of hoTypeArray to i
             If (i = jsonTypeArray) Begin
                 Get MemberCount of hoTypeArray to iTypeCount
                 If (iTypeCount > 0) Begin
                     Get MemberByIndex of hoTypeArray 0 to hoItems
                     Get JsonValue of hoItems to sFirstType
                     Send Destroy of hoItems
                     Send Destroy of hoTypeArray
                     Function_Return sFirstType
                 End
                 Else Begin
                     Send Destroy of hoTypeArray
                     Function_Return "string"
                 End
             End
             Else Begin
                 Get JsonValue of hoTypeArray to sType
                 Send Destroy of hoTypeArray
                 Function_Return sType
             End
         End
         Else Begin
             Get MemberValue of hoProperty "type" to sType
             Function_Return sType
         End
     End_Function
     
     Function AddPropertyComment Handle hoProperty Returns String
         String sDescription sComment
         Boolean bDescr
         
         Get HasMember of hoProperty "description" to bDescr
         If (bDescr) Begin        
             Get MemberValue of hoProperty "description" to sDescription
         End
         
         If (sDescription <> "") Begin
             Move ("  // " + sDescription) to sComment
             Function_Return sComment
         End
         
         Function_Return ""
     End_Function
     
     Function GenerateNestedStructs Handle hoJson String sPrefix Returns String
         Handle hoProperties hoProperty hoNestedProps
         String sResult sPropertyName sType sNestedStructName sNestedStruct sCurrentStruct
         Integer i iCount
         Boolean bHasProperties
         Handle hoItems
         String sItemType
         
         Move "" to sResult
         
         // Check if this JSON object has properties
         Get HasMember of hoJson "properties" to bHasProperties
         If (not(bHasProperties)) Function_Return sResult
         
         // Get the properties object
         Get Member of hoJson "properties" to hoProperties
         If (hoProperties = 0) Function_Return sResult
         
         // First pass: recursively generate the deepest nested structs
         Get MemberCount of hoProperties to iCount
         For i from 0 to (iCount - 1)
             Get MemberNameByIndex of hoProperties i to sPropertyName
             Get MemberByIndex of hoProperties i to hoProperty
             
             // Use the same type detection logic as ProcessSingleProperty
             Get ProcessSinglePropertyType hoProperty to sType
             If (sType = "object") Begin
                 // Generate struct name
                 Move (sPrefix + (Capitalize(Self,sPropertyName))) to sNestedStructName
                 
                 // Recursively generate nested structs for this object first (deepest first)
                 Get GenerateNestedStructs hoProperty (sNestedStructName) to sNestedStruct
                 Move (sResult + sNestedStruct) to sResult
             End
             Else If (sType = "array") Begin
                 
                 // Check if this is an array of objects
                 Get Member of hoProperty "items" to hoItems
                 If (hoItems <> 0) Begin
                     Get MemberValue of hoItems "type" to sItemType
                     If (sItemType = "object") Begin
                         // Generate struct for array items
                         Move (sPrefix + (Capitalize(Self,sPropertyName)) + "Item") to sNestedStructName
                         
                         // Recursively generate nested structs for this array item object first
                         Get GenerateNestedStructs hoItems (sNestedStructName) to sNestedStruct
                         Move (sResult + sNestedStruct) to sResult
                     End
                     Send Destroy of hoItems
                 End
             End
             
             Send Destroy of hoProperty
         Loop
         
         // Second pass: generate structs for this level (after all deeper structs are defined)
         Get MemberCount of hoProperties to iCount
         For i from 0 to (iCount - 1)
             Get MemberNameByIndex of hoProperties i to sPropertyName
             Get MemberByIndex of hoProperties i to hoProperty
             
             // Use the same type detection logic as ProcessSingleProperty
             Get ProcessSinglePropertyType hoProperty to sType
             If (sType = "object") Begin
                 // Generate struct name
                 Move (sPrefix + (Capitalize(Self,sPropertyName))) to sNestedStructName
                 
                 // Create the nested struct
                 Move (sResult + "Struct t" + sNestedStructName + (Character(13)) + (Character(10))) to sResult
                 
                 // Process the nested object's properties
                 Get ProcessPropertiesWithPrefix hoProperty 1 sNestedStructName to sNestedStruct
                 Move (sResult + sNestedStruct) to sResult
                 
                 Move (sResult + "End_Struct" + (Character(13)) + (Character(10)) + (Character(13)) + (Character(10))) to sResult
             End
             Else If (sType = "array") Begin
                 
                 // Check if this is an array of objects
                 Get Member of hoProperty "items" to hoItems
                 If (hoItems <> 0) Begin
                     Get MemberValue of hoItems "type" to sItemType
                     If (sItemType = "object") Begin
                         // Generate struct for array items
                         Move (sPrefix + (Capitalize(Self,sPropertyName)) + "Item") to sNestedStructName
                         
                         Move (sResult + "Struct t" + sNestedStructName + (Character(13)) + (Character(10))) to sResult
                         
                         // Process the array item object's properties
                         Get ProcessPropertiesWithPrefix hoItems 1 sNestedStructName to sNestedStruct
                         Move (sResult + sNestedStruct) to sResult
                         
                         Move (sResult + "End_Struct" + (Character(13)) + (Character(10)) + (Character(13)) + (Character(10))) to sResult
                     End
                     Send Destroy of hoItems
                 End
             End
             
             Send Destroy of hoProperty
         Loop
         
         Send Destroy of hoProperties
         Function_Return sResult
     End_Function
    
    Procedure ClearAll
        Set psCurrentFile to ""
        Set Value of oCurrentFileText to ""
        Set Value of oSchemaPreview to ""
        Set Value of oStructCode to ""
        Set Enabled_State of oGenerateButton to False
        
        If (phoJsonSchema(Self) <> 0) Begin
            Send Destroy of (phoJsonSchema(Self))
            Set phoJsonSchema to 0
        End
    End_Procedure
    
    Procedure End_Construct_Object
        Forward Send End_Construct_Object
        Send ClearAll
    End_Procedure

Cd_End_Object
