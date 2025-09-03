# Datatech AI Library (DTAI)

Version 0.1

This is a library intended to provide a standard interface for sending text prompts to AIs and receiving text responses back.  

This library can be used for both Windows and Web applications.  It has no dependencies on other DataFlex libraries or ActiveX components.  
It does require pandoc to view responses formatting in HTML.  See below.

The approach is to have a class defined for each AI that implements the REST API calls necessary to communicate with the AI behind a set of standard Dataflex functions.

An object for each AI is created when the AI class file is used and a global handle is defined to use to with each AI.

It may be desireable to use different AI's based on their capabitilies, strengths, cost, availablity, etc.  

Abstracting the actual access reduces cognitive load and the amount of code the developer needs to write to support access to different AIs.

The initial implementation was intended to focus on Anthropic's Claude API, supporting the messages, models, and files endpoints.

OCD took over and soon there were interfaces for Grok, Gemini, and ChatGPT.

#pandoc Dependency
AIs return response text in markdown format.  At present the framework converts the markdown to HTML for display using pandoc.  
You will need to install pandoc and add it to your system path so that it can be found via RUNPROGRAM.  
pandoc can be found here:  https://pandoc.org/installing.html

If you don't want to use pandoc for conversion to HTML, feel free to write your own markdown to HTML converter in DataFlex and send me a pull request! ;)

If you don't have pandoc installed and try to use the included demo program, you won't be able to see the responses in the HTML tab page.  
You will still see the raw text/JSON data with the responses though in the other tabs.

#CLASSES
 - cdtJsonHttpTransfer (mixin: cJSON_mxin)
   +-cAiInterface (mixins: cBase64Attachment_mixin, cMarkdown_mixin)
     +-cClaudeInterface
     +-cGrokInterface
     +-cGeminiInterface
     +-cChatGPTInterface
 -cClaudeRequest
 -cGrokRequest
 -cGeminiRequest
 -cChatGPTRequest
 -cClaudeTranslator
 -cGrokTranslator
 -cGeminiTranslator
 -cChatGPTranslator

 - cMultipartFormdataTransfer (used for Claude Files API, authored by Harm Wibier)

 - cEnvironment (see API Keys below)

# INTERFACE
Each AI class supports the following messages

## ModelList returns tAIModel[]
Returns a struct array with a list of available models to use.

## CreateRequest String sPrompt tAIAttachment[] Attachments Returns Handle (a handle to a JSON Request object)
Given a string parameter with a text prompt and optional array of files encoded as base64, construct a JSON request that can be sent to the AI.

This is implemented in the "Request" classes.  The developer will normally not need to use the "Request" classes directly.

Returns a handle to a JSON object that can be sent to MakeRequest / MakeRequestJSON

## MakeRequestJSON handle hoRequest returns handle (a handle to a JSON response object)
Sends a request to the AI and returns it's response as a handle to a JSON object.

This is a low level way of accessing the response because each AI has quite different JSON structures for their responses.  
When this is used, separate code (or serialization to a struct) must be used if dealing with multiple AIs.  If you are only
sending requests to a specific AI, it may be just fine to use this.

## MakeRequest handle hoRequest returns tAIResponse
Sends a request to the AI and returns its response in a DataFlex struct 

This is the intended high level access for the AI interface as this will return a well defined easy to work with struct to the calling procedure no matter which AI is used.

This will use the MakeRequestJSON function and then convert the JSON response to the standard response struct using the Translator helper class.

# API Keys

API Keys are necessary to use the REST APIs.  If you are unsure where to go to generate the API Keys, ask each model.  They can guide you through the process.

For Claude, ChatGPT, and Grok, you will need to purchase a nominal amount of tokens.  You can generate an API key for Gemini in Google AI Studio for free.

API keys can be stored in a {program_name}.env file.  This file will normally be stored in the Programs folder.  

The cEnvironment class is is used to load API keys so that they are not stored in the source code.

cEnvironment will first search the .env file and if a key is not found then it will use the get_environment command to get the environment variable.

The .env file should have the format:

{key}={value}

Example (no these are not valid!):
claude-api-key=sk-ant-api03-kasdf;jaksld45384adslkha;dlk
grok-api-key=xai-kfdan;IH325n;kajdf$)yhnaeiht;hn;s@g^e*dinrg;ioh
gemini-api-key=AIxyzzy977352k;lasdj%^$&fa90lskdnf;awe
chilkat-unlock-code=DATATECH_;kldfjha;dsl*@#$^knfaioetyh
chatgpt-api-key=sk-proj-i34752894jnkln;fkl347[0sdfhgPOIW;E4!#$#$956UJHDSFPOGIHN;]

(There is a Claude API key in a comment in an early version of cClaudeInterface.  It has been deactivated.)

# DATABASE

Currently there are no database table specific to this project.  When/if logging capabilities are added, this could change.

A SQL Server 2022 backup file in the Data folder only has CODEMAST/CODETYPE migrated to SQL.  You can restore this, or alternatively connect to your own blank database with those tables.

The Connection ID is set up for the local database server (i.e. ".") and DTAI as the database.

# CURRENT STATUS

It works!  The demo project included is AI.SRC.  

There are two views, one that allows you to submit a request to any of the four supported AIs, and one to test the file upload capability for Claude.

# TODO ITEMS
 (X = completed, x = In Progress)
 [X] Add error message if a request is made without an API key to all four interface classes
 [X] The current library is being used with DataFlex 19.1.  It needs to be migrated to 25.0, while retaining 19.1 compatibility.
 [X] Migrate the cClaudeInterface_beta code into cClaudeInterface (this was initially split up so as to not require ChilKat for basic Claude support)
 [X] Add a Mixin class to provide common base64 / MIME type / file attachment code 
 [X] A unified struct needs to be defined to contain the responses received from the AIs and MakeRequest implemented in all interfaces using this struct as a return value
     [X] Update MakeRequest for cClaudeInterface
     [X] Update MakeRequest for cGrokInterface
     [X] Update MakeRequest for cGeminiInterface
     [X] Update MakeRequest for cChatGPTInterface
 [x] More post processing support for the response.  AIs generate markdown text (unless instructed othewise), this needs to be converted to something displayable (e.g. HTML, looking at pandoc for this)
 [X] A demonstration program that has:
     [X] A radio group to select the AI to use
     [X] A comboform that allows you to select the model to use for the currently select AI
        [X] Comboform automatically updated when model changed
        [X] Store model list in property of AI subclass so that API request is not needed everytime
     [X] A text edit control to enter a text prompt
     [X] A file selection method to select optional attachments to send with the prompt
        [X] procedure OnFileDropped implemented to add files to grid
        [X] Add ability to delete files in the grid
        [X] Open files in grid on double click in default Windows App
     [X] A HTML control displaying the response (cWebBrowser2)
     [X] Text edit controls displaying the HTML source, Raw text Response, tAIResponse struct returned, model specific JSON returned
 [ ] Determine some way to control timeout-Grok and some OpenAI models in particular do not return a response before the standard 30 second timeout results in a "Http Transfer Failed" error
      https://support.dataaccess.com/Forums/showthread.php?72515-Can-timeout-be-controlled-on-cJsonHttpTransfer
 [ ] Logging of AI requests/responses/stats
     [x] Track start/stop time, timeout status in the cAiInterface class, augment HttpPostJson
     [ ] Log both complete request JSON and response JSON in Database
     [ ] Tool to extract base64 files from request JSON
     [ ] "Replay" a request from log
     [ ] Tracks tokens in/out (important for billing!!)
 [ ] Claude Files API Console updates
     [ ] Confirmation when file is uploaded
     [ ] Refresh file list when file uploaded/deleted
 [ ] Remove UI code from interface libraries
     [ ] Set properties with error conditions/messages
     [ ] Refactor calling code to handle errors
 [ ] PDF support in Grok is only through reference to a URL, not base64 encoded PDF file as with other AIs.  This... complicates things.
 [ ] On the Request side, support other parameters besides the max tokens, model id (e.g. Temperature, number of completions, top_p, etc)
 [ ] REplace backup of database with a script to create tables/etc.
Matt Davidian August 2025
