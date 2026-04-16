const { Router } = require('express');
const profileController = require('../controllers/profile.controller');
const { validate } = require('../middleware/validate.middleware');
const { updateProfileSchema, reorderPhotosSchema } = require('../validators/profile.validator');
const { mutationLimiter } = require('../middleware/rateLimiter.middleware');
const upload = require('../middleware/upload.middleware');

const router = Router();

router.get('/', profileController.getProfile);
router.put('/', validate(updateProfileSchema), profileController.updateProfile);
router.post('/photos', mutationLimiter, upload.array('photos', 6), profileController.uploadPhotos);
router.put('/photos/reorder', mutationLimiter, validate(reorderPhotosSchema), profileController.reorderPhotos);
router.delete('/photos/:publicId', mutationLimiter, profileController.deletePhoto);

module.exports = router;
