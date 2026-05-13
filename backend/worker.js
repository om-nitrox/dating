/**
 * Standalone worker entrypoint (Phase 0.7).
 *
 * This process is intentionally separate from the api so that:
 *   1. Long jobs cannot starve the api event loop.
 *   2. The worker can be scaled / restarted / pinned to different
 *      hosts independently.
 *   3. The api Dockerfile can be slimmer (no job code in the image is
 *      not realistic in v1 since both share src/, but the deployment
 *      manifest treats them as distinct units).
 *
 * Responsibilities on boot:
 *   - Load .env (`dotenv`)
 *   - Connect MongoDB (reuses `src/config/db.js`)
 *   - Build BullMQ Worker(s) with all handlers from `registerJobs`
 *   - Expose a `/metrics` endpoint on `config.workerMetricsPort` for
 *     Prometheus scraping (item 0.9 will add full metrics — for now we
 *     just expose the default Node process metrics + BullMQ counters).
 *   - Handle SIGTERM / SIGINT for graceful shutdown.
 */

require('dotenv').config();

const http = require('http');
const { Worker } = require('bullmq');

const config = require('./src/config');
const connectDB = require('./src/config/db');
const logger = require('./src/utils/logger');
const {
  QUEUE_NAMES, getQueueConnection, closeQueues,
} = require('./src/queue');
const { buildProcessor } = require('./src/queue/registerJobs');
// Phase 0.9: shared metrics registry — same names exposed on both api
// (port 5000) and worker (port 9091) so the Prometheus scrape config and
// Grafana dashboards can target either by job label.
const {
  register, jobProcessedTotal, jobDurationSeconds,
} = require('./src/observability/metrics');

let httpServer;
let worker;
let shuttingDown = false;

const startMetricsServer = () => new Promise((resolve, reject) => {
  httpServer = http.createServer(async (req, res) => {
    if (req.url === '/metrics' && req.method === 'GET') {
      try {
        res.setHeader('Content-Type', register.contentType);
        res.end(await register.metrics());
      } catch (err) {
        res.statusCode = 500;
        res.end(err.message);
      }
      return;
    }
    if (req.url === '/health' && req.method === 'GET') {
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ status: 'ok', worker: true }));
      return;
    }
    res.statusCode = 404;
    res.end('not found');
  });

  httpServer.on('error', reject);
  httpServer.listen(config.workerMetricsPort, () => {
    logger.info(
      { port: config.workerMetricsPort },
      'Worker metrics server listening on /metrics',
    );
    resolve();
  });
});

// -------- BullMQ worker --------
const startWorker = () => {
  const processor = buildProcessor();
  const queue = QUEUE_NAMES.DEFAULT;

  worker = new Worker(
    queue,
    async (job) => {
      // Phase 0.9: structured-log + metric instrumentation.
      const log = logger.child({ job_id: job.id, job_name: job.name });
      const start = process.hrtime.bigint();
      log.info({ event: 'job.started' }, 'job started');
      try {
        const result = await processor(job);
        const elapsedSec = Number(process.hrtime.bigint() - start) / 1e9;
        jobProcessedTotal.labels({ queue, job: job.name, status: 'completed' }).inc();
        jobDurationSeconds.labels({ queue, job: job.name }).observe(elapsedSec);
        log.info({ event: 'job.completed', durationSec: elapsedSec }, 'job completed');
        return result;
      } catch (err) {
        const elapsedSec = Number(process.hrtime.bigint() - start) / 1e9;
        jobProcessedTotal.labels({ queue, job: job.name, status: 'failed' }).inc();
        jobDurationSeconds.labels({ queue, job: job.name }).observe(elapsedSec);
        log.error({ event: 'job.failed', err: err.message, durationSec: elapsedSec }, 'job failed');
        throw err;
      }
    },
    {
      connection: getQueueConnection(),
      prefix: config.bullmqQueuePrefix,
      // Concurrency is intentionally modest — easier to reason about under
      // load until we have full observability (item 0.9).
      concurrency: parseInt(process.env.WORKER_CONCURRENCY, 10) || 5,
    },
  );

  // BullMQ event listeners — independent of the processor callback so they
  // also fire for jobs that errored before reaching the processor (e.g.
  // serialization failures). The processor-side counters above remain the
  // authoritative count.
  worker.on('failed', (job, err) => {
    logger.warn(
      {
        event: 'job.failed',
        jobId: job?.id,
        jobName: job?.name,
        err: err.message,
      },
      'BullMQ job failed',
    );
  });

  worker.on('error', (err) => {
    logger.error({ err: err.message }, 'BullMQ worker error');
  });

  logger.info({ queue }, 'BullMQ worker started');
};

// -------- Bootstrap --------
const start = async () => {
  try {
    await connectDB();
    await startMetricsServer();
    startWorker();
    logger.info('Worker process ready');
  } catch (err) {
    logger.error({ err: err.message }, 'Worker startup failed');
    process.exit(1);
  }
};

// -------- Graceful shutdown --------
const shutdown = async (signal) => {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, 'Worker shutdown signal received');

  // Stop accepting new HTTP requests for /metrics
  if (httpServer) {
    await new Promise((resolve) => { httpServer.close(() => resolve()); });
  }

  // Drain the BullMQ worker — `close()` waits for active jobs to finish.
  if (worker) {
    try {
      await worker.close();
      logger.info('BullMQ worker closed');
    } catch (err) {
      logger.error({ err: err.message }, 'Error closing BullMQ worker');
    }
  }

  // Close shared Redis + Queue handles
  try {
    await closeQueues();
  } catch (err) {
    logger.error({ err: err.message }, 'Error closing BullMQ queues');
  }

  // Close Mongo
  try {
    const mongoose = require('mongoose');
    await mongoose.connection.close();
    logger.info('MongoDB connection closed');
  } catch (err) {
    logger.error({ err: err.message }, 'Error closing MongoDB');
  }

  process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('uncaughtException', (err) => {
  logger.error({ err }, 'Worker uncaught exception');
  shutdown('uncaughtException');
});

process.on('unhandledRejection', (reason) => {
  logger.error({ err: reason }, 'Worker unhandled rejection');
  if (config.nodeEnv === 'production') {
    shutdown('unhandledRejection');
  }
});

start();
