const mockRedis = {
  set: jest.fn().mockResolvedValue('OK'),
  get: jest.fn().mockResolvedValue(null),
};

jest.mock('../../../src/models/User');
jest.mock('../../../src/models/Otp');
jest.mock('../../../src/utils/otp');
jest.mock('../../../src/utils/token');
jest.mock('../../../src/config/redis', () => ({
  getRedis: () => mockRedis,
}));
jest.mock('../../../src/config', () => ({
  googleClientId: 'test-client-id',
  otpExpiryMinutes: 5,
  jwtAccessSecret: 'access-secret',
  jwtRefreshSecret: 'refresh-secret',
  jwtAccessExpiry: '15m',
  jwtRefreshExpiry: '7d',
  nodeEnv: 'test',
}));

const User = require('../../../src/models/User');
const Otp = require('../../../src/models/Otp');
const { generateOtp, sendOtpEmail } = require('../../../src/utils/otp');
const { signAccessToken, signRefreshToken, hashRefreshToken, verifyRefreshToken } = require('../../../src/utils/token');
const authService = require('../../../src/services/auth.service');

const mockUser = {
  _id: 'user123',
  email: 'test@example.com',
  gender: 'male',
  banned: false,
  refreshToken: null,
  fcmTokens: [],
  save: jest.fn().mockResolvedValue(true),
  toObject: jest.fn().mockReturnValue({ _id: 'user123', email: 'test@example.com' }),
};

beforeEach(() => {
  jest.clearAllMocks();
  generateOtp.mockReturnValue('123456');
  sendOtpEmail.mockResolvedValue(undefined);
  signAccessToken.mockReturnValue('access-token');
  signRefreshToken.mockReturnValue('refresh-token');
  hashRefreshToken.mockReturnValue('hashed-token');
});

describe('sendOtp', () => {
  it('generates OTP, saves to DB, sends email', async () => {
    Otp.deleteMany = jest.fn().mockResolvedValue({});
    Otp.create = jest.fn().mockResolvedValue({});

    const result = await authService.sendOtp('test@example.com');

    expect(Otp.deleteMany).toHaveBeenCalledWith({ email: 'test@example.com' });
    expect(Otp.create).toHaveBeenCalledWith(
      expect.objectContaining({ email: 'test@example.com', code: '123456' })
    );
    expect(sendOtpEmail).toHaveBeenCalledWith('test@example.com', '123456');
    expect(result.message).toBe('OTP sent successfully');
  });
});

describe('verifyOtp', () => {
  const validOtp = {
    email: 'test@example.com',
    code: '123456',
    expiresAt: new Date(Date.now() + 60000),
  };

  it('rejects invalid OTP', async () => {
    Otp.findOne = jest.fn().mockResolvedValue(null);

    await expect(authService.verifyOtp('test@example.com', 'wrong')).rejects.toThrow('Invalid or expired OTP');
  });

  it('rejects expired OTP', async () => {
    Otp.findOne = jest.fn().mockResolvedValue({
      ...validOtp,
      expiresAt: new Date(Date.now() - 1000),
    });
    Otp.deleteMany = jest.fn().mockResolvedValue({});

    await expect(authService.verifyOtp('test@example.com', '123456')).rejects.toThrow('OTP expired');
  });

  it('creates new user when not found and dateOfBirth is provided', async () => {
    Otp.findOne = jest.fn().mockResolvedValue(validOtp);
    Otp.deleteMany = jest.fn().mockResolvedValue({});
    User.findOne = jest.fn().mockResolvedValue(null);
    User.create = jest.fn().mockResolvedValue({ ...mockUser });

    const result = await authService.verifyOtp('test@example.com', '123456', '1995-01-01');

    expect(User.create).toHaveBeenCalled();
    expect(result.isNewUser).toBe(true);
  });

  it('rejects new user without dateOfBirth', async () => {
    Otp.findOne = jest.fn().mockResolvedValue(validOtp);
    Otp.deleteMany = jest.fn().mockResolvedValue({});
    User.findOne = jest.fn().mockResolvedValue(null);

    await expect(authService.verifyOtp('test@example.com', '123456')).rejects.toThrow('Date of birth is required');
  });

  it('rejects underage users', async () => {
    Otp.findOne = jest.fn().mockResolvedValue(validOtp);
    Otp.deleteMany = jest.fn().mockResolvedValue({});
    User.findOne = jest.fn().mockResolvedValue(null);

    await expect(
      authService.verifyOtp('test@example.com', '123456', '2015-01-01')
    ).rejects.toThrow('18 or older');
  });

  it('returns existing user on correct OTP', async () => {
    Otp.findOne = jest.fn().mockResolvedValue(validOtp);
    Otp.deleteMany = jest.fn().mockResolvedValue({});
    User.findOne = jest.fn().mockResolvedValue({ ...mockUser });

    const result = await authService.verifyOtp('test@example.com', '123456');

    expect(result.isNewUser).toBe(false);
    expect(result.accessToken).toBe('access-token');
  });
});

describe('refreshTokens', () => {
  it('rejects invalid refresh token', async () => {
    verifyRefreshToken.mockImplementation(() => { throw new Error('invalid'); });

    await expect(authService.refreshTokens('bad-token')).rejects.toThrow('Invalid refresh token');
  });

  it('rejects token when atomic swap fails (hash mismatch or reuse)', async () => {
    verifyRefreshToken.mockReturnValue({ id: 'user123' });
    hashRefreshToken.mockReturnValue('old-hash');
    signRefreshToken.mockReturnValue('new-refresh-token');
    User.findOneAndUpdate = jest.fn().mockResolvedValue(null);
    User.findByIdAndUpdate = jest.fn().mockResolvedValue({});

    await expect(authService.refreshTokens('old-token')).rejects.toThrow('Invalid refresh token');
    expect(User.findByIdAndUpdate).toHaveBeenCalledWith('user123', { refreshToken: null });
  });

  it('rotates tokens on valid refresh', async () => {
    verifyRefreshToken.mockReturnValue({ id: 'user123' });
    hashRefreshToken.mockReturnValue('hashed');
    signRefreshToken.mockReturnValue('new-refresh-token');
    signAccessToken.mockReturnValue('new-access-token');
    User.findOneAndUpdate = jest.fn().mockResolvedValue({ ...mockUser });

    const result = await authService.refreshTokens('valid-token');

    expect(result.accessToken).toBe('new-access-token');
    expect(result.refreshToken).toBe('new-refresh-token');
  });
});

describe('logout', () => {
  it('clears refresh token and blacklists access token jti', async () => {
    User.findByIdAndUpdate = jest.fn().mockResolvedValue({});

    await authService.logout('user123', { jti: 'abc-jti', exp: Math.floor(Date.now() / 1000) + 900 });

    expect(User.findByIdAndUpdate).toHaveBeenCalledWith('user123', { refreshToken: null });
    expect(mockRedis.set).toHaveBeenCalledWith('blacklist:abc-jti', '1', 'EX', expect.any(Number));
  });

  it('does not blacklist if no jti provided', async () => {
    User.findByIdAndUpdate = jest.fn().mockResolvedValue({});
    jest.clearAllMocks();
    User.findByIdAndUpdate = jest.fn().mockResolvedValue({});

    await authService.logout('user123', {});

    expect(mockRedis.set).not.toHaveBeenCalled();
  });
});
