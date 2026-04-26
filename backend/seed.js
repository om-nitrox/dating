/**
 * Seed script — wipes all collections and inserts 4 fixed users:
 *   Girls: athrava08@gmail.com, 23bds040@iiitdwd.ac.in
 *   Boys:  23bds010@iiitdwd.ac.in, om.nitrox.21@gmail.com
 *
 * Usage:
 *   node seed.js
 */

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '.env') });

const User = require('./src/models/User');
const Like = require('./src/models/Like');
const Match = require('./src/models/Match');
const Message = require('./src/models/Message');
const Block = require('./src/models/Block');
const Report = require('./src/models/Report');
const Otp = require('./src/models/Otp');
const WebhookEvent = require('./src/models/WebhookEvent');

// --------------- fixed profiles ---------------

const users = [
  // ---- Girls ----
  {
    email: 'athrava08@gmail.com',
    name: 'Atharva Kulkarni',
    age: 22,
    gender: 'female',
    bio: 'Coffee-fueled designer chasing sunsets and good playlists. Swipe right if you can quote The Office.',
    interests: ['Design', 'Coffee', 'Music', 'Travel', 'Movies'],
    photos: [
      {
        url: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=80',
        publicId: 'seed_girl_1_a',
      },
      {
        url: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&q=80',
        publicId: 'seed_girl_1_b',
      },
    ],
    location: {
      type: 'Point',
      coordinates: [75.0078, 15.4589],
      city: 'Dharwad',
      state: 'Karnataka',
    },
  },
  {
    email: '23bds040@iiitdwd.ac.in',
    name: 'Ishita Sharma',
    age: 21,
    gender: 'female',
    bio: 'CS student, bookworm, and part-time stargazer. I debug code and overthink texts.',
    interests: ['Coding', 'Books', 'Astronomy', 'Anime', 'Chai'],
    photos: [
      {
        url: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=800&q=80',
        publicId: 'seed_girl_2_a',
      },
      {
        url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800&q=80',
        publicId: 'seed_girl_2_b',
      },
    ],
    location: {
      type: 'Point',
      coordinates: [75.0078, 15.4589],
      city: 'Dharwad',
      state: 'Karnataka',
    },
  },
  // ---- Boys ----
  {
    email: '23bds010@iiitdwd.ac.in',
    name: 'Aditya Rao',
    age: 21,
    gender: 'male',
    bio: 'IIIT Dharwad final-year. Gym rat, coder, and certified meme connoisseur.',
    interests: ['Gym', 'Coding', 'Gaming', 'Football', 'Memes'],
    photos: [
      {
        url: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=80',
        publicId: 'seed_boy_1_a',
      },
      {
        url: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=80',
        publicId: 'seed_boy_1_b',
      },
    ],
    location: {
      type: 'Point',
      coordinates: [75.0078, 15.4589],
      city: 'Dharwad',
      state: 'Karnataka',
    },
  },
  {
    email: 'om.nitrox.21@gmail.com',
    name: 'Om Prakash',
    age: 23,
    gender: 'male',
    bio: 'Full-stack dev by day, guitarist by night. Let’s grab biryani and talk startups.',
    interests: ['Startups', 'Music', 'Travel', 'Food', 'Tech'],
    photos: [
      {
        url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=80',
        publicId: 'seed_boy_2_a',
      },
      {
        url: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=80',
        publicId: 'seed_boy_2_b',
      },
    ],
    location: {
      type: 'Point',
      coordinates: [75.1240, 15.3647],
      city: 'Hubli',
      state: 'Karnataka',
    },
  },

  // ---- Extra Girls (Hubli + Dharwad) ----
  {
    email: 'ananya.desai@example.com',
    name: 'Ananya Desai',
    age: 22,
    gender: 'female',
    bio: 'Marketing intern who plans weekends around dosa runs and Bharatanatyam practice.',
    interests: ['Dance', 'Food', 'Marketing', 'Travel', 'Yoga'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/women/11.jpg', publicId: 'seed_girl_3_a' },
      { url: 'https://randomuser.me/api/portraits/women/12.jpg', publicId: 'seed_girl_3_b' },
    ],
    location: { type: 'Point', coordinates: [75.1240, 15.3647], city: 'Hubli', state: 'Karnataka' },
  },
  {
    email: 'priya.hegde@example.com',
    name: 'Priya Hegde',
    age: 20,
    gender: 'female',
    bio: 'Architecture student with too many sketchbooks. Obsessed with rain and filter coffee.',
    interests: ['Architecture', 'Art', 'Coffee', 'Photography', 'Monsoon'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/women/22.jpg', publicId: 'seed_girl_4_a' },
      { url: 'https://randomuser.me/api/portraits/women/23.jpg', publicId: 'seed_girl_4_b' },
    ],
    location: { type: 'Point', coordinates: [75.0078, 15.4589], city: 'Dharwad', state: 'Karnataka' },
  },
  {
    email: 'meera.nayak@example.com',
    name: 'Meera Nayak',
    age: 24,
    gender: 'female',
    bio: 'Doctor in training. I patch people up and then drag them out for girmit at Glass House.',
    interests: ['Medicine', 'Food', 'Reading', 'Running', 'K-Drama'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/women/33.jpg', publicId: 'seed_girl_5_a' },
      { url: 'https://randomuser.me/api/portraits/women/34.jpg', publicId: 'seed_girl_5_b' },
    ],
    location: { type: 'Point', coordinates: [75.1240, 15.3647], city: 'Hubli', state: 'Karnataka' },
  },
  {
    email: 'kavya.rao@example.com',
    name: 'Kavya Rao',
    age: 19,
    gender: 'female',
    bio: 'BDS student. I dance, I bake, I overanalyse lyrics. Don’t ghost me, my mom won’t like it.',
    interests: ['Dance', 'Baking', 'Music', 'Netflix', 'Dogs'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/women/44.jpg', publicId: 'seed_girl_6_a' },
      { url: 'https://randomuser.me/api/portraits/women/45.jpg', publicId: 'seed_girl_6_b' },
    ],
    location: { type: 'Point', coordinates: [75.0078, 15.4589], city: 'Dharwad', state: 'Karnataka' },
  },
  {
    email: 'sanjana.patil@example.com',
    name: 'Sanjana Patil',
    age: 23,
    gender: 'female',
    bio: 'Fashion blogger who shops more than she budgets. Looking for someone who won’t judge my 47 lipsticks.',
    interests: ['Fashion', 'Blogging', 'Travel', 'Cafes', 'Pets'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/women/55.jpg', publicId: 'seed_girl_7_a' },
      { url: 'https://randomuser.me/api/portraits/women/56.jpg', publicId: 'seed_girl_7_b' },
    ],
    location: { type: 'Point', coordinates: [75.1240, 15.3647], city: 'Hubli', state: 'Karnataka' },
  },
  {
    email: 'aditi.bhat@example.com',
    name: 'Aditi Bhat',
    age: 21,
    gender: 'female',
    bio: 'Literature major, part-time poet, full-time chai addict. Swipe right if Murakami means something to you.',
    interests: ['Poetry', 'Books', 'Chai', 'Indie Music', 'Museums'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/women/66.jpg', publicId: 'seed_girl_8_a' },
      { url: 'https://randomuser.me/api/portraits/women/67.jpg', publicId: 'seed_girl_8_b' },
    ],
    location: { type: 'Point', coordinates: [75.0078, 15.4589], city: 'Dharwad', state: 'Karnataka' },
  },
  {
    email: 'riya.kulkarni@example.com',
    name: 'Riya Kulkarni',
    age: 22,
    gender: 'female',
    bio: 'Software engineer by paycheck. On weekends I’m at Unkal Lake with a camera and snacks.',
    interests: ['Coding', 'Photography', 'Hiking', 'Board Games', 'Coffee'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/women/77.jpg', publicId: 'seed_girl_9_a' },
      { url: 'https://randomuser.me/api/portraits/women/78.jpg', publicId: 'seed_girl_9_b' },
    ],
    location: { type: 'Point', coordinates: [75.1240, 15.3647], city: 'Hubli', state: 'Karnataka' },
  },
  {
    email: 'shruti.joshi@example.com',
    name: 'Shruti Joshi',
    age: 20,
    gender: 'female',
    bio: 'Psych student. I’ll probably over-analyse your texts. Tell me your Myers–Briggs, I dare you.',
    interests: ['Psychology', 'Journaling', 'Plants', 'Lo-fi', 'Tarot'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/women/88.jpg', publicId: 'seed_girl_10_a' },
      { url: 'https://randomuser.me/api/portraits/women/89.jpg', publicId: 'seed_girl_10_b' },
    ],
    location: { type: 'Point', coordinates: [75.0078, 15.4589], city: 'Dharwad', state: 'Karnataka' },
  },

  // ---- Extra Boys (Hubli + Dharwad) ----
  {
    email: 'arjun.deshpande@example.com',
    name: 'Arjun Deshpande',
    age: 23,
    gender: 'male',
    bio: 'Running a tiny startup out of a Hubli co-working. Will build you an app if you build me a sandwich.',
    interests: ['Startups', 'Cricket', 'Podcasts', 'Food', 'Tech'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/men/11.jpg', publicId: 'seed_boy_3_a' },
      { url: 'https://randomuser.me/api/portraits/men/12.jpg', publicId: 'seed_boy_3_b' },
    ],
    location: { type: 'Point', coordinates: [75.1240, 15.3647], city: 'Hubli', state: 'Karnataka' },
  },
  {
    email: 'karthik.bhat@example.com',
    name: 'Karthik Bhat',
    age: 22,
    gender: 'male',
    bio: 'ML researcher at IIIT Dharwad. I write papers nobody reads and playlists everyone loves.',
    interests: ['AI/ML', 'Music', 'Chess', 'Running', 'Filter Coffee'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/men/22.jpg', publicId: 'seed_boy_4_a' },
      { url: 'https://randomuser.me/api/portraits/men/23.jpg', publicId: 'seed_boy_4_b' },
    ],
    location: { type: 'Point', coordinates: [75.0078, 15.4589], city: 'Dharwad', state: 'Karnataka' },
  },
  {
    email: 'rohan.patil@example.com',
    name: 'Rohan Patil',
    age: 24,
    gender: 'male',
    bio: 'Civil engineer, weekend trekker. I’ve seen more sunrises on hills than in my bedroom.',
    interests: ['Trekking', 'Engineering', 'Photography', 'Biking', 'Camping'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/men/33.jpg', publicId: 'seed_boy_5_a' },
      { url: 'https://randomuser.me/api/portraits/men/34.jpg', publicId: 'seed_boy_5_b' },
    ],
    location: { type: 'Point', coordinates: [75.1240, 15.3647], city: 'Hubli', state: 'Karnataka' },
  },
  {
    email: 'vivek.nayak@example.com',
    name: 'Vivek Nayak',
    age: 25,
    gender: 'male',
    bio: 'MBA grad, amateur cricketer, professional over-thinker. Can we talk about your coffee order?',
    interests: ['Cricket', 'Finance', 'Books', 'Cafes', 'Travel'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/men/44.jpg', publicId: 'seed_boy_6_a' },
      { url: 'https://randomuser.me/api/portraits/men/45.jpg', publicId: 'seed_boy_6_b' },
    ],
    location: { type: 'Point', coordinates: [75.0078, 15.4589], city: 'Dharwad', state: 'Karnataka' },
  },
  {
    email: 'siddharth.hegde@example.com',
    name: 'Siddharth Hegde',
    age: 21,
    gender: 'male',
    bio: 'Med student surviving on 3 hours of sleep and KMC’s samosas. Fluent in sarcasm and ECG.',
    interests: ['Medicine', 'Gym', 'Stand-up Comedy', 'F1', 'Dogs'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/men/55.jpg', publicId: 'seed_boy_7_a' },
      { url: 'https://randomuser.me/api/portraits/men/56.jpg', publicId: 'seed_boy_7_b' },
    ],
    location: { type: 'Point', coordinates: [75.1240, 15.3647], city: 'Hubli', state: 'Karnataka' },
  },
  {
    email: 'tanmay.rao@example.com',
    name: 'Tanmay Rao',
    age: 22,
    gender: 'male',
    bio: 'Filmmaker, photographer, occasional writer. I’ll film your best angle — you find mine.',
    interests: ['Filmmaking', 'Photography', 'Writing', 'Indie Music', 'Art'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/men/66.jpg', publicId: 'seed_boy_8_a' },
      { url: 'https://randomuser.me/api/portraits/men/67.jpg', publicId: 'seed_boy_8_b' },
    ],
    location: { type: 'Point', coordinates: [75.0078, 15.4589], city: 'Dharwad', state: 'Karnataka' },
  },
  {
    email: 'harsh.kulkarni@example.com',
    name: 'Harsh Kulkarni',
    age: 23,
    gender: 'male',
    bio: 'Chef at a tiny kitchen in Hubli. If we match, dinner is on me — literally.',
    interests: ['Cooking', 'Food', 'Travel', 'Wine', 'Gym'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/men/77.jpg', publicId: 'seed_boy_9_a' },
      { url: 'https://randomuser.me/api/portraits/men/78.jpg', publicId: 'seed_boy_9_b' },
    ],
    location: { type: 'Point', coordinates: [75.1240, 15.3647], city: 'Hubli', state: 'Karnataka' },
  },
  {
    email: 'nikhil.joshi@example.com',
    name: 'Nikhil Joshi',
    age: 20,
    gender: 'male',
    bio: 'Engineering student with a guitar and zero chill. Looking for someone to split momos with.',
    interests: ['Guitar', 'Music', 'Engineering', 'Gaming', 'Momos'],
    photos: [
      { url: 'https://randomuser.me/api/portraits/men/88.jpg', publicId: 'seed_boy_10_a' },
      { url: 'https://randomuser.me/api/portraits/men/89.jpg', publicId: 'seed_boy_10_b' },
    ],
    location: { type: 'Point', coordinates: [75.0078, 15.4589], city: 'Dharwad', state: 'Karnataka' },
  },
];

// --------------- per-profile enrichment ---------------
// Keyed by email — keeps the main users[] array readable while still giving
// every seed profile rich, Hinge-parity data (height, prompts, intentions…).

const enrichments = {
  'athrava08@gmail.com': {
    height: 165,
    hometown: 'Belgaum',
    jobTitle: 'Product Designer',
    workplace: 'Independent',
    education: 'NID Bengaluru',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada'],
    datingIntentions: 'long_term',
    relationshipType: 'monogamy',
    children: 'dont_have',
    familyPlans: 'open',
    vices: { drinking: 'sometimes', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'My simple pleasures…', answer: 'A latte, a sunset, and a good playlist.' },
      { question: 'The way to win me over is…', answer: 'Find me the best filter coffee in town.' },
      { question: 'Typical Sunday…', answer: 'Brunch, Pinterest board, long walk, pasta by 9.' },
    ],
  },
  '23bds040@iiitdwd.ac.in': {
    height: 160,
    hometown: 'Mangalore',
    jobTitle: 'CS Student',
    workplace: 'IIIT Dharwad',
    education: 'IIIT Dharwad',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Tulu'],
    datingIntentions: 'long_term_open_short',
    relationshipType: 'monogamy',
    children: 'dont_have',
    familyPlans: 'not_sure',
    vices: { drinking: 'rarely', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'A random fact I love is…', answer: 'Octopuses have 3 hearts and 9 brains.' },
      { question: 'I get way too excited about…', answer: 'Clean commit history and starry skies.' },
      { question: 'Unpopular opinion…', answer: 'Chai is better than coffee. Fight me.' },
    ],
  },
  '23bds010@iiitdwd.ac.in': {
    height: 178,
    hometown: 'Belgaum',
    jobTitle: 'Final-year CS Student',
    workplace: 'IIIT Dharwad',
    education: 'IIIT Dharwad',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada'],
    datingIntentions: 'long_term',
    relationshipType: 'monogamy',
    children: 'dont_have',
    familyPlans: 'open',
    vices: { drinking: 'sometimes', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'The way to win me over is…', answer: 'Spot me at the gym without me asking.' },
      { question: 'I go crazy for…', answer: 'Leg day, chicken biryani, and leetcode streaks.' },
      { question: "I'll fall for you if…", answer: 'You laugh at your own jokes before I do.' },
    ],
  },
  'om.nitrox.21@gmail.com': {
    height: 182,
    hometown: 'Bangalore',
    jobTitle: 'Full-stack Developer',
    workplace: 'Remote startup',
    education: 'BMS College of Engineering',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada'],
    datingIntentions: 'life_partner',
    relationshipType: 'monogamy',
    children: 'dont_have',
    familyPlans: 'want',
    vices: { drinking: 'sometimes', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'Dating me is like…', answer: 'Pair programming — we debug life together.' },
      { question: 'My simple pleasures…', answer: 'Late-night code sessions with lo-fi beats.' },
      { question: 'I quote too much from…', answer: 'Silicon Valley and F.R.I.E.N.D.S.' },
    ],
  },
  'ananya.desai@example.com': {
    height: 162,
    hometown: 'Gadag',
    jobTitle: 'Marketing Intern',
    education: 'KLE Institute',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada'],
    datingIntentions: 'long_term_open_short',
    children: 'dont_have',
    familyPlans: 'open',
    vices: { drinking: 'rarely', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'My happy place…', answer: 'The stage, mid-thillana.' },
      { question: 'All I ask is that you…', answer: 'Let me pick the playlist on road trips.' },
      { question: 'Best travel story…', answer: 'Got lost in Hampi, found the best masala dosa.' },
    ],
  },
  'priya.hegde@example.com': {
    height: 159,
    hometown: 'Sirsi',
    jobTitle: 'Architecture Student',
    education: 'SDM College Dharwad',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Konkani'],
    datingIntentions: 'figuring_out',
    children: 'dont_have',
    familyPlans: 'not_sure',
    vices: { drinking: 'no', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'I get way too excited about…', answer: 'Old buildings and new stationery.' },
      { question: 'My happy place…', answer: 'Dharwad in July, cup of chai, balcony view.' },
      { question: "Don't hate me if I…", answer: 'Sketch you when you’re not looking.' },
    ],
  },
  'meera.nayak@example.com': {
    height: 168,
    hometown: 'Udupi',
    jobTitle: 'Medical Intern',
    workplace: 'KMC Hubli',
    education: 'KMC Hubli',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Tulu'],
    datingIntentions: 'long_term',
    children: 'dont_have',
    familyPlans: 'want',
    vices: { drinking: 'rarely', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'A shower thought I recently had…', answer: 'Every ICU has a coffee machine. Coincidence?' },
      { question: 'My greatest strength…', answer: 'I can stay calm when everyone else is panicking.' },
      { question: 'The best way to ask me out is…', answer: 'Between my ward rounds — I’m quicker to say yes.' },
    ],
  },
  'kavya.rao@example.com': {
    height: 160,
    hometown: 'Mysore',
    jobTitle: 'BDS Student',
    education: 'SDM Dental College',
    religion: 'Hindu',
    languages: ['English', 'Kannada', 'Hindi'],
    datingIntentions: 'long_term_open_short',
    children: 'dont_have',
    familyPlans: 'open',
    vices: { drinking: 'no', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'I get way too excited about…', answer: 'Fresh-baked cookies and unreleased Taylor Swift snippets.' },
      { question: 'Unusual skills…', answer: 'I can tell a genuine smile from a nervous one.' },
      { question: 'Dating me is like…', answer: 'Adopting a very well-trained, food-motivated puppy.' },
    ],
  },
  'sanjana.patil@example.com': {
    height: 164,
    hometown: 'Hubli',
    jobTitle: 'Fashion Blogger',
    education: 'NIFT Bengaluru',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Marathi'],
    datingIntentions: 'long_term',
    children: 'dont_have',
    familyPlans: 'open',
    vices: { drinking: 'sometimes', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'Change my mind about…', answer: 'Fast fashion being “convenient”.' },
      { question: 'My love language is…', answer: 'Gift-giving (and unsolicited outfit advice).' },
      { question: 'Typical Sunday…', answer: 'Thrift hunt, cafe shoot, home by dinner.' },
    ],
  },
  'aditi.bhat@example.com': {
    height: 161,
    hometown: 'Dharwad',
    jobTitle: 'Literature Student',
    education: 'Karnatak University',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Marathi'],
    datingIntentions: 'life_partner',
    children: 'dont_have',
    familyPlans: 'want',
    vices: { drinking: 'no', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'I quote too much from…', answer: 'Murakami and Mary Oliver.' },
      { question: 'My cry-in-the-car song is…', answer: 'Ribs — Lorde.' },
      { question: 'Green flags I look for…', answer: 'You listen twice as much as you speak.' },
    ],
  },
  'riya.kulkarni@example.com': {
    height: 166,
    hometown: 'Hubli',
    jobTitle: 'Software Engineer',
    workplace: 'A local product startup',
    education: 'BVB College Hubli',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Marathi'],
    datingIntentions: 'long_term_open_short',
    children: 'dont_have',
    familyPlans: 'open',
    vices: { drinking: 'sometimes', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'My simple pleasures…', answer: 'Unkal Lake at 7am with an Americano.' },
      { question: "I'm a great +1 because…", answer: 'I can hold a conversation with anyone from anywhere.' },
      { question: 'My biggest date fail…', answer: 'Debugged his laptop mid-dinner. He still said yes to date 2.' },
    ],
  },
  'shruti.joshi@example.com': {
    height: 158,
    hometown: 'Pune',
    jobTitle: 'Psychology Student',
    education: 'Karnatak University',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Marathi'],
    datingIntentions: 'figuring_out',
    children: 'dont_have',
    familyPlans: 'not_sure',
    vices: { drinking: 'rarely', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'My therapist would say…', answer: 'I’m “emotionally available-ish”.' },
      { question: 'I get way too excited about…', answer: 'Type theories and tarot pulls.' },
      { question: 'Dating me is like…', answer: 'Therapy, but with better chai.' },
    ],
  },
  'arjun.deshpande@example.com': {
    height: 180,
    hometown: 'Hubli',
    jobTitle: 'Founder',
    workplace: 'Stealth startup',
    education: 'BVB College Hubli',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada'],
    datingIntentions: 'long_term',
    children: 'dont_have',
    familyPlans: 'want',
    vices: { drinking: 'sometimes', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'Dating me is like…', answer: 'A seed round — high risk, high reward.' },
      { question: 'My greatest strength…', answer: 'I can sell ice to penguins and Figma to my grandmother.' },
      { question: 'The way to win me over is…', answer: 'Pitch me your worst idea. I’ll listen.' },
    ],
  },
  'karthik.bhat@example.com': {
    height: 175,
    hometown: 'Mangalore',
    jobTitle: 'ML Researcher',
    workplace: 'IIIT Dharwad',
    education: 'IIIT Dharwad',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Tulu'],
    datingIntentions: 'long_term',
    children: 'dont_have',
    familyPlans: 'open',
    vices: { drinking: 'rarely', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'My simple pleasures…', answer: 'A working experiment and good filter coffee.' },
      { question: 'I quote too much from…', answer: 'The Martian — the book, not the movie.' },
      { question: 'Unpopular opinion…', answer: 'PyTorch > TensorFlow, and I will die on this hill.' },
    ],
  },
  'rohan.patil@example.com': {
    height: 183,
    hometown: 'Belgaum',
    jobTitle: 'Civil Engineer',
    workplace: 'L&T',
    education: 'BVB College Hubli',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Marathi'],
    datingIntentions: 'long_term',
    children: 'dont_have',
    familyPlans: 'want',
    vices: { drinking: 'sometimes', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'Best travel story…', answer: 'Kudremukh summit at 5am — worth every blister.' },
      { question: 'My happy place…', answer: 'Anywhere above 2000m.' },
      { question: 'The best way to ask me out is…', answer: 'Suggest a weekend trek — you’re in.' },
    ],
  },
  'vivek.nayak@example.com': {
    height: 177,
    hometown: 'Udupi',
    jobTitle: 'Financial Analyst',
    workplace: 'HDFC',
    education: 'IIM Shillong',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Tulu'],
    datingIntentions: 'life_partner',
    children: 'dont_have',
    familyPlans: 'want',
    vices: { drinking: 'sometimes', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: "I'm looking for…", answer: 'Someone who laughs at my excel-pun tier jokes.' },
      { question: 'My love language is…', answer: 'Quality time and well-timed memes.' },
      { question: 'Change my mind about…', answer: 'Vintage cricket > IPL.' },
    ],
  },
  'siddharth.hegde@example.com': {
    height: 181,
    hometown: 'Sirsi',
    jobTitle: 'Medical Student',
    workplace: 'KMC Hubli',
    education: 'KMC Hubli',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada'],
    datingIntentions: 'long_term_open_short',
    children: 'dont_have',
    familyPlans: 'open',
    vices: { drinking: 'rarely', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'Dating me is like…', answer: 'Having a live WebMD — except accurate.' },
      { question: 'My cry-in-the-car song is…', answer: '"Vienna" — Billy Joel.' },
      { question: 'A random fact I love is…', answer: 'Your stomach lining regenerates every 3 days.' },
    ],
  },
  'tanmay.rao@example.com': {
    height: 174,
    hometown: 'Dharwad',
    jobTitle: 'Filmmaker',
    education: 'SRFTI Kolkata',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Bengali'],
    datingIntentions: 'long_term_open_short',
    children: 'dont_have',
    familyPlans: 'open',
    vices: { drinking: 'sometimes', smoking: 'sometimes', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'All I ask is that you…', answer: 'Don’t make me choose between Nolan and Tarantino.' },
      { question: 'My happy place…', answer: 'The editing room at 3am.' },
      { question: 'I quote too much from…', answer: 'Before Sunrise. All three.' },
    ],
  },
  'harsh.kulkarni@example.com': {
    height: 178,
    hometown: 'Kolhapur',
    jobTitle: 'Chef',
    workplace: 'A tiny kitchen in Hubli',
    education: 'IHM Mumbai',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Marathi'],
    datingIntentions: 'long_term',
    children: 'dont_have',
    familyPlans: 'want',
    vices: { drinking: 'sometimes', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'The way to win me over is…', answer: 'Tell me about the best meal you ever ate.' },
      { question: 'Typical Sunday…', answer: 'Farmer’s market, slow braise, quiet evening.' },
      { question: "I'll fall for you if…", answer: 'You salt your pasta water correctly.' },
    ],
  },
  'nikhil.joshi@example.com': {
    height: 176,
    hometown: 'Belgaum',
    jobTitle: 'Engineering Student',
    education: 'KLE Technological University',
    religion: 'Hindu',
    languages: ['English', 'Hindi', 'Kannada', 'Marathi'],
    datingIntentions: 'figuring_out',
    children: 'dont_have',
    familyPlans: 'not_sure',
    vices: { drinking: 'rarely', smoking: 'no', marijuana: 'no', drugs: 'no' },
    prompts: [
      { question: 'My love language is…', answer: 'A new song I made, just for you.' },
      { question: "I'll fall for you if…", answer: 'You can harmonize to "Khoya Khoya Chand".' },
      { question: 'My happy place…', answer: 'A quiet jam room with mismatched furniture.' },
    ],
  },
};

function dobFromAge(age) {
  // Deterministic DOB so re-seeding does not change dates.
  // Uses Jan 1 of (currentYear - age).
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear() - age, 0, 1));
}

function buildUser(profile) {
  const extra = enrichments[profile.email] || {};
  return {
    ...profile,
    ...extra,
    // Derive dob from age if not explicitly provided
    dob: extra.dob || dobFromAge(profile.age),
    preferences: {
      ageMin: 18,
      ageMax: 30,
      maxDistance: 100,
      genderPreference: profile.gender === 'female' ? 'men' : 'women',
    },
    daysWithoutMatch: 0,
    boostLevel: 'none',
    isProfileComplete: true,
    isActive: true,
    isVerified: true,
  };
}

// --------------- main ---------------

async function seed() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log('Connected to MongoDB');

  // Wipe every collection used by the app
  const wipes = await Promise.all([
    User.deleteMany({}),
    Like.deleteMany({}),
    Match.deleteMany({}),
    Message.deleteMany({}),
    Block.deleteMany({}),
    Report.deleteMany({}),
    Otp.deleteMany({}),
    WebhookEvent.deleteMany({}),
  ]);
  console.log('Cleared collections:', {
    users: wipes[0].deletedCount,
    likes: wipes[1].deletedCount,
    matches: wipes[2].deletedCount,
    messages: wipes[3].deletedCount,
    blocks: wipes[4].deletedCount,
    reports: wipes[5].deletedCount,
    otps: wipes[6].deletedCount,
    webhookEvents: wipes[7].deletedCount,
  });

  const docs = users.map(buildUser);
  const inserted = await User.insertMany(docs);
  console.log(`Inserted ${inserted.length} users:`);
  inserted.forEach((u) => console.log(`  - ${u.gender.padEnd(6)} ${u.email}  (${u.name})`));

  await mongoose.disconnect();
  console.log('Done.');
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
