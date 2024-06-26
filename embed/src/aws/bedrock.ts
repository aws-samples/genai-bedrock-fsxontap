import { defaultProvider } from '@aws-sdk/credential-provider-node';
import { BedrockClient, GetFoundationModelCommand } from '@aws-sdk/client-bedrock';

export async function getFoundationModel(region: string, modelIdentifier: string) {
    const client = new BedrockClient({
        region,
        credentialDefaultProvider: () => defaultProvider({ profile: process.env.PROFILE })
    });

    const { modelDetails } = await client.send(new GetFoundationModelCommand({ modelIdentifier }));

    return modelDetails;
}
