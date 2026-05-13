const multer = require('multer');
const config = require('../config');
const AppError = require('../utils/AppError');

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  const allowed = ['image/jpeg', 'image/png', 'image/webp'];
  if (allowed.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new AppError('Only JPEG, PNG, and WebP images are allowed', 400), false);
  }
};

// 5MB per file by default — lower than the previous 10MB to reduce memory
// pressure when multiple uploads land concurrently. Configurable via
// MAX_PHOTO_SIZE_BYTES if a larger ceiling is genuinely needed.
const MAX_FILES = 6;

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: config.maxPhotoSizeBytes,
    files: MAX_FILES,
    // Hard caps on the multipart parser so a hostile client can't make us
    // allocate unbounded memory just by sending a flood of empty fields/parts.
    fields: 20,
    parts: MAX_FILES + 20,
    // Defense in depth — total bytes accepted across all files.
    fieldSize: 1024 * 1024,
  },
});

module.exports = upload;
