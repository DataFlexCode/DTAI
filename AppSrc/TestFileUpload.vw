Use Windows.pkg
Use DFClient.pkg
Use cMultipartFormdataTransfer.pkg
Use cTextEdit.pkg

Deferred_View Activate_oTestFileUpload for ;
Object oTestFileUpload is a dbView
    
    Object oFileTrans is a cMultipartFormdataTransfer
        Set pbPostLoopTest to True
        
        Procedure TestSendFiles
            Boolean bOk bLoopback
            String sResult
            Integer iStatus
            
            Get Checked_State of oLoopback to bLoopback
            Set pbPostLoopTest to bLoopback
            
            Set Value of oTextEdit1 to ""
            
            Send AddFormValue "value1" "Bla bla!"
            Send AddFormValue "value2" "Nog meer!"
            
            Send AddFile "file1" "testtext (1).txt" "text/plain"
            Send AddFile "file2" "testtext (2).txt" "text/plain"
            Send AddFile "file3" "testtext (3).txt" "text/plain"
            Get HttpPostFiles "localhost" "/UploadTest/Upload.asp" to bOk 
            
            
            If (bOk) Begin
                Get ResponseString to sResult
                Set Value of oTextEdit1 to sResult
            End
            Else Begin
                Get ResponseStatusCode to iStatus
                Set Value of oTextEdit1 to ("Failed with HTTP status: " + String(iStatus))
            End
        End_Procedure
        
        Procedure TestSendImages
            Boolean bOk bLoopback
            
            String sResult sCopy
            Integer iStatus
            
            Get Checked_State of oLoopback to bLoopback
            Set pbPostLoopTest to bLoopback
            
            Set Value of oTextEdit1 to ""
            
            Send AddFile "file1" "TestFile (1).jpg" "image/jpg"
            Send AddFile "file2" "TestFile (2).jpg" "image/jpg"
            Send AddFile "file3" "TestFile (3).jpg" "image/jpg"
            Get HttpPostFiles "localhost" "/UploadTest/Upload.asp" to bOk 
            
            
            If (bOk) Begin
                Get ResponseString to sResult
                Set Value of oTextEdit1 to sResult
            End
            Else Begin
                Get ResponseStatusCode to iStatus
                Set Value of oTextEdit1 to ("Failed with HTTP status: " + String(iStatus))
            End
        End_Procedure
        
        
        Procedure TestSendVideo
            Boolean bOk bLoopback
            String sResult sCopy
            Integer iStatus
            
            Get Checked_State of oLoopback to bLoopback
            Set pbPostLoopTest to bLoopback
            
            Set Value of oTextEdit1 to ""
            
            Send AddFile "file1" "IMG_3438.MOV" "video/mov"
            Send AddFile "file2" "IMG_3439.MOV" "video/mov"
            Get HttpPostFiles "localhost" "/UploadTest/Upload.asp" to bOk 
            
            
            If (bOk) Begin
                Get ResponseString to sResult
                Set Value of oTextEdit1 to sResult
            End
            Else Begin
                Get ResponseStatusCode to iStatus
                Set Value of oTextEdit1 to ("Failed with HTTP status: " + String(iStatus))
            End
        End_Procedure
        
    End_Object



    Set Border_Style to Border_Thick
    Set Size to 201 300
    Set Location to 23 17
    Set Label to "TestFileUpload"

    Object oButton1 is a Button
        Set Size to 14 107
        Set Location to 5 7
        Set Label to 'Send Text Files'
        
    
        // fires when the button is clicked
        Procedure OnClick
            Send TestSendFiles of oFileTrans
        End_Procedure
    
    End_Object
    
    
    Object oButton2 is a Button
        Set Size to 14 80
        Set Location to 6 117
        Set Label to 'Send Images'
        
    
        // fires when the button is clicked
        Procedure OnClick
            Send TestSendImages of oFileTrans
        End_Procedure
    
    End_Object
    
        Object oButton2 is a Button
        Set Size to 14 80
        Set Location to 6 201
        Set Label to 'Send Video'
        
    
        // fires when the button is clicked
        Procedure OnClick
            Send TestSendVideo of oFileTrans
        End_Procedure
    
    End_Object



    Object oTextEdit1 is a cTextEdit
        Set Size to 144 280
        Set Location to 51 7
        Set Label to "Result"
        Set peAnchors to anAll
    End_Object

    Object oLoopback is a CheckBox
        Set Size to 10 50
        Set Location to 24 7
        Set Label to "Loopback"
    
        // Fires whenever the value of the control is changed
    //    Procedure OnChange
    //        Boolean bChecked
    //    
    //        Get Checked_State to bChecked
    //    End_Procedure
    
    End_Object

Cd_End_Object
