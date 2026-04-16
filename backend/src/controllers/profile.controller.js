const profileService = require('../services/profile.service');
const catchAsync = require('../utils/catchAsync');

const getProfile = catchAsync(async (req, res) => {
  const profile = await profileService.getProfile(req.user.id);
  res.status(200).json(profile);
});

const updateProfile = catchAsync(async (req, res) => {
  const profile = await profileService.updateProfile(req.user.id, req.body);
  res.status(200).json(profile);
});

const uploadPhotos = catchAsync(async (req, res) => {
  const photos = await profileService.uploadPhotos(req.user.id, req.files);
  res.status(200).json({ photos });
});

const deletePhoto = catchAsync(async (req, res) => {
  const photos = await profileService.deletePhoto(
    req.user.id,
    req.params.publicId
  );
  res.status(200).json({ photos });
});

const reorderPhotos = catchAsync(async (req, res) => {
  const photos = await profileService.reorderPhotos(req.user.id, req.body.photoIds);
  res.status(200).json({ photos });
});

module.exports = { getProfile, updateProfile, uploadPhotos, deletePhoto, reorderPhotos };
