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
  ],
};
