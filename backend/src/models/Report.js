const mongoose = require('mongoose');
const { REPORT_REASONS, REPORT_STATUS } = require('../domain/taxonomies');

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
      enum: REPORT_REASONS,
      required: true,
    },
    details: {
      type: String,
      maxlength: 500,
    },
    status: {
      type: String,
      enum: REPORT_STATUS,
      default: 'pending',
    },
    resolvedAt: {
      type: Date,
    },
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
  },
  {
    timestamps: true,
  },
);

// Admin queries — find all reports against a user, filtered by status
reportSchema.index({ reported: 1, status: 1 });
// Show newest reports first in admin panel
reportSchema.index({ createdAt: -1 });
// Prevent duplicate reports from the same user for the same reported user
reportSchema.index({ reporter: 1, reported: 1 });

module.exports = mongoose.model('Report', reportSchema);
