import { defaultProvider } from '@aws-sdk/credential-provider-node';
import { AwsSigv4Signer } from '@opensearch-project/opensearch/aws';
import { Client } from '@opensearch-project/opensearch';
import { ExtendedMetadata } from './types/metadata';

export function getClient(region: string, endpoint: string) {
    const signer = AwsSigv4Signer({
        region,
        service: 'aoss',
        getCredentials: () => {
            const credentialsProvider = defaultProvider({ profile: process.env.PROFILE });
            return credentialsProvider();
        }
    });

    const client = new Client({
        ...signer,
        requestTimeout: 60000, // Also used for refreshing credentials in advance
        node: endpoint
    });

    return client;
}

export async function indexDocument(
    client: Client,
    indexName: string,
    data: { vector_field: number[]; text: string; metadata: ExtendedMetadata }
) {
    const { body, statusCode } = await client.index<{
        _index: string;
        _id: string;
        _version: number;
        result: 'created' | 'updated';
        _shards: { total: number; successful: number; failed: number };
        _seq_no: number;
        _primary_term: number;
    }>({ index: indexName, body: data });

    if (statusCode !== 201) {
        throw new Error(`Failed to index document, got status ${statusCode}`);
    }

    return body;
}

export async function bulkUpdate(client: Client, indexName: string, ids: { id: string }[], data: object) {
    const bulkStats = await client.helpers.bulk({
        datasource: ids,
        onDocument(id) {
            return [
                {
                    update: { _index: indexName, _id: id.id }
                },
                {
                    doc: data
                }
            ];
        }
    });

    if (bulkStats.successful !== ids.length) {
        console.error(bulkStats);
        throw new Error(`Failed to bulk update`);
    }

    return bulkStats;
}

export async function bulkDelete(client: Client, indexName: string, ids: string[]) {
    const bulkStats = await client.helpers.bulk({
        datasource: ids,
        onDocument(doc) {
            return {
                delete: { _index: indexName, _id: doc }
            };
        }
    });

    if (bulkStats.successful !== ids.length) {
        console.error(bulkStats);
        throw new Error(`Failed to bulk delete`);
    }

    return bulkStats;
}

export async function createIndex(client: Client, indexName: string) {
    return client.indices.create({
        index: indexName,
        body: {
            settings: {
                index: {
                    knn: true,
                    'knn.algo_param.ef_search': 512 // The size of the dynamic list used during k-NN searches. Higher values result in more accurate but slower searches
                }
            },
            mappings: {
                dynamic_templates: [
                    {
                        // map all metadata properties to be keyword
                        'metadata.*': {
                            match_mapping_type: 'string',
                            mapping: { type: 'keyword' }
                        }
                    },
                    {
                        'metadata.loc': {
                            match_mapping_type: 'object',
                            mapping: { type: 'object' }
                        }
                    },
                    {
                        'metadata.acl': {
                            match_mapping_type: 'object',
                            mapping: { type: 'object' }
                        }
                    }
                ],
                properties: {
                    metadata: {
                        type: 'object'
                    },
                    text: {
                        type: 'text'
                    },
                    vector_field: {
                        type: 'knn_vector', // type of index that allows k-nearest neighbor (k-NN) searches. This is required for vector searches
                        dimension: process.env.BEDROCK_EMBEDDING_MODEL_OUTPUT_VECTOR_SIZE,
                        method: {
                            name: 'hnsw', // Vector search collections only support the HNSW algorithm with Faiss - https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless-vector-search.html#serverless-vector-limitations
                            engine: 'faiss',
                            space_type: 'l2', // The space type used to calculate the distance/similarity between vectors
                            parameters: {
                                ef_construction: 512, // The size of the dynamic list used during k-NN graph creation. Higher values result in a more accurate graph but slower indexing speed. https://opensearch.org/docs/latest/search-plugins/knn/knn-index/,
                                m: 16
                            }
                        }
                    }
                }
            }
        }
    });
}
