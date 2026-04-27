module.exports = {
  testEnvironment: 'node',
  testTimeout: 30000,
  forceExit: true,
  testPathIgnorePatterns: ['/node_modules/', '/__tests__/helpers/'],
  coverageThreshold: {
    global: { lines: 70 },
  },
  globalSetup: './__tests__/helpers/globalSetup.js',
  globalTeardown: './__tests__/helpers/globalTeardown.js',
};
