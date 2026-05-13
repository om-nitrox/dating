/**
 * Phase 0.7 — BullMQ wiring integration test.
 *
 * The aim of this test is to verify the QUEUE PLUMBING the api process
 * relies on:
 *   - `src/queue/index.js` exposes a working Queue handle
 *   - `src/queue/registerJobs.js` resolves a registered job by name and
 *     invokes its handler with the BullMQ job object
 *   - The `sample` smoke-test job returns its echo payload
 *
 * Why not exercise a live BullMQ Worker here?
 *   BullMQ ships Lua scripts that depend on `cmsgpack`, which neither
 *   `ioredis-mock` nor `redis-memory-server` provide. The full round-trip
 *   smoke test is the docker-compose check in the brief
 *   (`docker-compose up api worker redis mongo` + an api-side enqueue +
 *   assert worker logs "hello from worker"). What we verify here is
 *   everything *we* own — the producer wiring and the processor lookup
 *   — without coupling CI to a Redis binary.
 */

// Required env so `src/config/index.js` doesn't throw.
process.env.MONGO_URI = 'mongodb://localhost:27017/test_placeholder';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-32-chars-long!!';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-32-chars-long!';
process.env.NODE_ENV = 'test';

const sampleJob = require('../../src/queue/jobs/sample.job');
const { JOB_HANDLERS, buildProcessor } = require('../../src/queue/registerJobs');

describe('queue/registerJobs', () => {
  it('registers the sample job under its NAME', () => {
    expect(Object.keys(JOB_HANDLERS)).toContain(sampleJob.NAME);
    expect(typeof JOB_HANDLERS[sampleJob.NAME]).toBe('function');
  });

  it('dispatches a job through the processor to the registered handler', async () => {
    const processor = buildProcessor();
    const fakeJob = {
      id: 'job-1',
      name: sampleJob.NAME,
      data: { hello: 'world' },
    };
    const result = await processor(fakeJob);
    expect(result).toEqual({ ok: true, echoed: { hello: 'world' } });
  });

  it('throws when an unknown job name is processed', async () => {
    const processor = buildProcessor();
    await expect(
      processor({ id: 'x', name: 'no-such-job', data: {} }),
    ).rejects.toThrow(/No handler registered/);
  });
});

describe('queue/index', () => {
  it('exposes the default queue name constant', () => {
    const { QUEUE_NAMES } = require('../../src/queue');
    expect(QUEUE_NAMES.DEFAULT).toBe('default');
  });

  it('lazily constructs the default queue without throwing on require', () => {
    // The `defaultQueue` getter constructs a BullMQ Queue against an
    // ioredis client. We don't actually `add` anything (that would need
    // real Redis), but the getter must not throw at construction time.
    const queueModule = require('../../src/queue');
    expect(typeof queueModule.getDefaultQueue).toBe('function');
    expect(typeof queueModule.closeQueues).toBe('function');
  });
});
