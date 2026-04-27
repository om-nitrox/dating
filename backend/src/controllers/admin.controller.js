const adminService = require('../services/admin.service');
const catchAsync = require('../utils/catchAsync');

const listReports = catchAsync(async (req, res) => {
  const { status = 'pending', cursor, limit } = req.query;
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

module.exports = { listReports, resolveReport, banUser, getUserProfile };
