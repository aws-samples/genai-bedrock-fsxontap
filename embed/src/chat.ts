import 'dotenv/config';
import { defaultProvider } from '@aws-sdk/credential-provider-node';
import { formatDocumentsAsString } from 'langchain/util/document';
import { BedrockChat } from '@langchain/community/chat_models/bedrock';
import { PromptTemplate } from '@langchain/core/prompts';
import { RunnableSequence, RunnablePassthrough } from '@langchain/core/runnables';
import { StringOutputParser } from '@langchain/core/output_parsers';
import { BedrockEmbeddings } from '@langchain/community/embeddings/bedrock';
import { OpenSearchVectorStore } from '@langchain/community/vectorstores/opensearch';
import ora from 'ora';
import figlet from 'figlet';
import inquirer from 'inquirer';
import boxen from 'boxen';
import { listCollections } from './aws/opensearchserverless';
import { getClient } from './opensearch';

async function main() {
    // use external region if provided
    if (process.env.ENV_REGION) {
        process.env.REGION = process.env.ENV_REGION;
    }

    // use external collection name if provided
    if (process.env.ENV_OPEN_SEARCH_SERVERLESS_COLLECTION_NAME) {
        process.env.OPEN_SEARCH_SERVERLESS_COLLECTION_NAME = process.env.ENV_OPEN_SEARCH_SERVERLESS_COLLECTION_NAME;
    }

    const {
        REGION,
        OPEN_SEARCH_SERVERLESS_COLLECTION_NAME,
        PROFILE,
        BEDROCK_EMBEDDING_MODEL_ID,
        VECTOR_STORE_RETRiEVAL_SIZE,
        BEDROCK_CHAT_MODEL_ID,
        BEDROCK_CHAT_MODEL_TEMPERATURE,
        BEDROCK_CHAT_MODEL_MAX_TOKENS
    } = process.env;

    console.log(`Operating in region ${REGION}, collection name ${OPEN_SEARCH_SERVERLESS_COLLECTION_NAME}`);

    console.log(
        figlet.textSync('NetApp AI chat', {
            font: 'Standard',
            horizontalLayout: 'default',
            verticalLayout: 'default',
            width: 80,
            whitespaceBreak: true
        })
    );

    const spinner = ora('Listing collections').start();

    const collections = await listCollections(REGION);
    const collection = collections.find(({ name }) => name === OPEN_SEARCH_SERVERLESS_COLLECTION_NAME);

    if (!collection) {
        console.error(`Collection ${OPEN_SEARCH_SERVERLESS_COLLECTION_NAME} is not found in region ${REGION}`);
        process.exit(-1);
    }
    spinner.succeed('Collection found');

    spinner.start('Creating opensearch client');
    const client = getClient(REGION, `https://${collection.id}.${REGION}.aoss.amazonaws.com`);
    spinner.succeed('Opensearch client created');

    spinner.start('Creating Bedrock embedding client');
    const bedrockEmbeddings = new BedrockEmbeddings({
        region: REGION,
        model: BEDROCK_EMBEDDING_MODEL_ID,
        credentials: defaultProvider({ profile: PROFILE })
    });
    spinner.succeed('Bedrock embedding client created');

    const indexName = `${OPEN_SEARCH_SERVERLESS_COLLECTION_NAME}-index`;

    spinner.start('Creating Langchain vector store');
    const vectorStore = new OpenSearchVectorStore(bedrockEmbeddings, {
        client,
        service: 'aoss',
        indexName,
        metadataFieldName: 'metadata',
        textFieldName: 'text',
        vectorFieldName: 'vector_field'
    });
    spinner.succeed('Langchain vector store created');

    spinner.start('Creating Langchain vector store retriever');
    // S-1-1-0 = everyone
    const retriever = vectorStore.asRetriever(parseInt(VECTOR_STORE_RETRiEVAL_SIZE), {
        'acl.allowed': ['S-1-1-0', 'put here any additional SID']
    });
    spinner.succeed('Langchain vector store retriever created');

    //
    // Use LCEL (LangChain Expression Language) for RAG
    // https://js.langchain.com/docs/expression_language/cookbook/retrieval
    //
    // Another approach is to use chains directly
    // https://js.langchain.com/docs/modules/chains/
    //
    const prompt = PromptTemplate.fromTemplate(`Answer the question based only on the following context:
{context}

Question: {question}`);

    const bedrockChat = new BedrockChat({
        region: REGION,
        model: BEDROCK_CHAT_MODEL_ID,
        credentials: defaultProvider({ profile: PROFILE }),
        temperature: parseInt(BEDROCK_CHAT_MODEL_TEMPERATURE),
        maxTokens: parseInt(BEDROCK_CHAT_MODEL_MAX_TOKENS),
        streaming: false
    });

    spinner.start('Creating Langchain runnable sequence');
    const chain = RunnableSequence.from([
        {
            context: retriever.pipe(formatDocumentsAsString),
            question: new RunnablePassthrough()
        },
        prompt,
        bedrockChat,
        new StringOutputParser()
    ]);
    spinner.succeed('Langchain runnable sequence created');

    while (true) {
        const { question } = await inquirer.prompt<{ question: string }>({
            type: 'input',
            name: 'question',
            message: 'What is your question?'
        });
        spinner.start('Running RAG sequence');
        const answer = await chain.invoke(question);
        spinner.stop();
        console.log(boxen(answer, { title: 'Amazon Bedrock', titleAlignment: 'center' }));
    }
}

main();
