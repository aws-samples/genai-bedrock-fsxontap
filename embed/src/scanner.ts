import { lstat, readdir } from 'node:fs/promises';
import { extname, join } from 'node:path';
import { exec } from 'node:child_process';
import { platform } from 'node:os';

const SUPPORTED_EXTENSIONS = ['.txt', '.csv', '.pdf'];

export async function scan(directory: string) {
    console.log('Scanning directory:', directory);

    //
    // using simple scanning strategy
    // for production use case 'open directory' API should be used
    // https://nodejs.org/docs/latest/api/fs.html#fspromisesopendirpath-options
    //
    const dirents = await readdir(directory, { recursive: true, withFileTypes: true });
    console.log(`${dirents.length} dirents found`);

    const files = dirents.filter(dirent => dirent.isFile() && SUPPORTED_EXTENSIONS.includes(extname(dirent.name)));
    console.log('Files with supported extensions', files.length);

    return Promise.all(
        files.map(async ({ name, parentPath }) => {
            const path = join(parentPath, name);
            const { ino, mtimeMs, ctimeMs, size } = await lstat(path);

            const acl = await getACL(path);

            return {
                path,
                ino,
                mtimeMs,
                ctimeMs,
                size,
                // ready ACL on linux machines only
                acl: platform() === 'linux' ? acl : undefined
            };
        })
    );
}

async function getACL(path: string) {
    try {
        const response = await execute(`getcifsacl "${path}"`);

        const parsedAcl = response
            .split('\n')
            .filter(acl => acl.startsWith('ACL'))
            .map(acl => {
                const [, sid, permissions] = acl.split(':');
                const [type, flags, masks] = permissions.split('/');

                return {
                    sid,
                    type: type as 'ALLOWED' | 'DENIED', // (ALLOWED / DENIED)
                    flags, // inheritance flag (OI|CI|IO|I)
                    masks // permission
                };
            });

        const acl = parsedAcl.filter(acl => ['R', 'FULL', 'READ', 'CHANGE'].includes(acl.masks));

        return {
            allowed: [...new Set(acl.filter(({ type }) => type === 'ALLOWED').map(({ sid }) => sid))],
            denied: [...new Set(acl.filter(({ type }) => type === 'DENIED').map(({ sid }) => sid))]
        };
    } catch (err) {
        console.warn('Failed to get CIFS ACL for path', path);
    }
}

async function execute(command: string, timeout?: number) {
    return new Promise<string>((resolve, reject) => {
        exec(command, { timeout }, (error: any, stdout: string, stderr: string) => {
            if (error) {
                reject(new Error(stderr || stdout || `Command execution: ${command} - timed out`));
            } else {
                resolve(stdout);
            }
        });
    });
}
