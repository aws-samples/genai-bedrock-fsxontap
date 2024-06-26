import { eq, ne } from 'drizzle-orm';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { migrate } from 'drizzle-orm/better-sqlite3/migrator';
import Database from 'better-sqlite3';
import { files, documents, filesRelations, documentsRelations } from './schema';

//
// Connect to the internal DB and run initial migration
//
const sqlite = new Database(process.env.INTERNAL_DB);
const db = drizzle(sqlite, { schema: { files, documents, filesRelations, documentsRelations } });

await migrate(db, {
    migrationsFolder: './migrations',
    migrationsTable: 'migrations'
});

export async function findFileByIno(ino: number) {
    return db.query.files.findFirst({ where: eq(files.ino, ino) });
}

export async function insertFile(ino: number, mtimeMs: number, ctimeMs: number, scanId: string) {
    return db.insert(files).values({ ino, mtimeMs, ctimeMs, scanId }).returning({ fileId: files.id });
}

export async function insertDocuments(fileId: number, ids: string[]) {
    return db.insert(documents).values(ids.map(id => ({ fileId, opensearchId: id })));
}

export async function updateFileScanIdById(fileId: number, scanId: string) {
    return db.update(files).set({ scanId }).where(eq(files.id, fileId));
}

export async function updateFileCtimeById(fileId: number, ctimeMs: number) {
    return db.update(files).set({ ctimeMs }).where(eq(files.id, fileId));
}

export async function findFileById(fileId: number) {
    return db.query.files.findFirst({ where: eq(files.id, fileId), with: { documents: true } });
}

export async function deleteFileById(fileId: number) {
    // ON DELETE cascade enabled in documents to file foreign key - deleting file will delete all referencing documents
    return db.delete(files).where(eq(files.id, fileId));
}

export async function deleteFilesByNotScanId(scanId: string) {
    // ON DELETE cascade enabled in documents to file foreign key - deleting file will delete all referencing documents
    return db.delete(files).where(ne(files.scanId, scanId));
}

export async function findFilesByNotScanId(scanId: string) {
    return db.query.files.findMany({ where: ne(files.scanId, scanId), with: { documents: true } });
}
