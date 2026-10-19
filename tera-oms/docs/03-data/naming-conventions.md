# Naming Conventions

- DB tables: `<module>_<entity>` (Prisma `@@map`)
- Prisma model: `PascalCase` matching the table's Pascal form
- Route: `/{module}/v1/{resource}`
- Events: `<module>.<past_tense_verb>`
- Packages: `@tera/<name>`
- Frontend module folder: kebab-case matching screen
