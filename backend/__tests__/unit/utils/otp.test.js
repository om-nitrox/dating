/**
 * Unit tests for OTP hashing (fix 2).
 *
 * Verifies:
 *  - generateOtp produces 6-digit numeric codes
 *  - hashOtp is deterministic for the same input
 *  - Different codes hash to different outputs
 *  - Stored OTPs never carry the plaintext `code` field
 */

// Config relies on JWT_ACCESS_SECRET — point at a test value before require.
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'test-access-secret';
process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'test-refresh-secret';
process.env.MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/test';
process.env.OTP_PEPPER = 'unit-test-pepper';

const { generateOtp, hashOtp } = require('../../../src/utils/otp');
const Otp = require('../../../src/models/Otp');

describe('generateOtp', () => {
  it('returns a six-digit numeric string', () => {
    for (let i = 0; i < 50; i += 1) {
      const code = generateOtp();
      expect(code).toMatch(/^\d{6}$/);
    }
  });
});

describe('hashOtp', () => {
  it('produces deterministic output for the same code', () => {
    const a = hashOtp('123456');
    const b = hashOtp('123456');
    expect(a).toBe(b);
  });

  it('returns different hashes for different codes', () => {
    expect(hashOtp('123456')).not.toBe(hashOtp('123457'));
    expect(hashOtp('000000')).not.toBe(hashOtp('999999'));
  });

  it('outputs a hex string (64 chars for SHA-256)', () => {
    expect(hashOtp('123456')).toMatch(/^[0-9a-f]{64}$/);
  });
});

describe('Otp model', () => {
  it('does not allow saving a plaintext `code` field', () => {
    // The schema only declares email/codeHash/expiresAt. Mongoose will strip
    // unknown fields silently — verify the OTP doc never carries plaintext.
    const doc = new Otp({
      email: 'x@x.com',
      code: '123456',
      codeHash: hashOtp('123456'),
      expiresAt: new Date(Date.now() + 60000),
    });
    expect(doc.code).toBeUndefined();
    expect(doc.codeHash).toBeDefined();
  });
});
