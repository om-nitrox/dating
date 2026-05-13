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
  // Cloudinary publicIds contain slashes (e.g. "reverse-match/users/u123/abc").
  // Express 5 path-to-regexp v8 wildcards produce an array of segments — join
  // them back. Older URL-encoded callers (no slashes in raw path) show up as a
  // string, so handle both shapes.
  const raw = req.params.publicId;
  const publicId = Array.isArray(raw) ? raw.join('/') : raw;
  await profileService.deletePhoto(req.user.id, publicId);
  // Spec §2: response is empty object.
  res.status(200).json({});
});

const reorderPhotos = catchAsync(async (req, res) => {
  const photos = await profileService.reorderPhotos(req.user.id, req.body.photoIds);
  res.status(200).json({ photos });
});

const uploadSelfie = catchAsync(async (req, res) => {
  const result = await profileService.uploadSelfie(req.user.id, req.file);
  res.status(200).json(result);
});

const registerFcmToken = catchAsync(async (req, res) => {
  const { token } = req.body;
  const deviceId = req.body.deviceId || req.headers['x-device-id'];
  const result = await profileService.registerFcmToken(req.user.id, token, deviceId);
  res.status(200).json(result);
});

module.exports = {
  getProfile,
  updateProfile,
  uploadPhotos,
  deletePhoto,
  reorderPhotos,
  uploadSelfie,
  registerFcmToken,
};
