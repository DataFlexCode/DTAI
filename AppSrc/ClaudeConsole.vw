Use Windows.pkg
Use DFClient.pkg

Use cCJGrid.pkg
Use cCJGridColumn.pkg

// TODO: File management, get meta data for a file, delete a file
// TODO: Send a message referencing a file(s)
// TODO: make the grid a multi-select list
//

Deferred_View Activate_oClaudeConsole for ;
Object oClaudeConsole is a dbView

    Set Border_Style to Border_Thick
    Set Size to 200 503
    Set Location to 2 2
    Set Label to "Claude Console"
    Set pbAcceptDropFiles to True

    Object oDirectoryGrid is a cCJGrid
        Set Size to 100 501
        Set Location to 3 2
        Set peAnchors to anAll

        Object oFileId is a cCJGridColumn
            Set piWidth to 300
//            Set pbVisible to False
            Set psCaption to 'id'
        End_Object
        
        Object oFileName is a cCJGridColumn
            Set piWidth to 366
            Set psCaption to "Filename"
        End_Object

        Object oBytes is a cCJGridColumn
            Set piWidth to 366
            Set psCaption to "Size"
        End_Object

        Object oCJGridColumn3 is a cCJGridColumn
            Set piWidth to 367
            Set psCaption to "Created At"
        End_Object

        Object oMime is a cCJGridColumn
            Set piWidth to 148
            Set psCaption to "Mime"
        End_Object
    End_Object

    Object oButton1 is a Button
        Set Location to 107 4
        Set Label to 'Get Files'
    
        // fires when the button is clicked
        Procedure OnClick
            tClaudeFileList Files
            tDataSourceRow[] GridData
            Integer i iCnt
            
            Get ClaudeFileList of ghoClaudeAI to Files
            Move (SizeOfArray(Files.data)-1) to iCnt
            For i from 0 to iCnt
                Move Files.data[i].id to GridData[i].sValue[0]
                Move Files.data[i].filename to GridData[i].sValue[1]
                Move Files.data[i].size_bytes to GridData[i].sValue[2]
                Move Files.data[i].created_at to GridData[i].sValue[3]
                Move Files.data[i].mime_type to GridData[i].sValue[4]
            Loop
            Send InitializeData of oDirectoryGrid GridData
        End_Procedure
    
    End_Object

    Procedure OnFileDropped String sFilename Boolean bLast
        String sFileId
        Forward Send OnFileDropped sFilename bLast
        Get UploadFile of ghoClaudeAI sFilename to sFileId
    End_Procedure

Cd_End_Object
