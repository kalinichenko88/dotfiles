---
name: typescript-conventions
description: Use when writing or reviewing TypeScript — declaring an object shape, naming a new file, writing a callback — or when setting up lint rules for a new TypeScript project.
---

# TypeScript conventions

A codebase that consistently does otherwise wins — match it and say so.

## Object shapes are `type`, never `interface`

```ts
type User = { id: string; name: string };    // yes
interface User { id: string; name: string }  // no
```

Extension is intersection: `type Admin = User & { role: Role }`.

`interface` is correct for exactly two things — declaration merging and module
augmentation (`declare module 'x' { interface Y { … } }`). Each one carries a
comment naming which; without it it reads as a slip.

Biome: `lint/style/useConsistentTypeDefinitions` at `error`, `style: "type"`.
ESLint: `@typescript-eslint/consistent-type-definitions` set to `"type"`.
Biome does not see `interface X extends Y` — close that bypass with an AST check
only where the guarantee matters.

## `strict: true`, and no `any`

Reach for `unknown` plus a narrowing guard, or a generic. An `any` that survives
review is a type hole, not a shortcut.

## Bodies are braced and expanded

No implicit arrow returns in callbacks and handlers, no one-line braced `if`.
The body goes on its own line, even when it is one statement.

## Files are kebab-case, one entity per file

`create-vault.ts`, not `createVault.ts`. Intra-file order: imports → the primary
export → private helpers below it.
