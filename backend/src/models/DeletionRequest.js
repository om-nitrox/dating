// Phase 1.17: DeletionRequest — GDPR audit row preserved after user deletion.
/**
 * When a user invokes `DELETE /account`, we cascade-delete every user-owned
 * row. The DeletionRequest is the only thing that SURVIVES the user — it's
 * the auditable record that the deletion happened, who requested it, and
 * what was destroyed.
 *
 * Why not TTL this collection:
 *   GDPR-style "right to be forgotten" only mandates removal of personal
 *   data. The audit row contains a userId (now dangling), an email (kept
 *   intentionally for fraud investigation / undo workflows), and aggregate
 *   counts — no personally identifying content. It is kept indefinitely
 *   so future incident response can reconstruct what was deleted.
 *
 * Fields:
 *   userId          The deleted user's _id (now dangling — no longer a ref).
 *   userEmail       The deleted user's email (preserved for audit).
 *   requestedAt     When the DELETE call hit the server.
 *   requesterIp     Originating client IP (best-effort; nullable when behind a
 *                   stripped proxy header).
 *   cascadeSummary  Counts per child collection — see account.service.
 */

const mongoose = require('mongoose');

const cascadeSummarySchema = new mongoose.Schema(
  {
    matches: { type: Number, default: 0 },
    messages: { type: Number, default: 0 },
    likesSent: { type: Number, default: 0 },
    likesReceived: { type: Number, default: 0 },
    blocks: { type: Number, default: 0 },
    reports: { type: Number, default: 0 },
    photos: { type: Number, default: 0 },
  },
  { _id: false },
);

const deletionRequestSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    userEmail: {
      type: String,
      default: null,
    },
    requestedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    requesterIp: {
      type: String,
      default: null,
    },
    cascadeSummary: {
      type: cascadeSummarySchema,
      default: () => ({}),
    },
  },
  {
    timestamps: true,
  },
);

module.exports = mongoose.model('DeletionRequest', deletionRequestSchema);
