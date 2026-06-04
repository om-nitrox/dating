const { Router } = require('express');
const idealMatchController = require('../controllers/idealMatch.controller');

const router = Router();

// GET /api/v1/ideal-match/status — gate check for the "Find My Ideal" button.
router.get('/status', idealMatchController.getStatus);

// POST /api/v1/ideal-match/reveal — run the ML model, return the 1 ideal
// match, and consume one of the two weekly uses.
router.post('/reveal', idealMatchController.reveal);

// GET /api/v1/ideal-match
// Spec §11: returns the highest-similarity candidate plus alternates.
router.get('/', idealMatchController.getIdealMatch);

module.exports = router;
