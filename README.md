# Datatech AI Library (DTAI)

Version 0.1

This is a library intended to provide a unified interface for sending prompts to AIs and receiving the responses back.

The approach is to have a class defined for each AI that implements the REST API calls necessary to communicate with the AI.

An object for each AI is created and has a global handle that can be used to work with the AI.

Because each class will have the same DataFlex interface, the same message can be sent to any of the global objects without requiring the programmer to know the details of the underlying REST implemenation.

The initial implementation focuses on Anthropic's Claude API, supporting the messages, models, and files endpoints.


Matt Davidian August 2025
