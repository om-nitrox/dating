// Mongo $project shape for an embedded UserModel — used by match,
// queue, and ideal-match services. Mirrors the fields the Flutter
// frontend UserModel.fromJson reads. Private fields are stripped:
// - refreshToken / refreshToken hash / fcmTokens / googleId / selfiePhoto
// - email & dob: only the owning user receives these via GET /profile;
//   they are never projected to OTHER users' UserModel payloads.
const USER_PROJECTION = {
  name: 1,
  age: 1,
  gender: 1,
  pronouns: 1,
  orientation: 1,
  bio: 1,
  interests: 1,
  photos: 1,
  prompts: 1,
  height: 1,
  ethnicity: 1,
  children: 1,
  familyPlans: 1,
  hometown: 1,
  jobTitle: 1,
  workplace: 1,
  education: 1,
  religion: 1,
  politics: 1,
  languages: 1,
  datingIntentions: 1,
  relationshipType: 1,
  vices: 1,
  location: 1,
  preferences: 1,
  daysWithoutMatch: 1,
  boostLevel: 1,
  isProfileComplete: 1,
  isVerified: 1,
  createdAt: 1,
};

module.exports = { USER_PROJECTION };
