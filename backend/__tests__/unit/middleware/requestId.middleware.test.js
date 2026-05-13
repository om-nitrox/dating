const requestId = require('../../../src/middleware/requestId.middleware');

const makeReqRes = (incomingId) => {
  const headers = {};
  if (incomingId !== undefined) headers['x-request-id'] = incomingId;
  const req = { headers };
  const res = {
    setHeader: jest.fn(),
  };
  const next = jest.fn();
  return { req, res, next };
};

describe('requestId middleware', () => {
  it('generates a UUIDv4 when no X-Request-Id is supplied', () => {
    const { req, res, next } = makeReqRes();
    requestId(req, res, next);

    expect(typeof req.id).toBe('string');
    expect(req.id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    expect(res.setHeader).toHaveBeenCalledWith('X-Request-Id', req.id);
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('reuses a well-formed incoming X-Request-Id', () => {
    const incoming = 'flutter-client-abc-123';
    const { req, res, next } = makeReqRes(incoming);
    requestId(req, res, next);

    expect(req.id).toBe(incoming);
    expect(res.setHeader).toHaveBeenCalledWith('X-Request-Id', incoming);
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('rejects an incoming id with invalid characters and generates a new one', () => {
    const incoming = "evil\r\nInjected-Header: hack";
    const { req, res, next } = makeReqRes(incoming);
    requestId(req, res, next);

    expect(req.id).not.toBe(incoming);
    expect(req.id).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('rejects an oversized incoming id and generates a new one', () => {
    const incoming = 'a'.repeat(200);
    const { req, res, next } = makeReqRes(incoming);
    requestId(req, res, next);

    expect(req.id).not.toBe(incoming);
    expect(req.id.length).toBe(36); // uuid v4
  });

  it('attaches a child logger as req.log', () => {
    const { req, res, next } = makeReqRes();
    requestId(req, res, next);

    expect(req.log).toBeDefined();
    expect(typeof req.log.info).toBe('function');
    expect(typeof req.log.warn).toBe('function');
    expect(typeof req.log.error).toBe('function');
  });

  it('isValidIncomingId helper accepts URL-safe ids only', () => {
    const { isValidIncomingId } = requestId;
    expect(isValidIncomingId('abc-123')).toBe(true);
    expect(isValidIncomingId('Aa1.-_:')).toBe(true);
    expect(isValidIncomingId('has space')).toBe(false);
    expect(isValidIncomingId('with\n')).toBe(false);
    expect(isValidIncomingId('')).toBe(false);
    expect(isValidIncomingId(undefined)).toBe(false);
    expect(isValidIncomingId('a'.repeat(129))).toBe(false);
  });
});
