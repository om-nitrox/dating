const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema(
  {
    reporter: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    reported: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    reason: {
      type: String,
      enum: ['harassment', 'fake', 'inappropriate', 'spam', 'other'],
      required: true,
    },
    details: {
      type: String,
      maxlength: 500,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for admin queries
reportSchema.index({ reported: 1 });
reportSchema.index({ createdAt: -1 });
reportSchema.index({ reporter: 1, reported: 1 });

module.exports = mongoose.model('Report', reportSchema);
