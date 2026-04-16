const cloudinary = require('../config/cloudinary');
const AppError = require('../utils/AppError');

/**
 * Validate image content by checking magic bytes (file signatures).
 * Prevents uploading malicious files with fake MIME types.
 */
const MAGIC_BYTES = {
  jpeg: [0xff, 0xd8, 0xff],
  png: [0x89, 0x50, 0x4e, 0x47],
  webp_riff: [0x52, 0x49, 0x46, 0x46], // RIFF header, followed by WEBP at offset 8
};

const validateImageContent = (buffer) => {
  if (!buffer || buffer.length < 12) {
    throw new AppError('Invalid image file', 400);
  }

  const bytes = [...buffer.subarray(0, 12)];

  const isJpeg =
    bytes[0] === MAGIC_BYTES.jpeg[0] &&
    bytes[1] === MAGIC_BYTES.jpeg[1] &&
    bytes[2] === MAGIC_BYTES.jpeg[2];

  const isPng =
    bytes[0] === MAGIC_BYTES.png[0] &&
    bytes[1] === MAGIC_BYTES.png[1] &&
    bytes[2] === MAGIC_BYTES.png[2] &&
    bytes[3] === MAGIC_BYTES.png[3];

  const isWebp =
    bytes[0] === MAGIC_BYTES.webp_riff[0] &&
    bytes[1] === MAGIC_BYTES.webp_riff[1] &&
    bytes[2] === MAGIC_BYTES.webp_riff[2] &&
    bytes[3] === MAGIC_BYTES.webp_riff[3] &&
    bytes[8] === 0x57 && // W
    bytes[9] === 0x45 && // E
    bytes[10] === 0x42 && // B
    bytes[11] === 0x50;   // P

  if (!isJpeg && !isPng && !isWebp) {
    throw new AppError('Invalid image format. Only JPEG, PNG, and WebP are accepted.', 400);
  }
};

const uploadImage = (buffer, userId) => {
  // Validate actual file content before uploading
  validateImageContent(buffer);

  return new Promise((resolve, reject) => {
    const uploadOptions = {
      folder: `reverse-match/users/${userId}`,
      transformation: [
        { width: 800, height: 1000, crop: 'limit' },
        { quality: 'auto', fetch_format: 'auto' },
      ],
    };

    // Enable Cloudinary's built-in moderation if configured
    // Set CLOUDINARY_MODERATION=true in env to enable (requires Cloudinary paid plan)
    if (process.env.CLOUDINARY_MODERATION === 'true') {
      uploadOptions.moderation = 'aws_rek';
    }

    const stream = cloudinary.uploader.upload_stream(
      uploadOptions,
      (error, result) => {
        if (error) {
          reject(new AppError('Image upload failed', 500));
          return;
        }

        // Check moderation result if enabled
        if (result.moderation && result.moderation.length > 0) {
          const modResult = result.moderation[0];
          if (modResult.status === 'rejected') {
            // Delete the rejected image from Cloudinary
            cloudinary.uploader.destroy(result.public_id).catch(() => {});
            reject(new AppError('Image rejected: content violates community guidelines', 400));
            return;
          }
        }

        resolve({
          url: result.secure_url,
          publicId: result.public_id,
        });
      }
    );

    stream.end(buffer);
  });
};

const deleteImage = async (publicId) => {
  await cloudinary.uploader.destroy(publicId);
};

module.exports = { uploadImage, deleteImage, validateImageContent };
