// General struct defintions for AI interface

// this is actually the same as the definition for tClaudeAttachment
//  
Struct tAIAttachment
    UChar[] uBase64File
    String sMimeType
    String sFileID
End_Struct

// unified structure for all AI model details
Struct tAIModel
    String type         // Claude
    String id           // Claude, Grok
    String display_name // Claude
    String created_at   // Claude        
    Integer created     // UNIX creation date/time Grok
    {Name=object }
    String _object      // Grok
    String owned_by     // Grok
End_Struct


