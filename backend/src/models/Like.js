const mongoose = require('mongoose');

const likeSchema = new mongoose.Schema(
  {
    fromUser: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    toUser: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected', 'skipped'],
      default: 'pending',
    },
  },
  {
    timestamps: true,
  }
);

// Prevent duplicate likes / skips
likeSchema.index({ fromUser: 1, toUser: 1 }, { unique: true });

// Fast queue lookup for boys (pending likes addressed to them)
likeSchema.index({ toUser: 1, status: 1 });

// Fast lookup of all likes sent by a user (for exclusion list in feed)
likeSchema.index({ fromUser: 1, status: 1 });

module.exports = mongoose.model('Like', likeSchema);
