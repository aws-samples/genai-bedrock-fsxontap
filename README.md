## Build RAG based generative AI applications in AWS using Amazon FSx for NetApp ONTAP with Amazon Bedrock

1. Use Amazon FSx for NetApp ONTAP with Amazon Bedrock to build Retrieval Augmented Generation (RAG) based generative AI applications by bringing company-specific, unstructured user file data from FSx for NetApp ONTAP for your RAG applications.
2. Leverage Windows and Linux based file ownership-based access control operations to provide a permissions-based RAG experience for your users.

### Solution Overview

The solution uses an FSx for ONTAP filesystem as the source of unstructured data and continuously populates an Amazon OpenSearch Serverless (AOSS) vector database with the user’s existing files and folders and associated metadata.  This enables a RAG scenario with Amazon Bedrock by enriching the generative AI prompt using Bedrock APIs with your company-specific data retrieved from the OpenSearch Serverless vector database. 

The solution also leverages FSx for ONTAP to allow users to extend their current data security and access mechanisms to augment model responses from Bedrock. It uses FSx for ONTAP as the source of associated metadata, specifically the user’s security access control list (ACL) configurations attached to their files and folders and populates that metadata into AOSS. By combining access control operations with file events that notify the RAG application of new and changed data on the file system, we demonstrate how FSx for NetApp ONTAP enables Bedrock to only use embeddings from authorized files for the specific users that connect to our generative AI application.

The solution provisions a multi-AZ deployment of the FSx for ONTAP filesystem with a storage virtual machine (SVM) joined to an AWS Managed Microsoft AD domain. An Amazon OpenSearch Serverless(AOSS) vector search collection provides scalable and high performing similarity search capability. We use an Amazon EC2 Windows server as an SMB/CIFS client to the FSx for ONTAP volume and configure data sharing and ACLs for the SMB shares in the volume. We use this data and ACLs to test permissions-based access to the embeddings in a RAG scenario with Bedrock.

The Embeddings container component of our solution that is deployed on an Amazon EC2 Linux server and mounted as an NFS client on the FSx for ONTAP volume, periodically migrates existing files and folders along with their security access control list (ACL) configurations to AOSS. It populates an index in the AOSS vector search collection with this company specific data (and associated metadata and ACLs) from the NFS share on the FSx for ONTAP file system.

The solution implements a RAG Retrieval Lambda function that enables a RAG scenario with Amazon Bedrock by enriching the Generative AI prompt using Bedrock APIs with your company-specific data and associated metadata (including ACLs) retrieved from the Amazon OpenSearch Serverless index that was populated by the Embeddings container component described above. The RAG Retrieval Lambda function also stores conversation history for the user interaction in an Amazon DynamoDB table.

The user interacts with the solution by submitting a natural language prompt either via a chatbot application or directly via the Amazon API Gateway API interface. The chatbot application container is built using streamlit and fronted by an AWS Application Load Balancer(ALB). When a user submits a natural language prompt to the chatbot UI via the ALB, the chatbot container interacts with API Gateway interface that then invokes the RAG Retrieval Lambda function to fetch the response for the user. The user can also directly submit prompt requests to the Amazon API Gateway API and obtain a response. We currently demonstrate permissions-based access to the RAG documents by explicitly retrieving the SID of a user and then using that SID in the chatbot or API Gateway request where the Retrieval lambda then matches the SID to the Windows ACLs configured for the document. In general, as a future enhancement, you may want to authenticate the user against an Identity Provider and then match the user against the permissions configured for the documents.

The following diagram illustrates the end-to-end flow for our solution. We start by configuring data sharing and ACLs with FSx for NetApp ONTAP and then these are periodically scanned by the Embeddings container. The Embeddings container splits the documents into chunks and uses the Amazon Titan Embeddings model to create vector embeddings from these chunks. It then stores these vector embeddings with associated metadata in our AOSS vector database by populating an index in a vector collection in AOSS.

![Embedding Flow](/images/flow-arch.png)

Here’s the overall reference architecture diagram that illustrates the various components of this solution working together

![Reference Architecture](/images/solution-arch.png)

### Prerequisites

1. Ensure you have [model access in Amazon Bedrock](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html) for both the Anthropic Claude v3 and Titan Text Embedding models available on Amazon Bedrock.
2. Install [AWS CLI](https://aws.amazon.com/cli)
3. Install [Docker](https://docs.docker.com/engine/install/)
4. [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### Setup

Cloning the repository and using the Terraform template will provision all the components with their required configurations as described in the solution overview section.

1. Clone the repository for this solution:
```
sudo yum install -y unzip
git clone https://github.com/aws-samples/genai-bedrock-fsxontap.git
cd genai-bedrock-fsxontap/terraform
```
2. From the _terraform_ folder, deploy the entire solution using terraform:
```
terraform init
terraform apply -auto-approve
```
This process can take 15–20 minutes to complete.

### Test and Validate

#### Load data and set permissions

Use the _ad_host_ instance to share sample data and set user permissions that will then be seamlessly used to populate the index on AOSS by the solution’s Embedding container component. Perform the following steps to mount your Amazon FSx for ONTAP storage virtual machine data volume as a network drive, upload data to this shared network drive and set permissions based on Windows ACLs:

1. Navigate to Systems Manager Fleet Manager on your AWS console, locate the  _ad_host_ instance and [follow instructions here](https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-rdp.html#fleet-rdp-connect-to-node) to login with Remote Desktop. Use the domain admin user _bedrock-01\\Admin_ and your _AD host password_ obtained from the Terraform output
2. Mount FSxN data volume as a network drive. Navigate to FSx on your AWS console, click on **Volumes**, select the *bedrockrag* volume and obtain values for the SVM ID and Volume name parameters. Under **This PC** right click **Network** and then **Map Network drive.** Choose drive letter and use the FSxN share path for the mount (\\\\&lt;SVM ID&gt;.brsvm.bedrock-01.com\\c$\\&lt;Volume name&gt;)
3. Upload the [Bedrock user guide](https://docs.aws.amazon.com/pdfs/bedrock/latest/userguide/bedrock-ug.pdf) to the shared network drive and set permissions to the Admin user only (ensure that you **Disable inheritance** under **Advanced settings**)
4. Upload the [FSx ONTAP user guide](https://docs.aws.amazon.com/pdfs/fsx/latest/ONTAPGuide/ONTAPGuide.pdf#getting-started) to the shared drive and ensure permissions are set to Everyone
5. On the _ad_host_ server open the command prompt and type the following command to obtain the SID for the Admin user:
```
wmic useraccount where name='Admin' get sid
```

#### Start periodic migration of FSxN data to AOSS

Mount and run the Embeddings container to periodically populate an index in the AOSS vector search collection with existing files and folders along with their security access control list (ACL) configurations from the FSx for ONTAP file system.

1. Navigate to Systems Manager Fleet Manager on your AWS console, locate the  _embedding_host_ instance, click the **Node actions** button and select **Start terminal session** to login to the _embedding_host_

> Optional: If Embedding container fails because of FSxN storage mount makse sure you mount and start the Embeddings Container. 
>
> 1. Navigate to FSx ONTAP on your AWS console and click on **Storage Virtual Machines** and obtain values for the SVM ID and File System ID parameters. 
> 2. Navigate to Amazon Elastic Container Registry on your AWS console and click on **Repositories** and obtain the value of the URI parameter for the fsxnragembed image name.
> 3. Run the following:  
>
>```
>sudo mount -t nfs <SVM ID>.<File system ID>:/ragdb /tmp/db
>sudo docker run -d -v /tmp/data:/opt/netapp/ai/data -v /tmp/db:/opt/netapp/ai/db -e ENV_REGION=<AWS_REGION> -e ENV_OPEN_SEARCH_SERVERLESS_COLLECTION_NAME=fsxnragvector <URI for fsxnragembed image>
>```
#### Test permissions-based RAG scenario with Bedrock and FSx for ONTAP

##### Use the Chatbot

Obtain the _lb-dns-name_ URL from the output of your Terraform template and access it via your web browser.

For the prompt query, ask any general question on the FSxN user guide that is available for access to everyone. You will see a response in the chat window as well as the source attribution used by the model for the response.

Now ask a question about the Bedrock user guide that has access restricted to the Admin user. You can see the model will not return an answer related to this query. Use the Admin SID on the User (SID) filter search in the chat UI and ask the same question again in the prompt. You will now see a response in the chat window as well as the source attribution used by the model for the response.

##### Query using API Gateway

You can also query the model directly using API Gateway. Obtain the *api-invoke-url* parameter from the output of your Terraform template

1. Here’s the curl request you can use for invoking API Gateway with *Everyone* access for a query related to the FSxN user guide. Note that the value of the *metadata* parameter is set to *NA* to indicate *Everyone* access. 
```
curl -v '<api-invoke-url>/bedrock_rag_retreival' -X POST -H 'content-type: application/json' -d '{"session_id": "1","prompt": "What is an FSxN ONTAP filesystem?", "bedrock_model_id": "anthropic.claude-3-sonnet-20240229-v1:0", "model_kwargs": {"temperature": 1.0, "top_p": 1.0, "top_k": 500}, "metadata": "NA", "memory_window": 10}'
```
2. Here’s the curl request you can use for invoking API Gateway with *Admin* access for a query related to the Bedrock user guide. Note that the value of the *metadata* parameter is set to the *SID* of the Admin user.
```
curl -v '<api-invoke-url>/bedrock_rag_retreival' -X POST -H 'content-type: application/json' -d '{"session_id": "1","prompt": "what is bedrock?", "bedrock_model_id": "anthropic.claude-3-sonnet-20240229-v1:0", "model_kwargs": {"temperature": 1.0, "top_p": 1.0, "top_k": 500}, "metadata": "S-1-5-21-4037439088-1296877785-2872080499-1112", "memory_window": 10}'
```

### Clean up

To avoid recurring charges, and to clean up your account after trying the solution outlined in this post, perform the following steps:

1. From the _terraform_ folder, delete the Terraform template for the solution:
```
terraform apply --destroy
```