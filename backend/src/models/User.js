const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      unique: true,
      lowercase: true,
      trim: true,
    },
    googleId: {
      type: String,
      sparse: true,
    },
    name: {
      type: String,
      trim: true,
      maxlength: 50,
    },
    age: {
      type: Number,
      min: 18,
      max: 100,
    },
    gender: {
      type: String,
      enum: ['male', 'female'],
    },
    bio: {
      type: String,
      maxlength: 300,
    },
    interests: [
      {
        type: String,
        trim: true,
      },
    ],
    photos: [
      {
        url: { type: String, required: true },
        publicId: { type: String, required: true },
      },
    ],
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        default: [0, 0],
      },
      city: String,
      state: String,
    },
    preferences: {
      ageMin: { type: Number, default: 18, min: 18 },
      ageMax: { type: Number, default: 50, max: 100 },
      maxDistance: { type: Number, default: 50 }, // km
    },
    daysWithoutMatch: {
      type: Number,
      default: 0,
    },
    boostLevel: {
      type: String,
      enum: ['none', 'bronze', 'silver', 'gold'],
      default: 'none',
    },
    boostExpiry: {
      type: Date,
    },
    fcmToken: {
      type: String,
    },
    refreshToken: {
      type: String,
    },
    isProfileComplete: {
      type: Boolean,
      default: false,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes (email index is auto-created by unique: true on the field)
userSchema.index({ 'location': '2dsphere' });
userSchema.index({ gender: 1, isActive: 1, isProfileComplete: 1 });
userSchema.index({ boostLevel: 1, boostExpiry: 1 }); // For expired boost cleanup cron
userSchema.index({ daysWithoutMatch: -1 }); // For feed sorting

module.exports = mongoose.model('User', userSchema);
