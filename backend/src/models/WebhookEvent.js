const mongoose = require('mongoose');

const webhookEventSchema = new mongoose.Schema(
  {
    eventId: {
      type: String,
      required: true,
      unique: true,
    },
    type: {
      type: String,
      required: true,
    },
    processedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

// Auto-expire after 30 days to prevent unbounded growth
webhookEventSchema.index({ processedAt: 1 }, { expireAfterSeconds: 2592000 });

module.exports = mongoose.model('WebhookEvent', webhookEventSchema);
