import json
import boto3
import os
from requests_aws4auth import AWS4Auth

from langchain_aws import BedrockLLM
from langchain_community.chat_models import BedrockChat
from langchain.memory import ConversationBufferMemory
from langchain_core.prompts import PromptTemplate
from langchain.chains import ConversationalRetrievalChain
from langchain_community.embeddings import BedrockEmbeddings
from langchain_community.chat_message_histories import DynamoDBChatMessageHistory
from opensearchpy import OpenSearch, RequestsHttpConnection
from langchain_community.vectorstores import OpenSearchVectorSearch

def lambda_handler(event, context):
    if "session_id" not in event or "prompt" not in event or "bedrock_model_id" not in event or "model_kwargs" not in event or "metadata" not in event or "memory_window" not in event:
        return {
            'statusCode': 400,
            'body': "Invalid input. Missing required fields."
        }
    
    prompt = event["prompt"]
    bedrock_model_id = event["bedrock_model_id"]
    model_kwargs = event["model_kwargs"]
    metadata = event["metadata"]
    memory_window = event["memory_window"]
    session_id = event["session_id"]

    if "temperature" in model_kwargs and (model_kwargs["temperature"] < 0 or model_kwargs["temperature"] > 1):
        return {
            'statusCode': 400,
            'body': "Invalid input. temperature value must be between 0 and 1."
        }
    if "top_p" in model_kwargs and (model_kwargs["top_p"] < 0 or model_kwargs["top_p"] > 1):
        return {
            'statusCode': 400,
            'body': "Invalid input. top_p value must be between 0 and 1."
        }

    # Check if top_k is between 0 and 1
    if "top_k" in model_kwargs and (model_kwargs["top_k"] < 0 or model_kwargs["top_k"] > 500):
        return {
            'statusCode': 400,
            'body': "Invalid input. top_k value must be between 0 and 500."
        }

    os_host = os.environ['aoss_host']
    if not os_host:
        return {
            'statusCode': 400,
            'body': "Invalid input. os_host is empty."
        }
    
    region = os.environ.get('AWS_REGION', 'us-east-1')  # Default to us-east-1 if AWS_REGION is not set

    # TODO implement
    conversation = init_conversationchain(session_id, region, bedrock_model_id,model_kwargs, metadata, memory_window, os_host)
    response = conversation({"question": prompt})
    
    generated_text = response["answer"]
    doc_url = json.loads('[]')

    if len(response['source_documents']) != 0:
        for doc in response['source_documents']:
            doc_url.append(doc.metadata['source'])
    print(generated_text)
    print(doc_url)

    return {
        'statusCode': 200,
        'body': {"question": prompt.strip(), "answer": generated_text.strip(), "documents": doc_url}
    }
    
    
def init_conversationchain(session_id,region, bedrock_model_id, model_kwargs, metadata, memory_window, host) -> ConversationalRetrievalChain:
    bedrock_embedding_model_id = "amazon.titan-embed-text-v2:0"
    
    bedrock_client = boto3.client(service_name='bedrock-runtime', region_name=region)
    bedrock_embeddings = BedrockEmbeddings(model_id=bedrock_embedding_model_id,
                                    client=bedrock_client)
    
    service = 'aoss'
    credentials = boto3.Session().get_credentials()
    awsauth = AWS4Auth(credentials.access_key, credentials.secret_key,
                    region, service, session_token=credentials.token)

    new_db = OpenSearchVectorSearch(
        index_name="fsxnragvector-index",
        embedding_function=bedrock_embeddings,
        opensearch_url=f'{host}:443',
        http_auth=awsauth,
        use_ssl=True,
        verify_certs=True,
        connection_class=RequestsHttpConnection
    )

    prompt_template = """Human: This is a friendly conversation between a human and an AI. 
    The AI is talkative and provides specific details from its context but limits it to 240 tokens.
    If the AI does not know the answer to a question, it truthfully says it 
    does not know.

    Assistant: OK, got it, I'll be a talkative truthful AI assistant.

    Human: Here are a few documents in <documents> tags:
    <documents>
    {context}
    </documents>
    Based on the above documents, provide a detailed answer for, {question} 
    Answer "don't know" if not present in the document. 

    Assistant:
    """

    PROMPT = PromptTemplate(
        template=prompt_template, input_variables=["question", "context"]
    )

    condense_qa_template = """{chat_history}
    Human:
    Given the previous conversation and a follow up question below, rephrase the follow up question
    to be a standalone question.

    Follow Up Question: {question}
    Standalone Question:

    Assistant:"""
    standalone_question_prompt = PromptTemplate.from_template(condense_qa_template)

    everyone_acl = 'S-1-1-0'
    if metadata == "NA":
        retriever = new_db.as_retriever(search_kwargs={"filter": [{"term": {"metadata.acl.allowed": everyone_acl}}]})
    else:
        # retriever = new_db.as_retriever(search_kwargs={"filter": [{"term": {"metadata.year": metadata}}]})
        retriever = new_db.as_retriever(search_kwargs={"filter": [{"terms": {"metadata.acl.allowed": [everyone_acl,metadata]}}]})

    llm = BedrockChat(
        model_id=bedrock_model_id,
        model_kwargs=model_kwargs,
        streaming=True
    )

    msg_history = DynamoDBChatMessageHistory(table_name='SessionTable', session_id=session_id, boto3_session=boto3.Session(region_name=region))

    memory = ConversationBufferMemory(
        memory_key="chat_history",
        chat_memory=msg_history,
        return_messages=True,
        output_key="answer")

    conversation = ConversationalRetrievalChain.from_llm(
        llm=llm,
        retriever=retriever,
        condense_question_prompt=standalone_question_prompt,
        return_source_documents=True, 
        verbose=True,
        memory=memory,
        combine_docs_chain_kwargs={"prompt":PROMPT},
    )

    return conversation
