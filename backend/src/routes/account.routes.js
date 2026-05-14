const { Router } = require('express');
const accountController = require('../controllers/account.controller');
const { validate } = require('../middleware/validate.middleware');
const { deleteAccountSchema } = require('../validators/account.validator');

const router = Router();

router.delete('/account', validate(deleteAccountSchema), accountController.deleteAccount);
// Phase 1.17: GDPR data export. Returns the user's data as JSON.
router.get('/account/export', accountController.exportAccountData);

module.exports = router;
