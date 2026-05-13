// Phase 0.3: validator codegen.
// Queue route validators — sourced from the generated zod schemas in
// ./generated/requests.js. `getQueue` validates the page/limit query
// against the OpenAPI `getQueue` operation. `acceptLike` / `rejectLike`
// validate the path-parameter `likeId`.
const { requests } = require('./generated');

const getQueueQuery = requests.getQueue.query;
const acceptLikeParams = requests.acceptLike.params;
const rejectLikeParams = requests.rejectLike.params;

module.exports = { getQueueQuery, acceptLikeParams, rejectLikeParams };
