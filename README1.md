# RAG with ACLs on Amazon FSx for NetApp ONTAP data using Amazon Bedrock and Langchain
## Overview
This reference architecture implemets the a RAG Chat engine on top of Amazon FSx for ONTAP (FSxN) data that has predefined access permission using ACLs with Active Directory.


## Infrastructure Allocation
This will create all the required AWS and application resources to on your AWS account using Terraform. You can read about it [here](/terraform/).

![general architecture](/images/architecture.png)
## Embedding Engine
This process takes the documents stored on the FSxN filesystem and embeds them together with the Access Control List into the OpenSearch Vector DB. You can read about the process in more details [here](/embed/).

![embedding](/images/embedding.png)

## Retrieval Engine
The retrieval engine works as a Lambda function that get a promp and model parameter for retrieval and uses RAG to get answers based on the embedding on the FSxN data. It also filters data access based on SID (ACL) provided. You can read more about the process in more details [here](/lambda/)  

## Chatbot
The chat bot is a simple chat UI that simplifies access to the retrival engine. You can read more about the chat bot in more details [here](/chatapp/)

## Test
### Prerequisites
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed on host
    * AWS [Credentials configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html)
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) installed on host
* [Docker engine](https://docs.docker.com/engine/install/) installed on host

### Start the environment 
Use the following to start the environment:
```
terraform init
terraform apply --auto-approve
```

### Clear the environment
Use the following to clear the environment:
```
terraform destroy --auto-approve
```