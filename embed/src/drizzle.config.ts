import { defineConfig } from 'drizzle-kit';

export default defineConfig({
    schema: './dist/compare/schema.js',
    dialect: 'sqlite',
    out: './migrations',
    verbose: true,
    strict: true,
    dbCredentials: {
        url: process.env.INTERNAL_DB
    }
});
