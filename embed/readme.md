# Vector Embedding Process 

## Overview

### Input Parameters
#### Environment Variables at build
You can set up these variables on the [.env](.env) file before running the build:
```
PROFILE ='xcp' # used for non in AWS environments
REGION  = 'us-west-2' # used for non in AWS environments
OPEN_SEARCH_SERVERLESS_COLLECTION_NAME = 'rag'
BEDROCK_EMBEDDING_MODEL_ID = 'amazon.titan-embed-text-v2:0' #'amazon.titan-embed-text-v1'
BEDROCK_EMBEDDING_MODEL_OUTPUT_VECTOR_SIZE = 1024 #1536
FILES_PROCESSING_CONCURRENCY = 3
EMBEDDING_CONCURRENCY = 3
DOCUMENTS_INDEXING_CONCURRENCY = 10
TEXT_SPLITTER_CHUNK_SIZE = 500
TEXT_SPLITTER_CHUNK_OVERLAP = 10
DATA_DIRECTORY = './data'
INTERNAL_DB = './db/internal.db'
SCANNER_INTERVAL = '5m'
```
* **REGION**: Default AWS Region
* **ENV_OPEN_SEARCH_SERVERLESS_COLLECTION_NAME**: Default OpenSearch collection name.
* **BEDROCK_EMBEDDING_MODEL_ID**: Amazon Bedrock embedding model.
* **BEDROCK_EMBEDDING_MODEL_OUTPUT_VECTOR_SIZE**: Embedding model dimentions
* **FILES_PROCESSING_CONCURRENCY**: File process concurrency
* **EMBEDDING_CONCURRENCY**: Embedding concurrency
* **DOCUMENTS_INDEXING_CONCURRENCY**: Document vector indexing concurrency
* **TEXT_SPLITTER_CHUNK_SIZE**: Chunk size for the text split 
* **TEXT_SPLITTER_CHUNK_OVERLAP**: Chunk overlap
* **DATA_DIRECTORY**: Data directory in the container
* **INTERNAL_DB**: Name of the sql db file
* **SCANNER_INTERVAL**: Embedding scanner interval

## Testing
#### Pre-requsites:
* Docker engine

#### Build:
Use the following to build the app:
```
docker build -t <image name> --platform linux/amd64 .
```

#### Run:
Use the following to run the app. You need to setup ``ENV_REGION`` for the AWS region to run in and ``ENV_OPEN_SEARCH_SERVERLESS_COLLECTION_NAME`` for the OpenSearch collection embed the data into.
```
docker run -d -v /tmp/data:/opt/netapp/ai/data -v /tmp/db:/opt/netapp/ai/db -e ENV_REGION='<aws_region>' -e ENV_OPEN_SEARCH_SERVERLESS_COLLECTION_NAME='<aws_aoss_collection>' <docker-image> 
```