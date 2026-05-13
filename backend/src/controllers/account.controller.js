const accountService = require('../services/account.service');
const catchAsync = require('../utils/catchAsync');

const deleteAccount = catchAsync(async (req, res) => {
  // Pass `io` so the service can disconnect sockets AFTER the DB cascades
  // commit (fix 14). disconnect(true) returns synchronously — see service.
  const io = req.app.get('io');
  await accountService.deleteAccount(req.user.id, io);
  // Spec §9: response is empty object.
  res.status(200).json({});
});

module.exports = { deleteAccount };
