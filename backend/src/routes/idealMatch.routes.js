const { Router } = require('express');
const idealMatchController = require('../controllers/idealMatch.controller');

const router = Router();

// GET /api/v1/ideal-match
// Spec §11: returns the highest-similarity candidate plus alternates.
router.get('/', idealMatchController.getIdealMatch);

module.exports = router;
