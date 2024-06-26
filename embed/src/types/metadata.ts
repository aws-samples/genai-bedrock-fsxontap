// source and loc - default langchain metadata
export interface DefaultMetadata {
    source: string;
    loc: {
        from: number;
        to: number;
    };
}

export interface ExtendedMetadata extends DefaultMetadata, Omit<FileMetadata, 'path' | 'ino'> {}

export interface FileMetadata {
    path: string;
    ino: number;
    mtimeMs: number;
    size: number;
    acl?: {
        allowed: string[];
        denied: string[];
    };
}
