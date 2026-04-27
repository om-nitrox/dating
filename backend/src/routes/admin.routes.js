const { Router } = require('express');
const adminController = require('../controllers/admin.controller');
const isAdmin = require('../middleware/isAdmin.middleware');
const validateObjectId = require('../middleware/validateObjectId.middleware');

const router = Router();

// All routes here already have `auth` applied via the parent router.
// isAdmin additionally checks role === 'admin'.
router.use(isAdmin);

router.get('/reports', adminController.listReports);
router.post('/reports/:id/resolve', validateObjectId('id'), adminController.resolveReport);
router.post('/users/:id/ban', validateObjectId('id'), adminController.banUser);
router.get('/users/:id', validateObjectId('id'), adminController.getUserProfile);

module.exports = router;
