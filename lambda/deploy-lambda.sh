#This is develoment time script. It is meant for manual redeployment of the lambda and is not part of the initial build automation
# bash ./deploy-lambda.sh will build and deploy the lambda code in this folder.
ACCOUNTID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
ECR_URL=$ACCOUNTID.dkr.ecr.$REGION.amazonaws.com
FUNCTION_NAME=bedrock_rag_retreival
IMAGE_NAME=fsxnragvector 


aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL
docker build --no-cache -t $ECR_URL/$IMAGE_NAME:latest .
docker image push $ECR_URL/$IMAGE_NAME:latest 
aws lambda update-function-code \
           --function-name $FUNCTION_NAME \
           --image-uri $ECR_URL/$IMAGE_NAME:latest \
           --publish \
           --no-paginate \
           --output text
