import { defaultProvider } from '@aws-sdk/credential-provider-node';
import { STSClient, GetCallerIdentityCommand } from '@aws-sdk/client-sts';

export async function getCallerIdentity(region: string) {
    const client = new STSClient({
        region,
        credentialDefaultProvider: () => defaultProvider({ profile: process.env.PROFILE })
    });
    const { Arn } = await client.send(new GetCallerIdentityCommand());

    return Arn!;
}
