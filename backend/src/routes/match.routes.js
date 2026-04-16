const { Router } = require('express');
const matchController = require('../controllers/match.controller');
const { mutationLimiter } = require('../middleware/rateLimiter.middleware');
const validateObjectId = require('../middleware/validateObjectId.middleware');

const router = Router();

router.get('/', matchController.getMatches);
router.delete('/:matchId', mutationLimiter, validateObjectId('matchId'), matchController.deleteMatch);

module.exports = router;
