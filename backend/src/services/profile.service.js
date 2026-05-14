const User = require('../models/User');
const PendingImageDelete = require('../models/PendingImageDelete');
const { uploadImage, deleteImage } = require('./upload.service');
const { upsertFcmToken } = require('./notification.service');
const { invalidateIdealMatch } = require('./idealMatch.service');
const { bumpCacheVersion } = require('../utils/cache');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');

const MAX_PHOTOS = 6;
const MIN_PHOTOS = 2;

const UPDATABLE_FIELDS = [
  'name',
  'dob',
  'age',
  'gender',
  'pronouns',
  'orientation',
  'bio',
  'exercise',
  'zodiac',
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
];

const ageFromDob = (dob) => {
  if (!dob) return undefined;
  const now = new Date();
  let age = now.getFullYear() - dob.getFullYear();
  const m = now.getMonth() - dob.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < dob.getDate())) age--;
  return age;
};

const computeIsProfileComplete = (user) => !!(user.name && user.age && user.gender && user.photos.length >= 2);

const stripPrivate = (userDoc) => {
  const obj = userDoc.toObject ? userDoc.toObject() : userDoc;
  delete obj.refreshToken;
  delete obj.fcmTokens;
  delete obj.selfiePhoto;
  delete obj.__v;
  return obj;
};

const getProfile = async (userId) => {
  const user = await User.findById(userId).select(
    '-refreshToken -fcmTokens -selfiePhoto -__v',
  );
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

  let locationChanged = false;
  if (data.location) {
    const prev = user.location?.coordinates;
    const next = data.location.coordinates || prev;
    if (
      !prev
      || !next
      || prev[0] !== next[0]
      || prev[1] !== next[1]
    ) {
      locationChanged = true;
    }
    user.location = {
      type: 'Point',
      coordinates: next,
      city: data.location.city ?? user.location?.city,
      state: data.location.state ?? user.location?.state,
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

  // Spec §11: the ideal-match cache is per-user with 24h TTL; bust on any
  // profile edit so the next request recomputes against fresh data.
  await invalidateIdealMatch(userId);

  // If the user moved (or set their first location), bump the feed/exclude
  // cache versions so the next /swipe/feed read recomputes from the new geo.
  if (locationChanged) {
    await Promise.all([
      bumpCacheVersion('feed', userId),
      bumpCacheVersion('exclude', userId),
    ]);
  }

  return stripPrivate(user);
};

const uploadPhotos = async (userId, files) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  if (user.photos.length >= MAX_PHOTOS) {
    throw new AppError(`Maximum ${MAX_PHOTOS} photos allowed`, 400);
  }

  if (user.photos.length + files.length > MAX_PHOTOS) {
    throw new AppError(`Cannot upload ${files.length} photos: would exceed the ${MAX_PHOTOS}-photo limit`, 400);
  }

  const uploads = await Promise.all(
    files.map((file) => uploadImage(file.buffer, userId)),
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

  // Spec §2: reject with 400 if deletion would leave user below the minimum.
  // Only enforce once the user has already passed the threshold — otherwise a
  // freshly-uploaded photo could not be removed during onboarding.
  if (user.photos.length <= MIN_PHOTOS && user.isProfileComplete) {
    throw new AppError(
      `You must keep at least ${MIN_PHOTOS} photos`,
      400,
    );
  }

  // Mongo first, Cloudinary second — if the remote delete fails we still have
  // a consistent DB and an orphan asset to reap later. The opposite order
  // could leave the user holding a reference to a deleted asset on Cloudinary
  // failure recovery.
  user.photos.splice(photoIndex, 1);
  user.isProfileComplete = computeIsProfileComplete(user);
  await user.save();

  try {
    await deleteImage(publicId);
  } catch (err) {
    // Phase 1.2: persist to PendingImageDelete so the `media.reaper`
    // BullMQ repeatable job retries with exponential backoff. The user's
    // Mongo doc has already been updated above; the row is the SOLE record
    // of the orphan.
    try {
      await PendingImageDelete.updateOne(
        { publicId },
        {
          $setOnInsert: {
            publicId,
            nextAttemptAt: new Date(Date.now() + 60 * 1000),
          },
          $set: { lastError: String(err.message || err).slice(0, 500) },
        },
        { upsert: true },
      );
      logger.warn(
        {
          event: 'media.delete.deferred',
          publicId,
          err: err.message,
        },
        'Cloudinary delete failed; queued for reaper',
      );
    } catch (persistErr) {
      // If we can't even persist the orphan, log loudly — we now leak the
      // asset. This is the worst case but shouldn't be common.
      logger.error(
        {
          event: 'media.delete.deferred.persist_failed',
          publicId,
          err: persistErr.message,
        },
        'Failed to persist pending image delete; asset is leaked',
      );
    }
  }

  return user.photos;
};

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

const uploadSelfie = async (userId, file) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);
  if (!file) throw new AppError('Selfie file required', 400);

  // Save reference to any prior selfie so we can clean it up AFTER the new
  // upload + DB write succeed (see fix 20 — Mongo first, Cloudinary second).
  const previousPublicId = user.selfiePhoto?.publicId;

  const asset = await uploadImage(file.buffer, `${userId}/selfie`);

  user.selfiePhoto = asset;
  // TODO(verification): plug in face-match service here. Until then the badge
  // (isVerified) is gated on manual admin approval flipping
  // selfieReviewStatus = 'approved' AND isVerified = true.
  user.isVerified = false;
  user.selfieReviewStatus = 'pending';
  await user.save();

  if (previousPublicId) {
    // Mongo is already updated above; if Cloudinary delete fails the orphan
    // is logged and a future reaper can clean it up.
    deleteImage(previousPublicId).catch(() => {});
  }

  // Spec §2: response shape returns the (un)verified state and review status.
  return { verified: false, status: 'pending_review' };
};

/**
 * Register or update an FCM token for the given device.
 * Called when the client registers its push token after login.
 */
const registerFcmToken = async (userId, token, deviceId) => {
  if (!token || !deviceId) {
    throw new AppError('token and deviceId are required', 400);
  }
  await upsertFcmToken(userId, token, deviceId);
  return { message: 'FCM token registered' };
};

module.exports = {
  getProfile,
  updateProfile,
  uploadPhotos,
  deletePhoto,
  reorderPhotos,
  uploadSelfie,
  registerFcmToken,
};
