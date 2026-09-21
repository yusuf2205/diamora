/** Integration tests run against a REAL PostgreSQL 17 (embedded binaries started in global-setup). */
module.exports = {
  rootDir: '.',
  testRegex: 'test/.*\\.spec\\.ts$',
  moduleFileExtensions: ['js', 'json', 'ts'],
  testEnvironment: 'node',
  globalSetup: '<rootDir>/test/support/global-setup.cjs',
  globalTeardown: '<rootDir>/test/support/global-teardown.cjs',
  testTimeout: 60000,
  transform: {
    '^.+\\.ts$': [
      '@swc/jest',
      {
        jsc: {
          target: 'es2022',
          parser: { syntax: 'typescript', decorators: true },
          transform: { legacyDecorator: true, decoratorMetadata: true },
        },
        module: { type: 'commonjs' },
      },
    ],
  },
};
