module.exports = {
  apps: [
    {
      name: 'reverse-match-api',
      script: 'server.js',
      instances: 'max', // Use all available CPU cores
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'development',
        PORT: 5000,
      },
      env_staging: {
        NODE_ENV: 'staging',
        PORT: 5000,
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 5000,
      },

      // Logging
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: './logs/error.log',
      out_file: './logs/out.log',
      merge_logs: true,

      // Restart policy
      max_memory_restart: '500M',
      max_restarts: 10,
      restart_delay: 1000,
      autorestart: true,

      // Graceful shutdown — 30s for draining 1500 connections
      kill_timeout: 30000,
      listen_timeout: 10000,
      shutdown_with_message: true,

      // Watch (dev only)
      watch: false,
    },
    // BullMQ worker (Phase 0.7).
    // Runs as a SEPARATE app — single fork instance to keep job ordering
    // semantics simple in v1. The api cluster (above) remains untouched so
    // we can scale them independently. Eventually the worker may move to
    // its own host entirely — keeping it in this same ecosystem.config.js
    // for now means `pm2 start ecosystem.config.js` brings the whole stack
    // up locally.
    {
      name: 'reverse-match-worker',
      script: 'worker.js',
      instances: 1,
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'development',
        WORKER_METRICS_PORT: 9091,
      },
      env_staging: {
        NODE_ENV: 'staging',
        WORKER_METRICS_PORT: 9091,
      },
      env_production: {
        NODE_ENV: 'production',
        WORKER_METRICS_PORT: 9091,
      },

      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: './logs/worker-error.log',
      out_file: './logs/worker-out.log',
      merge_logs: true,

      max_memory_restart: '500M',
      max_restarts: 10,
      restart_delay: 1000,
      autorestart: true,

      // Worker is single-instance; if it crashes we restart cleanly.
      kill_timeout: 30000,
      listen_timeout: 10000,
      shutdown_with_message: true,

      watch: false,
    },
  ],
};
