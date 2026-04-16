const { Router } = require('express');
const messageController = require('../controllers/message.controller');
const { validate } = require('../middleware/validate.middleware');
const { messageLimiter } = require('../middleware/rateLimiter.middleware');
const { sendMessageSchema } = require('../validators/message.validator');
const validateObjectId = require('../middleware/validateObjectId.middleware');

const router = Router();

router.get('/:matchId', validateObjectId('matchId'), messageController.getMessages);
router.post('/', messageLimiter, validate(sendMessageSchema), messageController.sendMessage);
router.put('/:matchId/seen', validateObjectId('matchId'), messageController.markSeen);

module.exports = router;
