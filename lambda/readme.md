# RAG Retrieval Lambda Function
## Overview
This fucntion using Retrival Augmented Generation (RAG) using [Amazon Bedrock](https://aws.amazon.com/bedrock/) foundation models, [Langchain](https://www.langchain.com) and Amazon [Opensearch](https://opensearch.org/platform/search/vector-database.html) Serverless as a Vector DB.
The function also elables filtering on Metadata based on the original file ACLs data. You can send spesific [SID](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-security-identifiers) and get resposes based on the originla file authorizations.


## Input
You need to send the following payload as data input for the fucntion
```
{
  "session_id": "1",
  "prompt": "who was Moses?",
  "bedrock_model_id": "anthropic.claude-v2:1",
  "model_kwargs": {
    "temperature": 1,
    "top_p": 1,
    "top_k": 500,
    "max_tokens": 1024
  },
  "metadata": "S-1-5-21-4037439088-1296877785-2872080499-1112",
  "memory_window": 10
}
```
* **session_id (str)**: unique session ID to keep history for you chat with the model. Using the same session_id on seperate executions will using previous executions chat memory. 
* **prompt (str)**: user prompt/question for the model
* **bedrock_model_id (str)**: AWS Bedrock model id. Current supported models are ``anthropic.claude-v2:1`` and ``anthropic.claude-3-sonnet-20240229-v1:0``.
* **model_kwargs**: list of paramers for the foundation model
    * **temperature (float)**: The amount of randomness injected into the response. Ranges from 0 to 1. Use temp closer to 0 for analytical / multiple choice, and closer to 1 for creative and generative tasks.
    * **top_p (float)**: Use nucleus sampling. In nucleus sampling, Anthropic Claude computes the cumulative distribution over all the options for each subsequent token in decreasing probability order and cuts it off once it reaches a particular probability specified by top_p. You should alter either ``temperature`` or ``top_p``, but not both.
   * **top_k (int)**: Only sample from the top K options for each subsequent token. Use ``top_k`` to remove long tail low probability responses
   * **max_tokens (int)**: The maximum number of tokens to generate before stopping.
* **metadata (str)**: User SID to filter the data we access too based on original ACL SID access auth. 
* **memory_window (int)**: Only keep last K interaction in the memory of the chat.

### Output
This is the output format from the Lambda funcation
```
{
    'statusCode': 200,
    'body': {
        "question": <prompt>,
        "answer": <model answer>,
        "documents": <source documents>
    }
}
```
* **statusCode**: Return status code.
* **body**:
    * **question (str)**: The original question/prompt to the model.
    * **answer (str)**: The return answer from the mode.
    * **documents (array)**: An array of source documents the answer is based on.


## Building
#### Pre-requsites:
* Docker engine

#### Build:
Use the following to build the app:
```
docker build -t <image name> --platform linux/amd64 .
```
