const { Router } = require('express');
const accountController = require('../controllers/account.controller');
const { validate } = require('../middleware/validate.middleware');
const { deleteAccountSchema } = require('../validators/account.validator');

const router = Router();

router.delete('/account', validate(deleteAccountSchema), accountController.deleteAccount);

module.exports = router;
