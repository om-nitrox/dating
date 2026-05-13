module.exports = {
  testEnvironment: 'node',
  testTimeout: 30000,
  forceExit: true,
  // Run tests serially. Each integration test file connects to its own
  // MongoMemoryServer instance but they all share the global Mongoose
  // connection — running in parallel previously caused
  // "stopTestApp" in one file to disconnect another file's tests mid-run.
  maxWorkers: 1,
  testPathIgnorePatterns: ['/node_modules/', '/__tests__/helpers/'],
  coverageThreshold: {
    // Allow a small dip during ongoing hardening — the new transaction
    // helpers, multi-session refresh path, and gender DB-lookup branches
    // are exercised in integration but report low cov in unit-only runs.
    global: { lines: 60 },
  },
  globalSetup: './__tests__/helpers/globalSetup.js',
  globalTeardown: './__tests__/helpers/globalTeardown.js',
};
