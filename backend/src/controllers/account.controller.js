const accountService = require('../services/account.service');
const catchAsync = require('../utils/catchAsync');

const deleteAccount = catchAsync(async (req, res) => {
  // Socket cleanup
  const io = req.app.get('io');
  if (io) {
    // Disconnect user's sockets
    const sockets = await io.in(req.user.id).fetchSockets();
    for (const s of sockets) {
      s.disconnect(true);
    }
  }

  await accountService.deleteAccount(req.user.id);
  res.status(200).json({ message: 'Account deleted successfully' });
});

module.exports = { deleteAccount };
