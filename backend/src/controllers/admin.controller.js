const adminService = require('../services/admin.service');
const catchAsync = require('../utils/catchAsync');

const listReports = catchAsync(async (req, res) => {
  const { status = 'pending', cursor, limit } = req.cleanQuery;
  const result = await adminService.listReports(status, cursor, parseInt(limit, 10) || 20);
  res.status(200).json(result);
});

const resolveReport = catchAsync(async (req, res) => {
  const { id } = req.params;
  const { banUser = false } = req.body;
  const result = await adminService.resolveReport(id, req.user.id, banUser);
  res.status(200).json(result);
});

const banUser = catchAsync(async (req, res) => {
  const { id } = req.params;
  const result = await adminService.banUserById(id, req.user.id);
  res.status(200).json(result);
});

const getUserProfile = catchAsync(async (req, res) => {
  const { id } = req.params;
  const result = await adminService.getAdminUserProfile(id);
  res.status(200).json(result);
});

// -------- Phase 1.3: selfie review queue --------

const listPendingSelfies = catchAsync(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 20;
  const result = await adminService.listPendingSelfies(page, limit);
  res.status(200).json(result);
});

const approveSelfie = catchAsync(async (req, res) => {
  const { userId } = req.params;
  const result = await adminService.approveSelfie(userId, req.user.id);
  res.status(200).json(result);
});

const rejectSelfie = catchAsync(async (req, res) => {
  const { userId } = req.params;
  const { reason } = req.body || {};
  const result = await adminService.rejectSelfie(userId, req.user.id, reason);
  res.status(200).json(result);
});

module.exports = {
  listReports,
  resolveReport,
  banUser,
  getUserProfile,
  // Phase 1.3
  listPendingSelfies,
  approveSelfie,
  rejectSelfie,
};
