const { Router } = require('express');
const queueController = require('../controllers/queue.controller');
const { mutationLimiter } = require('../middleware/rateLimiter.middleware');
const validateObjectId = require('../middleware/validateObjectId.middleware');

const router = Router();

router.get('/', queueController.getQueue);
router.post('/accept/:likeId', mutationLimiter, validateObjectId('likeId'), queueController.accept);
router.post('/reject/:likeId', mutationLimiter, validateObjectId('likeId'), queueController.reject);

module.exports = router;
