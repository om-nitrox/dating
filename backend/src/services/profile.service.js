const User = require('../models/User');
const { uploadImage, deleteImage } = require('./upload.service');
const AppError = require('../utils/AppError');

// Fields that clients are allowed to update directly via PUT /profile.
// refreshToken, isVerified, selfiePhoto, boost* are intentionally excluded —
// they are mutated by dedicated endpoints or server-side logic.
const UPDATABLE_FIELDS = [
  'name',
  'dob',
  'age',
  'gender',
  'pronouns',
  'orientation',
  'bio',
  'interests',
  'prompts',
  'height',
  'ethnicity',
  'children',
  'familyPlans',
  'hometown',
  'jobTitle',
  'workplace',
  'education',
  'religion',
  'politics',
  'languages',
  'datingIntentions',
  'relationshipType',
  'fcmToken',
];

const ageFromDob = (dob) => {
  if (!dob) return undefined;
  const now = new Date();
  let age = now.getFullYear() - dob.getFullYear();
  const m = now.getMonth() - dob.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < dob.getDate())) age--;
  return age;
};

/**
 * A profile is "complete" when the user can realistically appear in the feed.
 * We only require the bare minimum — everything Hinge-style is optional.
 */
const computeIsProfileComplete = (user) =>
  !!(user.name && user.age && user.gender && user.photos.length >= 2);

const stripPrivate = (userDoc) => {
  const obj = userDoc.toObject ? userDoc.toObject() : userDoc;
  delete obj.refreshToken;
  delete obj.selfiePhoto;
  delete obj.__v;
  return obj;
};

const getProfile = async (userId) => {
  const user = await User.findById(userId).select('-refreshToken -__v');
  if (!user) throw new AppError('User not found', 404);
  return user;
};

const updateProfile = async (userId, data) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  for (const field of UPDATABLE_FIELDS) {
    if (data[field] === undefined) continue;

    if (field === 'dob') {
      user.dob = data.dob ? new Date(data.dob) : null;
      const derived = ageFromDob(user.dob);
      if (derived !== undefined) user.age = derived;
    } else {
      user[field] = data[field];
    }
  }

  // Nested merges — these are objects whose sub-keys we want to patch, not replace.
  if (data.location) {
    user.location = {
      type: 'Point',
      coordinates: data.location.coordinates || user.location.coordinates,
      city: data.location.city ?? user.location.city,
      state: data.location.state ?? user.location.state,
    };
  }
  if (data.preferences) {
    user.preferences = {
      ...user.preferences.toObject(),
      ...data.preferences,
    };
  }
  if (data.vices) {
    user.vices = {
      ...(user.vices ? user.vices.toObject() : {}),
      ...data.vices,
    };
  }

  user.isProfileComplete = computeIsProfileComplete(user);
  await user.save();

  return stripPrivate(user);
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
  user.isProfileComplete = computeIsProfileComplete(user);
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

  user.isProfileComplete = computeIsProfileComplete(user);
  await user.save();
  return user.photos;
};

/**
 * Reorder photos by receiving the full array of publicIds in the desired order.
 */
const reorderPhotos = async (userId, orderedPublicIds) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  const userPublicIds = new Set(user.photos.map((p) => p.publicId));
  for (const id of orderedPublicIds) {
    if (!userPublicIds.has(id)) {
      throw new AppError(`Photo not found: ${id}`, 400);
    }
  }

  if (orderedPublicIds.length !== user.photos.length) {
    throw new AppError('Must include all photos in reorder', 400);
  }

  const photoMap = new Map(user.photos.map((p) => [p.publicId, p]));
  user.photos = orderedPublicIds.map((id) => photoMap.get(id));
  await user.save();

  return user.photos;
};

/**
 * Store the user's selfie for verification.
 * Replaces any existing selfie. Sets isVerified=true in the current MVP.
 * The selfie is stored privately — never projected to other users.
 */
const uploadSelfie = async (userId, file) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);
  if (!file) throw new AppError('Selfie file required', 400);

  const asset = await uploadImage(file.buffer, `${userId}/selfie`);

  // Replace previous selfie if one exists
  if (user.selfiePhoto?.publicId) {
    deleteImage(user.selfiePhoto.publicId).catch(() => {
      /* non-fatal — old asset may already be gone */
    });
  }

  user.selfiePhoto = asset;
  user.isVerified = true;
  await user.save();

  return { isVerified: true };
};

module.exports = {
  getProfile,
  updateProfile,
  uploadPhotos,
  deletePhoto,
  reorderPhotos,
  uploadSelfie,
};
