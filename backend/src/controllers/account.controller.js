const accountService = require('../services/account.service');
const catchAsync = require('../utils/catchAsync');

const deleteAccount = catchAsync(async (req, res) => {
  // Pass `io` so the service can disconnect sockets AFTER the DB cascades
  // commit (fix 14). disconnect(true) returns synchronously — see service.
  const io = req.app.get('io');
  // Phase 1.17: capture requesterIp so the DeletionRequest audit row has
  // it for fraud / regulatory investigations.
  const requesterIp = req.ip || (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || null;
  await accountService.deleteAccount(req.user.id, io, { requesterIp });
  // Spec §9: response is empty object.
  res.status(200).json({});
});

/**
 * Phase 1.17 — GET /account/export
 *
 * Returns the authenticated user's data as a JSON document. Frontend wraps
 * the response in a "Download data" button and writes the JSON to a file
 * client-side. The Content-Disposition hint makes Curl / browser direct
 * fetches drop the file naturally; in-app fetches see a plain JSON body.
 */
const exportAccountData = catchAsync(async (req, res) => {
  const data = await accountService.exportAccountData(req.user.id);
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="reverse-match-export-${req.user.id}.json"`,
  );
  res.status(200).json(data);
});

module.exports = { deleteAccount, exportAccountData };
