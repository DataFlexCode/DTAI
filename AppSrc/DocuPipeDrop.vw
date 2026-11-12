// DocuPipe drag and drop test view
// Optional: drop a JSON schema file in the schema area (or use Browse...). It is registered with
//   POST /schema (once per file content per session) and the returned schemaId goes into the Schema ID field.
//   A file containing just {"schemaId": "..."} is used as a reference to an existing DocuPipe schema.
// Drop a PDF in the PDF area (or use Browse...) and it is run through the complete DocuPipe flow:
//   1. POST /document            upload (base64)              -> documentId + upload jobId
//   2. GET  /document/{documentId} poll until parsing completes (status completed)
//   3. POST /v3/standardize      extract with schema           -> standardize jobId + standardizationId
//   4. GET  /job/{jobId}         poll until extraction completes (falls back to GET /standardization/{id} on 404)
//   5. GET  /standardization/{id} show the extracted "data" JSON
// The API key is read from docupipe-api-key=... in Programs\ai.env
Use Windows.pkg
Use DFClient.pkg
Use File_dlg.pkg
Use Cursor.pkg
Use cTimer.pkg
Use cTextEdit.pkg

Use docupipeai.pkg
Use DocuPipeSchemaLookup.dg

Define C_DocuPipePollSeconds for 3
Define C_DocuPipeMaxPolls    for 200   // 200 * 3 seconds = 10 minutes per job

Deferred_View Activate_oDocuPipeDrop for ;
Object oDocuPipeDrop is a dbView
    Property Integer piStage 0              // 0=idle, 1=waiting for upload/parse job, 2=waiting for standardize job
    Property Integer piPolls 0
    Property String psFileName ""
    Property String psDocumentId ""
    Property String psJobId ""
    Property String psStandardizationId ""
    Property String psRawResult ""
    Property String psDataResult ""

    Set Border_Style to Border_Thick
    Set Size to 330 460
    Set Location to 2 2
    Set Label to "DocuPipe PDF Processing (drag and drop)"
    Set piMinSize to 250 400
    // drops anywhere else on the view are routed by file extension (.json = schema, .pdf = document)
    Set pbAcceptDropFiles to True

    Object oSchemaDropZone is a Group
        Set Size to 52 226
        Set Location to 2 2
        Set Label to "1. JSON schema (optional) - drop a .json file here"
        Set peAnchors to anTopLeft
        Set pbAcceptDropFiles to True

        Procedure OnFileDropped String sFilename Boolean bLast
            Send SchemaFileDropped sFilename
        End_Procedure

        Object oSchemaFileName is a TextBox
            Set Auto_Size_State to False
            Set Size to 10 212
            Set Location to 13 8
            Set Label to "No schema file - the Schema ID field below is used as typed."
        End_Object

        Object oSchemaBrowseButton is a Button
            Set Size to 14 60
            Set Location to 31 8
            Set Label to "Browse..."

            Procedure OnClick
                Send BrowseForSchemaFile
            End_Procedure
        End_Object

        Object oSchemaClearButton is a Button
            Set Size to 14 60
            Set Location to 31 74
            Set Label to "Clear"
            Set psToolTip to "Forget the schema file and clear the Schema ID field"

            Procedure OnClick
                Send ClearSchemaFile
            End_Procedure
        End_Object

        Object oSchemaLookupButton is a Button
            Set Size to 14 60
            Set Location to 31 140
            Set Label to "Lookup..."
            Set psToolTip to "Pick a schema that is already uploaded to DocuPipe"

            Procedure OnClick
                Send LookupSchema
            End_Procedure
        End_Object
    End_Object

    Object oPdfDropZone is a Group
        Set Size to 52 226
        Set Location to 2 232
        Set Label to "2. PDF document - drop a .pdf file here"
        Set peAnchors to anTopLeftRight
        Set pbAcceptDropFiles to True

        Procedure OnFileDropped String sFilename Boolean bLast
            Send PdfFileDropped sFilename
        End_Procedure

        Object oPdfFileName is a TextBox
            Set Auto_Size_State to False
            Set Size to 10 212
            Set Location to 13 8
            Set Label to "Drag a PDF from Windows Explorer here to process it."
        End_Object

        Object oBrowseButton is a Button
            Set Size to 14 60
            Set Location to 31 8
            Set Label to "Browse..."

            Procedure OnClick
                Send BrowseForFile
            End_Procedure
        End_Object

        Object oCancelButton is a Button
            Set Size to 14 60
            Set Location to 31 74
            Set Label to "Stop"
            Set psToolTip to "Stop polling. Jobs already submitted keep running at DocuPipe."

            Procedure OnClick
                Send StopProcessing "Stopped by user (any submitted DocuPipe job keeps running on the server)."
            End_Procedure
        End_Object
    End_Object

    Object oSchemaId is a Form
        Set Size to 13 200
        Set Location to 59 75
        Set Label to "Schema ID:"
        Set Label_Col_Offset to 2
        Set Label_Justification_Mode to JMode_Right
        Set psToolTip to "DocuPipe schemaId used for extraction. Filled in when a schema file is dropped; can also be typed. Blank = DocuPipe drafts a schema (extra credits)."
    End_Object

    Object oHighEffort is a CheckBox
        Set Size to 10 60
        Set Location to 61 285
        Set Label to "High effort"
        Set psToolTip to "effortLevel=high uses DocuPipe's best (slower, more expensive) models"
    End_Object

    Object oCurrentStatus is a Form
        Set Size to 13 400
        Set Location to 76 56
        Set Label to "Status:"
        Set Label_Col_Offset to 2
        Set Label_Justification_Mode to JMode_Right
        Set Enabled_State to False
        Set peAnchors to anTopLeftRight
    End_Object

    Object oStatusLog is a cTextEdit
        Set Size to 66 456
        Set Location to 92 2
        Set peAnchors to anTopLeftRight
        Set Read_Only_State to True
        Set pbAcceptDropFiles to True

        Procedure OnFileDropped String sFilename Boolean bLast
            Delegate Send OnFileDropped sFilename bLast
        End_Procedure
    End_Object

    Object oResultLabel is a TextBox
        Set Size to 10 100
        Set Location to 163 2
        Set Label to "Result (extracted data):"
    End_Object

    Object oCopyButton is a Button
        Set Size to 13 45
        Set Location to 160 236
        Set Label to "Copy"
        Set peAnchors to anTopRight
        Set Enabled_State to False
        Set psToolTip to "Copy the result to the clipboard"

        Procedure OnClick
            Send CopyResult
        End_Procedure
    End_Object

    Object oSaveAsButton is a Button
        Set Size to 13 45
        Set Location to 160 285
        Set Label to "Save As..."
        Set peAnchors to anTopRight
        Set Enabled_State to False
        Set psToolTip to "Save the result to a file"

        Procedure OnClick
            Send SaveResultAs
        End_Procedure
    End_Object

    Object oShowRaw is a CheckBox
        Set Size to 10 120
        Set Location to 162 336
        Set Label to "Show full DocuPipe response"
        Set peAnchors to anTopRight

        Procedure OnChange
            Send ShowResult
        End_Procedure
    End_Object

    Object oResult is a cTextEdit
        Set Size to 152 456
        Set Location to 175 2
        Set peAnchors to anAll
        Set Read_Only_State to True
        Set pbAcceptDropFiles to True

        Procedure OnFileDropped String sFilename Boolean bLast
            Delegate Send OnFileDropped sFilename bLast
        End_Procedure
    End_Object

    Object oOpenDialog is an OpenDialog
        Set Dialog_Caption to "Select a PDF to process with DocuPipe"
        Set Filter_String to "PDF Files|*.pdf|All Files|*.*"
    End_Object

    Object oSchemaOpenDialog is an OpenDialog
        Set Dialog_Caption to "Select a JSON schema file"
        Set Filter_String to "JSON Files|*.json|All Files|*.*"
    End_Object

    Object oResultSaveAsDialog is a SaveAsDialog
        Set Dialog_Caption to "Save DocuPipe result"
        Set Filter_String to "JSON Files|*.json|All Files|*.*"
        Set OverwritePrompt_State to True
    End_Object

    Object oPollTimer is a cTimer
        Set piTimeout to (C_DocuPipePollSeconds*1000)
        Set pbEnabled to False

        Procedure OnTimer
            Send PollJob
        End_Procedure
    End_Object

    // ----- helpers -----

    // edit controls need CR/LF line breaks
    Function ToCRLF String sText Returns String
        Move (Replaces(Character(13),sText,"")) to sText
        Move (Replaces(Character(10),sText,Character(13)+Character(10))) to sText
        Function_Return sText
    End_Function

    Procedure SetStatus String sText
        String sLog

        Set Value of oCurrentStatus to sText

        Get Value of oStatusLog to sLog
        If (sLog<>"") Move (sLog+Character(13)+Character(10)) to sLog
        Move (sLog+sText) to sLog
        Set Value of oStatusLog to sLog
    End_Procedure

    Procedure ShowResult
        Boolean bRaw
        String sText

        Get Checked_State of oShowRaw to bRaw
        If (bRaw) Get psRawResult to sText
        Else Get psDataResult to sText
        If (sText<>"") Get PrettyJson of ghoDocuPipe sText to sText
        Set Value of oResult to (ToCRLF(Self,sText))
        Send UpdateResultButtons
    End_Procedure

    Procedure UpdateResultButtons
        String sText
        Boolean bHasResult

        Get Value of oResult to sText
        Move (Trim(sText)<>"") to bHasResult
        Set Enabled_State of oCopyButton to bHasResult
        Set Enabled_State of oSaveAsButton to bHasResult
    End_Procedure

    Procedure CopyResult
        String sText

        Get Value of oResult to sText
        If (Trim(sText)="") Procedure_Return
        Direct_Output "clipboard:"
        Write sText
        Close_Output
        Send SetStatus "Result copied to clipboard"
    End_Procedure

    // default file name: <pdf name>_docupipe.json in the PDF's folder
    Procedure SaveResultAs
        String sText sPdf sFolder sName sFile
        Integer iPos
        Boolean bOk

        Get Value of oResult to sText
        If (Trim(sText)="") Procedure_Return

        Get psFileName to sPdf
        Move "" to sFolder
        Move "docupipe_result" to sName
        If (sPdf<>"") Begin
            Move (RightPos('\',sPdf)) to iPos
            If (iPos>0) Begin
                Move (Left(sPdf,iPos-1)) to sFolder
                Move (Right(sPdf,Length(sPdf)-iPos)) to sName
            End
            Else Move sPdf to sName
            Move (RightPos('.',sName)) to iPos
            If (iPos>1) Move (Left(sName,iPos-1)) to sName
            Move (sName+"_docupipe") to sName
        End

        If (sFolder<>"") Set Initial_Folder of oResultSaveAsDialog to sFolder
        Set Filter_Index of oResultSaveAsDialog to 1
        Set File_Name of oResultSaveAsDialog to (sName+".json")
        Get Show_Dialog of oResultSaveAsDialog to bOk
        If (not(bOk)) Procedure_Return

        Get File_Name of oResultSaveAsDialog to sFile
        If (sFile="") Procedure_Return
        // add .json when no extension was typed and the JSON filter is selected
        Move (RightPos('\',sFile)) to iPos
        If (Pos('.',Right(sFile,Length(sFile)-iPos))=0 and Filter_Index(oResultSaveAsDialog)=1) Move (sFile+".json") to sFile

        Direct_Output ("BINARY:"+sFile)
        Write sText
        Close_Output
        Send SetStatus ("Saved result to "+sFile)
    End_Procedure

    Procedure ShowError String sError String sRawJson
        Send SetStatus ("ERROR: "+sError)
        Set psRawResult to sRawJson
        Set psDataResult to sRawJson
        Send ShowResult
    End_Procedure

    Procedure StopProcessing String sReason
        Set pbEnabled of oPollTimer to False
        If (piStage(Self)<>0) Begin
            Set piStage to 0
            If (sReason<>"") Send SetStatus sReason
        End
    End_Procedure

    Procedure BrowseForFile
        Boolean bOk
        String sFile

        Get Show_Dialog of oOpenDialog to bOk
        If (bOk) Begin
            Get File_Name of oOpenDialog to sFile
            If (sFile<>"") Send ProcessFile sFile
        End
    End_Procedure

    Function FileExtension String sFile Returns String
        Integer iPos
        String sExt

        Move (RightPos('.',sFile)) to iPos
        If (iPos>0) Move (Lowercase(Right(sFile,Length(sFile)-iPos))) to sExt
        Function_Return sExt
    End_Function

    // drops outside the two drop areas: route by extension
    Procedure OnFileDropped String sFilename Boolean bLast
        String sExt

        Get FileExtension sFilename to sExt
        If (sExt="json") Send SchemaFileDropped sFilename
        Else Send PdfFileDropped sFilename
    End_Procedure

    Procedure PdfFileDropped String sFilename
        If (FileExtension(Self,sFilename)="json") Begin
            Send Stop_Box "That is a JSON file. Drop schema files in the '1. JSON schema' area."
            Procedure_Return
        End
        // only one document at a time; take the first file of a multi-file drop
        If (piStage(Self)<>0) Begin
            Send Info_Box "A document is already being processed. Wait for it to finish or click Stop."
            Procedure_Return
        End
        Send ProcessFile sFilename
    End_Procedure

    // ----- schema file -----

    Procedure BrowseForSchemaFile
        Boolean bOk
        String sFile

        Get Show_Dialog of oSchemaOpenDialog to bOk
        If (bOk) Begin
            Get File_Name of oSchemaOpenDialog to sFile
            If (sFile<>"") Send SchemaFileDropped sFile
        End
    End_Procedure

    // pick an existing DocuPipe schema; replaces any schema file that was dropped
    Procedure LookupSchema
        Boolean bOk
        String sId sName

        Get SelectSchema of oDocuPipeSchemaLookup to bOk
        If (not(bOk)) Procedure_Return

        Get psSelectedSchemaId of oDocuPipeSchemaLookup to sId
        Get psSelectedSchemaName of oDocuPipeSchemaLookup to sName
        Set Value of oSchemaId to sId
        Set Label of oSchemaFileName to ("Existing schema: "+sName)
        Send SetStatus ("Selected schema "+sName+" ("+sId+")")
    End_Procedure

    Procedure ClearSchemaFile
        Set Value of oSchemaId to ""
        Set Label of oSchemaFileName to "No schema file - the Schema ID field below is used as typed."
        Send SetStatus "Schema file cleared."
    End_Procedure

    // read the JSON schema file and register it with DocuPipe (POST /schema), or use the schemaId it references.
    // The resulting schemaId goes into the Schema ID field, which is what the standardize step uses.
    Procedure SchemaFileDropped String sFile
        tDocuPipeSchemaCreateResponse SchemaResp

        If (FileExtension(Self,sFile)<>"json") Begin
            Send Stop_Box ("Only .json schema files are accepted in the schema area:"+Character(13)+Character(10)+sFile)
            Procedure_Return
        End

        If (ApiKey(ghoDocuPipe)="") Begin
            Send Stop_Box "No DocuPipe API key found. Add a line docupipe-api-key=YOUR_KEY to Programs\ai.env and restart the program."
            Procedure_Return
        End

        Send SetStatus ("Reading schema file "+sFile+" ...")
        Send Cursor_Wait of Cursor_Control
        Get CreateSchemaFromFile of ghoDocuPipe sFile "" to SchemaResp
        Send Cursor_Ready of Cursor_Control

        If (not(SchemaResp.bOk)) Begin
            Send ShowError ("Schema not registered. "+SchemaResp.sError) SchemaResp.sRawJson
            Procedure_Return
        End

        Set Value of oSchemaId to SchemaResp.sSchemaId
        Set Label of oSchemaFileName to ("Schema file: "+sFile)

        If (SchemaResp.bExistingReference) Send SetStatus ("Schema file references existing schemaId="+SchemaResp.sSchemaId+" (nothing created).")
        Else If (SchemaResp.bFromCache) Send SetStatus ("Schema '"+SchemaResp.sSchemaName+"' already registered this session, reusing schemaId="+SchemaResp.sSchemaId+".")
        Else Send SetStatus ("Schema '"+SchemaResp.sSchemaName+"' created in DocuPipe. schemaId="+SchemaResp.sSchemaId)
    End_Procedure

    // ----- DocuPipe flow -----

    // step 1: upload the file, then start polling the upload/parse job
    Procedure ProcessFile String sFile
        tDocuPipeConfig cfg
        tDocuPipeDocumentSubmitResponse SubmitResp
        String sExt

        If (piStage(Self)<>0) Begin
            Send Info_Box "A document is already being processed. Wait for it to finish or click Stop."
            Procedure_Return
        End

        Get FileExtension sFile to sExt
        If (sExt<>"pdf") Begin
            Send Stop_Box ("Only PDF files are accepted by this view:"+Character(13)+Character(10)+sFile)
            Procedure_Return
        End

        // keep the key from the .env file (blank sApiKey = leave as is), 2 minute timeout, single retry
        Move 120 to cfg.iTimeoutSeconds
        Move 1 to cfg.iRetryCount
        Send Configure of ghoDocuPipe cfg

        If (ApiKey(ghoDocuPipe)="") Begin
            Send Stop_Box "No DocuPipe API key found. Add a line docupipe-api-key=YOUR_KEY to Programs\ai.env and restart the program."
            Procedure_Return
        End

        Set psFileName to sFile
        Set psDocumentId to ""
        Set psJobId to ""
        Set psStandardizationId to ""
        Set psRawResult to ""
        Set psDataResult to ""
        Set Value of oResult to ""
        Send UpdateResultButtons
        Set Label of oPdfFileName to ("PDF: "+sFile)
        If (Value(oStatusLog(Self))<>"") Send SetStatus "----------------------------------------"

        Send SetStatus ("Uploading "+sFile+" ...")
        Send Cursor_Wait of Cursor_Control
        Get SubmitDocumentFromFile of ghoDocuPipe sFile "" "" to SubmitResp
        Send Cursor_Ready of Cursor_Control

        If (not(SubmitResp.bOk)) Begin
            Send ShowError ("Upload failed. "+SubmitResp.sError) SubmitResp.sRawJson
            Procedure_Return
        End

        Set psDocumentId to SubmitResp.sDocumentId
        Set psJobId to SubmitResp.sJobId
        Send SetStatus ("Uploaded. documentId="+SubmitResp.sDocumentId+"  upload jobId="+SubmitResp.sJobId+"  status="+SubmitResp.sStatus)

        Set piStage to 1
        Set piPolls to 0
        Send SetStatus "Waiting for DocuPipe to parse the document ..."
        Set pbEnabled of oPollTimer to True
    End_Procedure

    // step 3: start extraction against the schema, then poll the standardize job
    Procedure StartStandardization
        tDocuPipeStandardizeResponse StdResp
        String sSchemaId sEffort
        Boolean bHigh

        Get Value of oSchemaId to sSchemaId
        Move (Trim(sSchemaId)) to sSchemaId
        Get Checked_State of oHighEffort to bHigh
        If (bHigh) Move "high" to sEffort

        If (sSchemaId="") Send SetStatus "Standardizing with no schema ID (DocuPipe will draft a schema from the document) ..."
        Else Send SetStatus ("Standardizing with schemaId="+sSchemaId+" ...")

        Send Cursor_Wait of Cursor_Control
        Get StandardizeDocument of ghoDocuPipe (psDocumentId(Self)) sSchemaId "" sEffort to StdResp
        Send Cursor_Ready of Cursor_Control

        If (not(StdResp.bOk)) Begin
            Set piStage to 0
            Send ShowError ("Standardize request failed. "+StdResp.sError) StdResp.sRawJson
            Procedure_Return
        End

        Set psJobId to StdResp.sJobId
        Set psStandardizationId to StdResp.sStandardizationId
        Send SetStatus ("Standardization started. jobId="+StdResp.sJobId+"  standardizationId="+StdResp.sStandardizationId)

        Set piStage to 2
        Set piPolls to 0
        Send SetStatus "Waiting for DocuPipe to extract the data ..."
        Set pbEnabled of oPollTimer to True
    End_Procedure

    // with "Show full DocuPipe response" checked, every poll response is written to the log (truncated)
    Procedure LogPollResponse String sWhat Integer iHttpStatus String sRawJson
        Boolean bRaw

        Get Checked_State of oShowRaw to bRaw
        If (not(bRaw)) Procedure_Return
        If (Length(sRawJson)>2000) Move (Left(sRawJson,2000)+" ...(truncated)") to sRawJson
        Send SetStatus ("  "+sWhat+" -> HTTP "+String(iHttpStatus)+": "+sRawJson)
    End_Procedure

    Function NextPoll Returns Integer
        Integer iPolls

        Get piPolls to iPolls
        Increment iPolls
        Set piPolls to iPolls
        Function_Return iPolls
    End_Function

    // keep waiting, or give up after C_DocuPipeMaxPolls
    Procedure ContinuePolling String sWhat String sStatus String sRawJson
        Integer iPolls

        Get piPolls to iPolls
        If (iPolls>=C_DocuPipeMaxPolls) Begin
            Set piStage to 0
            Send ShowError ("Gave up waiting for "+sWhat+" (still '"+sStatus+"').") sRawJson
            Procedure_Return
        End
        Set Value of oCurrentStatus to (sWhat+" is "+sStatus+" ("+String(iPolls*C_DocuPipePollSeconds)+"s)")
        Set pbEnabled of oPollTimer to True
    End_Procedure

    // steps 2 and 4: called by the timer
    Procedure PollJob
        Integer iStage

        Set pbEnabled of oPollTimer to False   // no re-entry while we are talking to DocuPipe
        Get piStage to iStage
        If (iStage=1) Send PollDocument
        If (iStage=2) Send PollStandardizeJob
    End_Procedure

    // step 2: wait for parsing with GET /document/{documentId} (status processing|completed|error).
    // The upload jobId from POST /document is not reliably queryable (GET /job/{id} can 404).
    Procedure PollDocument
        tDocuPipeDocumentStatusResponse DocResp
        Integer iPolls
        String sStatus sWhat

        Get NextPoll to iPolls
        Move ("Document "+psDocumentId(Self)) to sWhat

        Get GetDocumentStatus of ghoDocuPipe (psDocumentId(Self)) to DocResp
        Send LogPollResponse ("GET /document/"+psDocumentId(Self)) DocResp.iHttpStatus DocResp.sRawJson
        If (not(DocResp.bOk)) Begin
            Set piStage to 0
            Send ShowError ("Document status request failed. "+DocResp.sError) DocResp.sRawJson
            Procedure_Return
        End

        Move (Lowercase(DocResp.sStatus)) to sStatus
        If (sStatus="completed") Begin
            Send SetStatus ("Document parsed ("+String(iPolls*C_DocuPipePollSeconds)+"s).")
            Set piStage to 0
            Send StartStandardization
            Procedure_Return
        End
        If (sStatus="error" or sStatus="failed") Begin
            Set piStage to 0
            Send ShowError (sWhat+" failed to parse (status '"+DocResp.sStatus+"').") DocResp.sRawJson
            Procedure_Return
        End

        Send ContinuePolling sWhat DocResp.sStatus ""
    End_Procedure

    // step 4: wait for extraction with GET /job/{jobId}. If the job can't be found (404) but we have a
    // standardizationId, GET /standardization/{id}: success means the extraction is complete.
    Procedure PollStandardizeJob
        tDocuPipeJobResponse JobResp
        tDocuPipeStandardizationGetResponse GetResp
        Integer iPolls
        String sStatus sWhat sStdId

        Get NextPoll to iPolls
        Move ("Job "+psJobId(Self)) to sWhat

        Get GetJob of ghoDocuPipe (psJobId(Self)) to JobResp
        Send LogPollResponse ("GET /job/"+psJobId(Self)) JobResp.iHttpStatus JobResp.sRawJson

        If (not(JobResp.bOk)) Begin
            Get psStandardizationId to sStdId
            If (JobResp.iHttpStatus=404 and sStdId<>"") Begin
                Get GetStandardization of ghoDocuPipe sStdId to GetResp
                Send LogPollResponse ("GET /standardization/"+sStdId) GetResp.iHttpStatus GetResp.sRawJson
                If (GetResp.bOk) Begin
                    Set piStage to 0
                    Send SetStatus ("Job not found, but standardization "+sStdId+" is available ("+String(iPolls*C_DocuPipePollSeconds)+"s).")
                    Send DisplayStandardization GetResp
                    Procedure_Return
                End
                If (GetResp.iHttpStatus=404) Begin
                    // not there yet, keep waiting
                    Send ContinuePolling ("Standardization "+sStdId) "not available yet" GetResp.sRawJson
                    Procedure_Return
                End
                Set piStage to 0
                Send ShowError ("Could not retrieve standardization "+sStdId+". "+GetResp.sError) GetResp.sRawJson
                Procedure_Return
            End
            Set piStage to 0
            Send ShowError ("Job status request failed. "+JobResp.sError) JobResp.sRawJson
            Procedure_Return
        End

        Move (Lowercase(JobResp.sStatus)) to sStatus

        If (not(IsTerminalJobStatus(ghoDocuPipe,sStatus))) Begin
            Send ContinuePolling sWhat JobResp.sStatus JobResp.sRawJson
            Procedure_Return
        End

        Set piStage to 0
        If (sStatus<>"completed" and sStatus<>"complete") Begin
            Send ShowError ("DocuPipe job "+psJobId(Self)+" ended with status '"+JobResp.sStatus+"'. "+JobResp.sErrorMessage) JobResp.sRawJson
            Procedure_Return
        End

        If (psStandardizationId(Self)="") Set psStandardizationId to JobResp.sStandardizationId
        Send SetStatus ("Extraction completed ("+String(iPolls*C_DocuPipePollSeconds)+"s).")
        Send FetchResult
    End_Procedure

    Procedure DisplayStandardization tDocuPipeStandardizationGetResponse GetResp
        Set psRawResult to GetResp.sRawJson
        Set psDataResult to GetResp.sDataJson
        Send ShowResult
        Send SetStatus ("Done. standardizationId="+GetResp.sStandardizationId+"  documentId="+psDocumentId(Self))
    End_Procedure

    // step 5: retrieve and display the extracted data
    Procedure FetchResult
        tDocuPipeStandardizationGetResponse GetResp
        String sStdId

        Get psStandardizationId to sStdId
        If (sStdId="") Begin
            Send ShowError "DocuPipe did not return a standardizationId." ""
            Procedure_Return
        End

        Send Cursor_Wait of Cursor_Control
        Get GetStandardization of ghoDocuPipe sStdId to GetResp
        Send Cursor_Ready of Cursor_Control

        If (not(GetResp.bOk)) Begin
            Send ShowError ("Could not retrieve standardization "+sStdId+". "+GetResp.sError) GetResp.sRawJson
            Procedure_Return
        End

        Send DisplayStandardization GetResp
    End_Procedure

Cd_End_Object
