const User = require('../models/User');
const { uploadImage, deleteImage } = require('./upload.service');
const AppError = require('../utils/AppError');

const getProfile = async (userId) => {
  const user = await User.findById(userId).select('-refreshToken -__v');
  if (!user) throw new AppError('User not found', 404);
  return user;
};

const updateProfile = async (userId, data) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  // Update allowed fields
  const allowedFields = [
    'name', 'age', 'gender', 'bio', 'interests',
    'location', 'preferences', 'fcmToken',
  ];

  for (const field of allowedFields) {
    if (data[field] !== undefined) {
      if (field === 'location' && data.location) {
        user.location = {
          type: 'Point',
          coordinates: data.location.coordinates || user.location.coordinates,
          city: data.location.city || user.location.city,
          state: data.location.state || user.location.state,
        };
      } else if (field === 'preferences' && data.preferences) {
        user.preferences = { ...user.preferences.toObject(), ...data.preferences };
      } else {
        user[field] = data[field];
      }
    }
  }

  // Check if profile is complete
  const isComplete =
    user.name &&
    user.age &&
    user.gender &&
    user.photos.length >= 2 &&
    user.bio &&
    user.interests.length >= 1;

  user.isProfileComplete = !!isComplete;
  await user.save();

  const result = user.toObject();
  delete result.refreshToken;
  delete result.__v;
  return result;
};

const uploadPhotos = async (userId, files) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  if (user.photos.length + files.length > 6) {
    throw new AppError('Maximum 6 photos allowed', 400);
  }

  const uploads = await Promise.all(
    files.map((file) => uploadImage(file.buffer, userId))
  );

  user.photos.push(...uploads);

  // Re-check profile completeness
  if (user.name && user.age && user.gender && user.photos.length >= 2 && user.bio) {
    user.isProfileComplete = true;
  }

  await user.save();

  return user.photos;
};

const deletePhoto = async (userId, publicId) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  const photoIndex = user.photos.findIndex((p) => p.publicId === publicId);
  if (photoIndex === -1) throw new AppError('Photo not found', 404);

  await deleteImage(publicId);
  user.photos.splice(photoIndex, 1);

  if (user.photos.length < 2) {
    user.isProfileComplete = false;
  }

  await user.save();
  return user.photos;
};

/**
 * Reorder photos by receiving the full array of publicIds in the desired order.
 */
const reorderPhotos = async (userId, orderedPublicIds) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  // Validate that all publicIds belong to this user
  const userPublicIds = new Set(user.photos.map((p) => p.publicId));
  for (const id of orderedPublicIds) {
    if (!userPublicIds.has(id)) {
      throw new AppError(`Photo not found: ${id}`, 400);
    }
  }

  if (orderedPublicIds.length !== user.photos.length) {
    throw new AppError('Must include all photos in reorder', 400);
  }

  // Reorder based on the provided order
  const photoMap = new Map(user.photos.map((p) => [p.publicId, p]));
  user.photos = orderedPublicIds.map((id) => photoMap.get(id));
  await user.save();

  return user.photos;
};

module.exports = { getProfile, updateProfile, uploadPhotos, deletePhoto, reorderPhotos };
