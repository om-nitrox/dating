const { Router } = require('express');
const messageController = require('../controllers/message.controller');
const { validate } = require('../middleware/validate.middleware');
const { messageLimiter } = require('../middleware/rateLimiter.middleware');
const { sendMessageSchema } = require('../validators/message.validator');
const validateObjectId = require('../middleware/validateObjectId.middleware');
const { idempotency } = require('../middleware/idempotency.middleware');

const router = Router();

router.get('/:matchId', validateObjectId('matchId'), messageController.getMessages);
// Phase 1.4: idempotency on POST /messages — flaky network duplicates here
// produced double-sent messages in v0.
router.post(
  '/',
  messageLimiter,
  idempotency({ routeBase: '/messages' }),
  validate(sendMessageSchema),
  messageController.sendMessage,
);
router.put('/:matchId/seen', validateObjectId('matchId'), messageController.markSeen);

module.exports = router;
