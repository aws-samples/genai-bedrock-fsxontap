import { relations } from 'drizzle-orm';
import { text, integer, sqliteTable, index } from 'drizzle-orm/sqlite-core';

export const files = sqliteTable(
    'files',
    {
        id: integer('id', { mode: 'number' }).primaryKey({ autoIncrement: true }),
        scanId: text('scan_id').notNull(),
        ino: integer('ino').unique().notNull(),
        mtimeMs: integer('mtime_ms').notNull(),
        ctimeMs: integer('ctime_ms').notNull()
    },
    table => {
        return {
            inoIdx: index('ino_idx').on(table.ino),
            scanIdIdx: index('scan_id_idx').on(table.scanId)
        };
    }
);

export const documents = sqliteTable(
    'documents',
    {
        id: integer('id', { mode: 'number' }).primaryKey({ autoIncrement: true }),
        opensearchId: text('opensearch_id').unique().notNull(),
        fileId: integer('file_id', { mode: 'number' })
            .notNull()
            .references(() => files.id, { onDelete: 'cascade' })
    },
    table => {
        return {
            opensearchIdIdx: index('opensearch_id_idx').on(table.opensearchId)
        };
    }
);

export const filesRelations = relations(files, ({ many }) => ({
    documents: many(documents)
}));

export const documentsRelations = relations(documents, ({ one }) => ({
    file: one(files, {
        fields: [documents.fileId],
        references: [files.id]
    })
}));
