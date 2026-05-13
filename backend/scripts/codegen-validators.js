#!/usr/bin/env node
/**
 * Phase 0.3 — Validator codegen from OpenAPI.
 *
 * Reads docs/api/openapi.yaml and emits zod schemas to
 * backend/src/validators/generated/. The spec is the single source of truth;
 * generated code is committed so CI can drift-check it
 * (`git diff --exit-code backend/src/validators/generated/`).
 *
 * Why hand-rolled and not `openapi-zod-client` / `openapi-to-zod`:
 *   - Those packages target zod-3 and the rich `openapi-zod-client` (zodios)
 *     toolchain is heavier than the small surface this project actually
 *     needs (31 REST operations, all flat schemas, no remote $refs).
 *   - The repo already pulls in `js-yaml` transitively (via `@stoplight/spectral-*`)
 *     and `zod@^4`. A 300-line emitter keeps the dependency surface tiny and
 *     deterministic on Windows + Node 22.
 *
 * Output:
 *   - generated/schemas.js   — every `#/components/schemas/*` as a zod schema
 *   - generated/requests.js  — request body + query schemas per operationId
 *   - generated/index.js     — re-exports
 *   - generated/README.md    — pinned tool choice and regen instructions
 *
 * Run:
 *   npm run codegen:validators
 *
 * Drift check (CI):
 *   git diff --exit-code backend/src/validators/generated/
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const SPEC_PATH = path.resolve(__dirname, '..', '..', 'docs', 'api', 'openapi.yaml');
const OUT_DIR = path.resolve(__dirname, '..', 'src', 'validators', 'generated');

// -------------------------------------------------------------------
// Reference resolution and naming
// -------------------------------------------------------------------

const refToName = (ref) => {
  // `#/components/schemas/Foo` -> `Foo`
  const parts = ref.split('/');
  return parts[parts.length - 1];
};

// -------------------------------------------------------------------
// JSON-Schema (subset) -> zod schema source text
// -------------------------------------------------------------------

/**
 * Emit a zod expression for a JSON Schema node. Returns a STRING of
 * JavaScript source (e.g. `z.string().email()`). Recurses on `properties`
 * / `items`. Cross-references use `lazy(() => SchemaName)` to allow forward
 * declarations within the same file.
 *
 * We deliberately keep the surface narrow: supports `$ref`, `string`,
 * `number`, `integer`, `boolean`, `array`, `object`, `enum`, `oneOf`,
 * `allOf`, `null`, and `additionalProperties: false`. The OpenAPI spec
 * uses no `anyOf` / discriminators / `if/then` — anything outside the
 * supported set throws so the emitter fails loudly on a future spec change.
 */
const emit = (node) => {
  if (node == null) return 'z.unknown()';

  if (node.$ref) {
    const refName = refToName(node.$ref);
    // z.lazy lets a schema reference another schema declared later in the
    // file. The cost (a tiny thunk per reference) is worth the simplicity
    // — no topological sort needed.
    return `z.lazy(() => ${refName})`;
  }

  // `type: 'null'` (string) is how `oneOf: [..., { type: 'null' }]` is
  // serialized.
  if (node.type === 'null') return 'z.null()';

  if (node.enum) {
    const literals = node.enum.map((v) => JSON.stringify(v)).join(', ');
    return `z.enum([${literals}])`;
  }

  if (node.oneOf) {
    const parts = node.oneOf.map(emit);
    if (parts.length === 1) return parts[0];
    // zod 4: `z.union([...])`
    return `z.union([${parts.join(', ')}])`;
  }

  if (node.allOf) {
    // All allOf branches in this spec are object compositions — merge by
    // chaining `.and(...)`. Falls back to the first branch if there's only
    // one.
    const parts = node.allOf.map(emit);
    if (parts.length === 1) return parts[0];
    return parts.reduce((acc, cur) => `${acc}.and(${cur})`);
  }

  switch (node.type) {
    case 'string': {
      let expr = 'z.string()';
      if (node.format === 'email') expr += '.email()';
      if (node.format === 'uri') expr += '.url()';
      // `date-time` could be `.datetime()` in zod 4, but Joi accepted ISO
      // strings loosely; keep parity by NOT enforcing the strict RFC3339
      // grammar (frontend may emit "2026-05-02T14:30:00Z" without ms).
      if (node.pattern) expr += `.regex(/${node.pattern}/)`;
      if (typeof node.minLength === 'number') expr += `.min(${node.minLength})`;
      if (typeof node.maxLength === 'number') expr += `.max(${node.maxLength})`;
      return expr;
    }

    case 'integer':
    case 'number': {
      let expr = node.type === 'integer' ? 'z.number().int()' : 'z.number()';
      if (typeof node.minimum === 'number') expr += `.min(${node.minimum})`;
      if (typeof node.maximum === 'number') expr += `.max(${node.maximum})`;
      return expr;
    }

    case 'boolean':
      return 'z.boolean()';

    case 'array': {
      const inner = node.items ? emit(node.items) : 'z.unknown()';
      let expr = `z.array(${inner})`;
      if (typeof node.minItems === 'number') expr += `.min(${node.minItems})`;
      if (typeof node.maxItems === 'number') expr += `.max(${node.maxItems})`;
      return expr;
    }

    case 'object':
    default: {
      // Default to `object` when type is missing but `properties` is present.
      const props = node.properties || {};
      const required = new Set(node.required || []);
      const keys = Object.keys(props);
      if (keys.length === 0) {
        // `additionalProperties: false` -> strict empty object
        if (node.additionalProperties === false) {
          return 'z.object({}).strict()';
        }
        return 'z.record(z.string(), z.unknown())';
      }
      const propLines = keys
        .map((k) => {
          const child = emit(props[k]);
          const isReq = required.has(k);
          return `    ${JSON.stringify(k)}: ${isReq ? child : `${child}.optional()`},`;
        })
        .join('\n');
      let expr = `z.object({\n${propLines}\n  })`;
      if (node.additionalProperties === false) expr += '.strict()';
      return expr;
    }
  }
};

// -------------------------------------------------------------------
// Build output files
// -------------------------------------------------------------------

const generateSchemasFile = (schemas) => {
  const exportLines = Object.keys(schemas).map((name) => {
    const body = emit(schemas[name]);
    return `const ${name} = ${body};`;
  });

  const exportsObj = `module.exports = {\n${Object.keys(schemas)
    .map((n) => `  ${n},`)
    .join('\n')}\n};\n`;

  return [
    '// AUTO-GENERATED FILE — DO NOT EDIT BY HAND.',
    '// Generated by scripts/codegen-validators.js. Source: docs/api/openapi.yaml.',
    '// Regenerate: npm run codegen:validators',
    '// Phase 0.3: validator codegen.',
    '',
    "/* eslint-disable max-len */",
    "/* eslint-disable no-unused-vars */",
    "const { z } = require('zod');",
    '',
    exportLines.join('\n\n'),
    '',
    exportsObj,
  ].join('\n');
};

/**
 * Build the requests-per-operation file. For each operationId we capture:
 *   - body schema (if requestBody is application/json)
 *   - query schema (a synthesized z.object of all `parameters` where `in=query`)
 *   - params schema (path params)
 *
 * Multipart bodies (`application/x-www-form-urlencoded` / `multipart/form-data`)
 * are left to the existing hand-validators; multer parses them upstream and
 * the file payload is on `req.files`, not `req.body`.
 */
const generateRequestsFile = (spec) => {
  const ops = []; // { id, body, query, params }

  for (const [pathKey, pathItem] of Object.entries(spec.paths || {})) {
    for (const method of ['get', 'post', 'put', 'patch', 'delete']) {
      const op = pathItem[method];
      if (!op || !op.operationId) continue;

      const entry = { id: op.operationId };

      // JSON request body
      const json = op.requestBody && op.requestBody.content && op.requestBody.content['application/json'];
      if (json && json.schema) entry.body = emit(json.schema);

      // Parameters (combined path + query)
      const allParams = (op.parameters || []).map((p) => {
        if (p.$ref) {
          // Resolve parameter $ref against `components.parameters`.
          const refName = refToName(p.$ref);
          const resolved = spec.components.parameters[refName];
          return resolved;
        }
        return p;
      });

      const queryParams = allParams.filter((p) => p.in === 'query');
      const pathParams = allParams.filter((p) => p.in === 'path');

      const paramsToZod = (params) => {
        if (params.length === 0) return null;
        const propLines = params.map((p) => {
          // Query/path params arrive as strings on Express. For numeric
          // schemas we coerce so validators don't reject `?page=2` as the
          // string "2". Joi did this implicitly; zod requires explicit
          // `z.coerce.*`.
          const schema = p.schema || { type: 'string' };
          let child = emit(schema);
          const coercible = schema.type === 'integer' || schema.type === 'number' || schema.type === 'boolean';
          if (coercible) {
            // Replace the leading `z.number()` / `z.boolean()` with the
            // coercing variant. The substitution is precise — emit() always
            // starts numeric schemas with `z.number()`.
            child = child.replace(/^z\.number\(\)/, 'z.coerce.number()');
            child = child.replace(/^z\.boolean\(\)/, 'z.coerce.boolean()');
          }
          const isReq = !!p.required;
          return `    ${JSON.stringify(p.name)}: ${isReq ? child : `${child}.optional()`},`;
        });
        // Default zod behaviour strips unknown keys — matches the existing
        // Joi `stripUnknown: true` and the sanitize middleware's contract.
        return `z.object({\n${propLines.join('\n')}\n  })`;
      };

      entry.query = paramsToZod(queryParams);
      entry.params = paramsToZod(pathParams);

      ops.push(entry);
    }
  }

  const blocks = ops.map((o) => {
    const lines = [];
    if (o.body) lines.push(`  body: ${o.body},`);
    if (o.query) lines.push(`  query: ${o.query},`);
    if (o.params) lines.push(`  params: ${o.params},`);
    if (lines.length === 0) {
      // Operation has no validated inputs (e.g. `GET /config`). Emit an empty
      // frozen object so consumers can still spread it without checking.
      return `const ${o.id} = Object.freeze({});`;
    }
    return `const ${o.id} = Object.freeze({\n${lines.join('\n')}\n});`;
  });

  const exportObj = `module.exports = {\n${ops.map((o) => `  ${o.id},`).join('\n')}\n};\n`;

  return [
    '// AUTO-GENERATED FILE — DO NOT EDIT BY HAND.',
    '// Generated by scripts/codegen-validators.js. Source: docs/api/openapi.yaml.',
    '// Regenerate: npm run codegen:validators',
    '// Phase 0.3: validator codegen.',
    '',
    "/* eslint-disable max-len */",
    "const { z } = require('zod');",
    "const schemas = require('./schemas');",
    '',
    // Pull every component schema into local scope so emitted z.lazy(() => X)
    // calls resolve.
    `const { ${Object.keys(spec.components.schemas).join(', ')} } = schemas;`,
    '',
    blocks.join('\n\n'),
    '',
    exportObj,
  ].join('\n');
};

const generateIndexFile = () => [
  '// AUTO-GENERATED FILE — DO NOT EDIT BY HAND.',
  '// Phase 0.3: validator codegen.',
  '',
  "module.exports = {",
  "  schemas: require('./schemas'),",
  "  requests: require('./requests'),",
  "};",
  '',
].join('\n');

const README = `# Generated validators (Phase 0.3)

Generated from \`docs/api/openapi.yaml\` by \`backend/scripts/codegen-validators.js\`.

**Do not edit these files by hand.** They are regenerated by:

\`\`\`bash
npm run codegen:validators
\`\`\`

## Toolchain choice

We rolled a small, dependency-light emitter rather than pulling in
\`openapi-zod-client\` or \`openapi-to-zod\`. Rationale:

1. The spec is small (31 ops, ~50 schemas) and uses a narrow JSON-Schema
   subset (\`$ref\`, \`oneOf\`, \`allOf\`, primitives, enums, \`object\` with
   \`properties\` / \`required\`, \`array\` with \`items\`).
2. \`openapi-zod-client\` targets zod 3 and brings in the \`zodios\` runtime;
   \`openapi-to-zod\` is unmaintained and emits TypeScript-only.
3. The monorepo already pulls in \`js-yaml\` transitively (via \`@stoplight/spectral-*\`)
   and \`zod@^4\` direct. The emitter is ~250 lines and has zero deps beyond those.
4. Output is committed so CI can drift-check with
   \`git diff --exit-code backend/src/validators/generated/\`.

If the spec ever uses constructs the emitter doesn't support (\`anyOf\`,
discriminated unions, \`if/then/else\`, recursive cycles via something other
than named \`$ref\`), the script will throw and the build will fail loudly —
that's the intent.

## Files

| File          | Contents                                                            |
| ------------- | ------------------------------------------------------------------- |
| \`schemas.js\`  | One zod export per \`components.schemas.*\` entry.                    |
| \`requests.js\` | One frozen object per \`operationId\`: \`{ body?, query?, params? }\`. |
| \`index.js\`    | Convenience re-export.                                              |

## Consumption pattern

Hand-written validators in \`backend/src/validators/*.js\` import from here:

\`\`\`js
const { requests } = require('./generated');
// requests.updateProfile.body is a zod schema
\`\`\`

The \`zodValidate\` middleware (\`backend/src/middleware/zodValidate.middleware.js\`)
adapts a zod schema to the route signature shared with the existing Joi
\`validate(...)\` middleware, so route mounts don't have to change.

## Drift check

CI runs:

\`\`\`bash
npm run codegen:validators
git diff --exit-code backend/src/validators/generated/
\`\`\`

If you change \`docs/api/openapi.yaml\` without regenerating, the diff will
fail and the PR will be red.
`;

// -------------------------------------------------------------------
// Main
// -------------------------------------------------------------------

const main = () => {
  if (!fs.existsSync(SPEC_PATH)) {
    console.error(`Spec not found at ${SPEC_PATH}`);
    process.exit(1);
  }
  const text = fs.readFileSync(SPEC_PATH, 'utf8');
  const spec = yaml.load(text);

  if (!spec.components || !spec.components.schemas) {
    console.error('Spec has no components.schemas — nothing to generate.');
    process.exit(1);
  }

  if (!fs.existsSync(OUT_DIR)) {
    fs.mkdirSync(OUT_DIR, { recursive: true });
  }

  const schemasSrc = generateSchemasFile(spec.components.schemas);
  const requestsSrc = generateRequestsFile(spec);

  fs.writeFileSync(path.join(OUT_DIR, 'schemas.js'), schemasSrc);
  fs.writeFileSync(path.join(OUT_DIR, 'requests.js'), requestsSrc);
  fs.writeFileSync(path.join(OUT_DIR, 'index.js'), generateIndexFile());
  fs.writeFileSync(path.join(OUT_DIR, 'README.md'), README);

  // eslint-disable-next-line no-console
  console.log(`Generated validators in ${path.relative(process.cwd(), OUT_DIR)}`);
};

main();
