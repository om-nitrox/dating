/**
 * `sample` — smoke-test job for Phase 0.7.
 *
 * Used by the BullMQ integration test (`__tests__/integration/queue.test.js`)
 * and by manual `docker-compose up api worker` end-to-end verification.
 * Has no side effects; just logs and resolves with a fixed string the test
 * can assert against.
 */

const logger = require('../../utils/logger');

const NAME = 'sample';

const handler = async (job) => {
  logger.info(
    { jobId: job.id, name: job.name, data: job.data },
    'hello from worker',
  );
  return { ok: true, echoed: job.data };
};

module.exports = { NAME, handler };
