import { lstat } from 'node:fs/promises';
import { dirname } from 'node:path';
import { getFoundationModel } from './aws/bedrock';
import { getCollection, listCollections } from './aws/opensearchserverless';

export async function validate() {
    // use external region if provided
    if (process.env.ENV_REGION) {
        process.env.REGION = process.env.ENV_REGION;
    }

    // use external collection name if provided
    if (process.env.ENV_OPEN_SEARCH_SERVERLESS_COLLECTION_NAME) {
        process.env.OPEN_SEARCH_SERVERLESS_COLLECTION_NAME = process.env.ENV_OPEN_SEARCH_SERVERLESS_COLLECTION_NAME;
    }

    const { REGION, BEDROCK_EMBEDDING_MODEL_ID, DATA_DIRECTORY, OPEN_SEARCH_SERVERLESS_COLLECTION_NAME, INTERNAL_DB } =
        process.env;

    // Verify data directory exists
    try {
        const stats = await lstat(DATA_DIRECTORY);
        if (!stats.isDirectory()) {
            throw new Error(`${DATA_DIRECTORY} is not a directory`);
        }
    } catch (err) {
        console.error(`Failed to get data directory status ${DATA_DIRECTORY}`, err);
        process.exit(-1);
    }

    // Verify internal db directory exists
    try {
        const directory = dirname(INTERNAL_DB);
        const stats = await lstat(directory);
        if (!stats.isDirectory()) {
            throw new Error(`${directory} is not a directory`);
        }
    } catch (err) {
        console.error(`Failed to get internal db status ${INTERNAL_DB}`, err);
        process.exit(-1);
    }

    // Verify embedding model exists
    try {
        await getFoundationModel(REGION, BEDROCK_EMBEDDING_MODEL_ID);
    } catch (err) {
        console.error(`Embedding model ${BEDROCK_EMBEDDING_MODEL_ID} not found in region ${REGION}`, err);
        process.exit(-1);
    }

    // validate existing collection status and type
    const collections = await listCollections(REGION);
    const collection = collections.find(({ name }) => name === OPEN_SEARCH_SERVERLESS_COLLECTION_NAME);
    if (collection) {
        const { status, type } = await getCollection(REGION, OPEN_SEARCH_SERVERLESS_COLLECTION_NAME);
        if (status !== 'ACTIVE' || type !== 'VECTORSEARCH') {
            console.error(
                `Collection ${OPEN_SEARCH_SERVERLESS_COLLECTION_NAME} in region ${REGION} is no active or not vector search`
            );
            process.exit(-1);
        }
    } else {
        console.error(`Unable to find collection ${OPEN_SEARCH_SERVERLESS_COLLECTION_NAME} in region ${REGION}`);
        process.exit(-1);
    }
}
