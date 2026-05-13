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
    // Phase 0.9: raised from 60 -> 65 after observability + event-bus
    // tests landed. Target is 70; remaining gap is the legacy
    // notification.service / upload.service code paths that need
    // dedicated integration coverage (TODO).
    global: { lines: 65 },
  },
  globalSetup: './__tests__/helpers/globalSetup.js',
  globalTeardown: './__tests__/helpers/globalTeardown.js',
};
