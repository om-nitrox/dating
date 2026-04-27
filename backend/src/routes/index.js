const { Router } = require('express');
const auth = require('../middleware/auth.middleware');
const requireGender = require('../middleware/gender.middleware');
const { globalLimiter } = require('../middleware/rateLimiter.middleware');

const authRoutes = require('./auth.routes');
const profileRoutes = require('./profile.routes');
const swipeRoutes = require('./swipe.routes');
const queueRoutes = require('./queue.routes');
const matchRoutes = require('./match.routes');
const messageRoutes = require('./message.routes');
const boostRoutes = require('./boost.routes');
const safetyRoutes = require('./safety.routes');
const accountRoutes = require('./account.routes');
const adminRoutes = require('./admin.routes');

const router = Router();

// Global rate limiter
router.use(globalLimiter);

// Public routes
router.use('/auth', authRoutes);

// Protected routes
router.use('/profile', auth, profileRoutes);
router.use('/swipe', auth, requireGender('female'), swipeRoutes);
router.use('/queue', auth, requireGender('male'), queueRoutes);
router.use('/matches', auth, matchRoutes);
router.use('/messages', auth, messageRoutes);
router.use('/boost', auth, requireGender('male'), boostRoutes);
router.use('/', auth, safetyRoutes);
router.use('/', auth, accountRoutes);

// Admin routes — auth middleware already applied, isAdmin checked inside admin.routes.js
router.use('/admin', auth, adminRoutes);

module.exports = router;
