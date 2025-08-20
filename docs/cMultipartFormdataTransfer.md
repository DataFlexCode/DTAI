# cMultipartFormdataTransfer Class Documentation

## Overview

The `cMultipartFormdataTransfer` class is a specialized subclass of `cHttpTransfer` designed for uploading files and form data using HTTP multipart/form-data encoding. This class simplifies the process of creating and sending multipart HTTP POST requests, making it ideal for file upload scenarios and forms that combine text fields with file attachments.

## Inheritance

```
cHttpTransfer (superclass)
└── cMultipartFormdataTransfer
```

For detailed information about the parent class capabilities, refer to the [cHttpTransfer documentation](https://docs.dataaccess.com/dataflexhelp/mergedProjects/VDFClassRef/cHttpTransfer.htm).

## Key Features

- **File Upload Support**: Upload multiple files with different content types
- **Form Data Integration**: Combine files with traditional form field values
- **Memory Efficient**: Reads large files in chunks to minimize memory usage
- **Automatic Boundary Generation**: Handles multipart boundary creation automatically
- **Response Processing**: Built-in methods to handle server responses as strings or JSON
- **Testing Support**: Loopback testing mode for development and debugging

## Class Structure

### Structs

#### tPostfile
Represents a file to be uploaded:
```dataFlex
Struct tPostfile
    String sPath         // Full path to the file
    String sName         // Form field name for the file
    String sContentType  // MIME content type (e.g., "image/jpeg", "text/plain")
End_Struct
```

#### tPostValue
Represents a form field value:
```dataFlex
Struct tPostValue
    String sName   // Form field name
    String sValue  // Field value
End_Struct
```

### Properties

#### Public Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `psBoundary` | String | "---dfyoEniJtfokydpuyM7aT1" | Multipart boundary string used to separate form parts |
| `pbClearHeaders` | Boolean | True | Whether to automatically clear HTTP headers between requests |
| `psContentTypeReceived` | String | '' | Content type of the received response (read-only) |
| `pbPostLoopTest` | Boolean | False | Testing mode - returns posted data instead of sending to server |

#### Private Properties

| Property | Type | Description |
|----------|------|-------------|
| `paValues` | tPostValue[] | Array of form field values |
| `paFiles` | tPostfile[] | Array of files to upload |
| `paDataReceived` | Address | Memory address of received response data |
| `piDataReceivedLength` | Integer | Length of received response data |

## Public Methods

### AddFormValue
Adds a form field value to the request.

```dataFlex
Procedure AddFormValue String sName String sValue
```

**Parameters:**
- `sName`: The form field name
- `sValue`: The field value

**Example:**
```dataFlex
Send AddFormValue "username" "john_doe"
Send AddFormValue "description" "File upload test"
```

### AddFile
Adds a file to be uploaded.

```dataFlex
Procedure AddFile String sName String sPath String sContentType
```

**Parameters:**
- `sName`: The form field name for the file input
- `sPath`: Full path to the file to upload
- `sContentType`: MIME type of the file (e.g., "image/jpeg", "application/pdf")

**Example:**
```dataFlex
Send AddFile "profile_image" "C:\Users\John\Pictures\avatar.jpg" "image/jpeg"
Send AddFile "document" "C:\Documents\report.pdf" "application/pdf"
```

### HttpPostFiles
Performs the HTTP POST request with all added files and form values.

```dataFlex
Function HttpPostFiles String sHost String sFilePath Returns Boolean
```

**Parameters:**
- `sHost`: Target server hostname or IP address
- `sFilePath`: Server path/endpoint for the upload

**Returns:**
- `Boolean`: True if the request was successful, False otherwise

**Example:**
```dataFlex
Boolean bOk
Get HttpPostFiles "api.example.com" "/upload/files" to bOk
If (bOk) Begin
    // Handle successful upload
End
```

### ResponseString
Retrieves the server response as a properly converted string.

```dataFlex
Function ResponseString Returns String
```

**Returns:**
- `String`: Server response converted from UTF-8 to OEM codepage

**Example:**
```dataFlex
String sResponse
Get ResponseString to sResponse
Showln "Server responded: " sResponse
```

### ResponseJson
Parses the server response as JSON and returns a JSON object handle.

```dataFlex
Function ResponseJson Boolean ByRef bOk Returns Handle
```

**Parameters:**
- `bOk` (ByRef): Set to True if JSON parsing succeeded, False otherwise

**Returns:**
- `Handle`: Handle to cJsonObject (must be destroyed even if parsing failed)

**Example:**
```dataFlex
Boolean bJsonOk
Handle hoJson
String sMessage

Get ResponseJson (&bJsonOk) to hoJson
If (bJsonOk) Begin
    Get Member "message" of hoJson to sMessage
    Showln "JSON message: " sMessage
End
If (hoJson) Begin
    Send Destroy of hoJson
End
```

## Usage Examples

### Basic File Upload

```dataFlex
Object oUploader is a cMultipartFormdataTransfer
End_Object

// Add form fields
Send AddFormValue of oUploader "user_id" "12345"
Send AddFormValue of oUploader "category" "documents"

// Add files
Send AddFile of oUploader "file1" "C:\temp\document.pdf" "application/pdf"
Send AddFile of oUploader "file2" "C:\temp\image.jpg" "image/jpeg"

// Perform upload
Boolean bOk
Get HttpPostFiles of oUploader "myserver.com" "/api/upload" to bOk

If (bOk) Begin
    String sResponse
    Get ResponseString of oUploader to sResponse
    Showln "Upload successful: " sResponse
End
Else Begin
    Integer iStatus
    Get ResponseStatusCode of oUploader to iStatus
    Showln "Upload failed with HTTP status: " iStatus
End
```

### JSON Response Handling

```dataFlex
Object oUploader is a cMultipartFormdataTransfer
End_Object

// ... add files and form data ...

Boolean bOk bJsonOk
Handle hoJson
String sStatus sMessage

Get HttpPostFiles of oUploader "api.example.com" "/upload" to bOk

If (bOk) Begin
    Get ResponseJson of oUploader (&bJsonOk) to hoJson
    If (bJsonOk) Begin
        Get Member "status" of hoJson to sStatus
        Get Member "message" of hoJson to sMessage
        Showln "Status: " sStatus ", Message: " sMessage
    End
    
    If (hoJson) Begin
        Send Destroy of hoJson
    End
End
```

### Testing Mode (Loopback)

```dataFlex
Object oUploader is a cMultipartFormdataTransfer
    Set pbPostLoopTest to True  // Enable testing mode
End_Object

// Add test data
Send AddFormValue of oUploader "test_field" "test_value"
Send AddFile of oUploader "test_file" "test.txt" "text/plain"

// This will return the posted data without sending to server
Boolean bOk
Get HttpPostFiles of oUploader "localhost" "/test" to bOk

If (bOk) Begin
    String sResponse
    Get ResponseString of oUploader to sResponse
    Showln "Loopback response: " sResponse
End
```

## Content Type Examples

Common MIME types for different file formats:

| File Type | MIME Type |
|-----------|-----------|
| JPEG Image | `image/jpeg` |
| PNG Image | `image/png` |
| GIF Image | `image/gif` |
| PDF Document | `application/pdf` |
| Plain Text | `text/plain` |
| HTML | `text/html` |
| CSS | `text/css` |
| JavaScript | `application/javascript` |
| XML | `application/xml` |
| JSON | `application/json` |
| ZIP Archive | `application/zip` |
| Microsoft Word | `application/msword` |
| Microsoft Excel | `application/vnd.ms-excel` |
| Video (MP4) | `video/mp4` |
| Video (MOV) | `video/quicktime` |
| Audio (MP3) | `audio/mpeg` |

## Error Handling

The class inherits error handling capabilities from `cHttpTransfer`. Common error scenarios include:

1. **Network Errors**: Check the return value of `HttpPostFiles`
2. **HTTP Status Errors**: Use `ResponseStatusCode` to get HTTP status codes
3. **File Access Errors**: Ensure files exist and are readable before calling `AddFile`
4. **Memory Allocation**: The class handles memory management internally, but large files may cause issues on systems with limited memory

```dataFlex
Boolean bOk
Integer iStatus

Get HttpPostFiles of oUploader "server.com" "/upload" to bOk

If (not bOk) Begin
    Get ResponseStatusCode of oUploader to iStatus
    Case Begin
        Case (iStatus = 404)
            Showln "Endpoint not found"
        Case (iStatus = 413) 
            Showln "File too large"
        Case (iStatus = 500)
            Showln "Server error"
        Case_Else
            Showln "HTTP Error: " iStatus
    Case End
End
```

## Best Practices

1. **Memory Management**: The class automatically manages memory for response data, but ensure you destroy JSON objects returned by `ResponseJson`

2. **File Paths**: Use full absolute paths for files to avoid path resolution issues

3. **Content Types**: Specify accurate MIME types for better server-side processing

4. **Testing**: Use the loopback mode (`pbPostLoopTest`) during development to test your multipart data structure

5. **Error Handling**: Always check the return value of `HttpPostFiles` and handle different HTTP status codes appropriately

6. **Headers**: If you need custom headers, set `pbClearHeaders` to False and manage headers manually

7. **Large Files**: The class reads files in 1MB chunks to handle large files efficiently, but be aware of server upload limits

## Security Considerations

1. **File Validation**: Validate file types and sizes before upload
2. **Path Sanitization**: Ensure file paths don't contain malicious content
3. **Authentication**: Use inherited `cHttpTransfer` properties for authentication when required
4. **HTTPS**: For sensitive data, use HTTPS by setting appropriate transfer flags in the parent class

## Revision History

- **Version 0.1** (DAE 2017/02/21): Initial implementation by HW

---

*This documentation is based on the cMultipartFormdataTransfer class implementation and the TestFileUpload.vw example. For additional HTTP transfer capabilities, refer to the cHttpTransfer class documentation.*
