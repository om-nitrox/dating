"""
One-off seed: add more active+profile-complete MALE users so the Ideal Match
candidate pool exceeds the >=10-swipe unlock gate (the seed DB only had 10 men,
so a girl who swiped enough to unlock had no one left to match).

Modeled exactly on an existing valid male doc (see app/adapter.py USER_FIELDS).
Idempotent: emails are unique-indexed and use a 'seedmale+N' pattern, so re-runs
skip already-inserted profiles.
"""
from __future__ import annotations

import datetime
import os

from pymongo import MongoClient

MONGO_URI = os.getenv(
    "MONGO_URI",
    "mongodb+srv://prathom577_db_user:hh1l6TiWIQMPK2Vj@date.yvkitne.mongodb.net/test",
)
db = MongoClient(MONGO_URI, serverSelectionTimeoutMS=8000)["test"]

NOW = datetime.datetime(2026, 5, 30, 12, 0, 0)

# 18 distinct men, varied across personality / interests / intent / religion so
# the embedder produces a real spread of similarity scores.
MEN = [
    ("Rohan Shetty", 24, "Mangaluru", "Karnataka", (74.8560, 12.9141),
     "Coastal kid turned product designer. Sketch by day, surf by weekend.",
     ["Design", "Surfing", "Coffee", "Travel", "Photography"],
     ["Product Designer", "Freshworks", "NITK Surathkal"], "Hindu",
     ["English", "Kannada", "Tulu"], "long_term", 180,
     [("My simple pleasures", "Filter coffee and a good sunset."),
      ("Together we could", "Roadtrip the entire Konkan coast."),
      ("I geek out on", "Typography and clean UI.")]),
    ("Arjun Menon", 26, "Bengaluru", "Karnataka", (77.5946, 12.9716),
     "Backend engineer who runs marathons to justify the biryani.",
     ["Running", "Coding", "Cooking", "Football", "Podcasts"],
     ["Senior SWE", "Razorpay", "PES University"], "Hindu",
     ["English", "Malayalam", "Hindi"], "life_partner", 177,
     [("The way to win me over", "Out-run me, then out-eat me."),
      ("I'm weirdly attracted to", "People who love their work."),
      ("Sunday mornings", "10k run then dosa, non-negotiable.")]),
    ("Kabir Sharma", 23, "Pune", "Maharashtra", (73.8567, 18.5204),
     "Music producer + part-time philosopher. I will make you a playlist.",
     ["Music", "Guitar", "Reading", "Travel", "Concerts"],
     ["Music Producer", "Independent", "Symbiosis"], "Hindu",
     ["English", "Hindi", "Marathi"], "long_term_open_short", 175,
     [("I go crazy for", "Live gigs and vinyl crackle."),
      ("My love language", "Curated playlists, obviously."),
      ("Dream date", "Rooftop, two guitars, no phones.")]),
    ("Ishaan Verma", 27, "Hyderabad", "Telangana", (78.4867, 17.3850),
     "Startup founder. High energy, low ego. Building, always building.",
     ["Startups", "Tech", "Chess", "Fitness", "Investing"],
     ["Founder", "Stealth Startup", "BITS Pilani"], "Hindu",
     ["English", "Hindi", "Telugu"], "long_term", 182,
     [("I'm convinced that", "Ambition is the best aphrodisiac."),
      ("Weekends", "Whiteboard sessions and long walks."),
      ("Green flag", "You ask why before how.")]),
    ("Aryan Gupta", 25, "Delhi", "Delhi", (77.2090, 28.6139),
     "Photojournalist chasing light and stories. Ask me about my last trip.",
     ["Photography", "Travel", "Hiking", "Writing", "Films"],
     ["Photojournalist", "The Hindu", "Delhi University"], "Hindu",
     ["English", "Hindi"], "figuring_out", 179,
     [("My camera roll is", "90% strangers, 10% street dogs."),
      ("Take me to", "A place with no signal and great light."),
      ("I'll fall for you if", "You can read a map.")]),
    ("Vivaan Reddy", 24, "Bengaluru", "Karnataka", (77.5946, 12.9716),
     "Data scientist, amateur barista, terrible-at-tennis enthusiast.",
     ["Tennis", "Coffee", "Data", "Anime", "Cooking"],
     ["Data Scientist", "Swiggy", "IIIT Hyderabad"], "Hindu",
     ["English", "Telugu", "Hindi"], "long_term", 176,
     [("I make a mean", "Pour-over and a worse backhand."),
      ("Nerd-out topic", "Recommender systems."),
      ("Ideal Sunday", "Brunch, a long match, a longer nap.")]),
    ("Aman Khan", 28, "Mumbai", "Maharashtra", (72.8777, 19.0760),
     "Architect who sketches buildings on napkins. Foodie first, always.",
     ["Architecture", "Food", "Sketching", "Cricket", "Travel"],
     ["Architect", "Studio Lotus", "Sir JJ College"], "Muslim",
     ["English", "Hindi", "Urdu"], "life_partner", 181,
     [("Best meal of my life", "A bombay sandwich at 2am."),
      ("I notice", "Good light and bad kerning."),
      ("Win me with", "A new place to eat.")]),
    ("Dev Patel", 26, "Ahmedabad", "Gujarat", (72.5714, 23.0225),
     "Finance guy with a dangerous love for street food and standup.",
     ["Comedy", "Finance", "Cricket", "Food", "Travel"],
     ["Investment Analyst", "Motilal Oswal", "IIM Ahmedabad"], "Hindu",
     ["English", "Hindi", "Gujarati"], "long_term", 174,
     [("I laugh hardest at", "My own jokes, sadly."),
      ("Spreadsheet or", "spontaneity? Both, in that order."),
      ("Date idea", "Open mic, then khaman.")]),
    ("Karan Nair", 25, "Kochi", "Kerala", (76.2673, 9.9312),
     "Marine engineer, half the year at sea, fully a dog person.",
     ["Sailing", "Dogs", "Fitness", "Travel", "Diving"],
     ["Marine Engineer", "Maersk", "CUSAT"], "Christian",
     ["English", "Malayalam", "Hindi"], "long_term_open_short", 183,
     [("Months at sea taught me", "To value the people on land."),
      ("My dog thinks", "I'm the best, I won't correct him."),
      ("Take me", "Anywhere with water.")]),
    ("Siddharth Iyer", 27, "Chennai", "Tamil Nadu", (80.2707, 13.0827),
     "Doctor by training, drummer by heart. Calm under pressure.",
     ["Music", "Medicine", "Drums", "Running", "Books"],
     ["Resident Doctor", "Apollo", "CMC Vellore"], "Hindu",
     ["English", "Tamil", "Hindi"], "life_partner", 178,
     [("After a 12-hour shift", "I drum until midnight."),
      ("I'm steady when", "Everyone else is panicking."),
      ("Green flag", "Kindness to waiters.")]),
    ("Nikhil Joshi", 23, "Dharwad", "Karnataka", (75.0078, 15.4589),
     "CS undergrad, chess club captain, biryani optimist.",
     ["Chess", "Coding", "Gaming", "Football", "Memes"],
     ["CS Student", "IIIT Dharwad", "IIIT Dharwad"], "Hindu",
     ["English", "Hindi", "Kannada"], "long_term", 175,
     [("I'll beat you at", "Chess, then teach you."),
      ("Comfort food", "Hostel-mess biryani, unironically."),
      ("I go crazy for", "A clean checkmate.")]),
    ("Rishabh Mehta", 29, "Jaipur", "Rajasthan", (75.7873, 26.9124),
     "Travel writer collecting cities and bad puns. Tea over coffee, fight me.",
     ["Writing", "Travel", "History", "Tea", "Trekking"],
     ["Travel Writer", "Lonely Planet", "MNIT Jaipur"], "Hindu",
     ["English", "Hindi", "Rajasthani"], "long_term_open_short", 177,
     [("I've slept in", "More trains than I can count."),
      ("Hot take", "Tea > coffee, always."),
      ("Let's", "Get lost in an old city together.")]),
    ("Ayaan Ali", 25, "Lucknow", "Uttar Pradesh", (80.9462, 26.8467),
     "Chef de partie with a soft spot for poetry and old films.",
     ["Cooking", "Poetry", "Films", "Music", "Food"],
     ["Chef", "Taj Hotels", "IHM Lucknow"], "Muslim",
     ["English", "Hindi", "Urdu"], "life_partner", 176,
     [("I express love through", "Food, mostly biryani."),
      ("Quote me a", "Couplet and I'm yours."),
      ("Sunday", "Old film, slow-cooked lunch.")]),
    ("Aditya Pillai", 26, "Bengaluru", "Karnataka", (77.5946, 12.9716),
     "Cloud engineer, weekend cyclist, plant dad to eleven succulents.",
     ["Cycling", "Plants", "Tech", "Coffee", "Hiking"],
     ["Cloud Engineer", "Google", "RVCE"], "Hindu",
     ["English", "Malayalam", "Kannada"], "long_term", 180,
     [("My apartment is", "A jungle, send help (don't)."),
      ("Weekend ride", "100km then a giant breakfast."),
      ("I'm low-key proud of", "Keeping plants alive.")]),
    ("Yash Agarwal", 24, "Kolkata", "West Bengal", (88.3639, 22.5726),
     "Stand-up comic and economics nerd. I will analyze the date later.",
     ["Comedy", "Economics", "Football", "Reading", "Food"],
     ["Comedian", "Independent", "Presidency University"], "Hindu",
     ["English", "Hindi", "Bengali"], "short_term_open_long", 173,
     [("I overthink", "Everything except my jokes."),
      ("Best first date", "Phuchka crawl across the city."),
      ("Win me with", "A genuine laugh.")]),
    ("Tanish Rao", 27, "Goa", "Goa", (73.9135, 15.2993),
     "Hostel owner living the slow life. Sunsets, surfboards, no rush.",
     ["Surfing", "Travel", "Music", "Cooking", "Diving"],
     ["Hostel Owner", "Self-employed", "Goa University"], "Hindu",
     ["English", "Konkani", "Hindi"], "short_term_open_long", 179,
     [("I traded a desk for", "A beach and zero regrets."),
      ("My ideal morning", "Surf, then no plans at all."),
      ("Come over for", "Sunset and homemade fish curry.")]),
    ("Harsh Vardhan", 28, "Indore", "Madhya Pradesh", (75.8577, 22.7196),
     "Mechanical engineer turned EV startup guy. Big on long drives.",
     ["Cars", "Startups", "Fitness", "Travel", "Tech"],
     ["EV Engineer", "Ather Energy", "IIT Indore"], "Hindu",
     ["English", "Hindi"], "long_term", 182,
     [("I could talk for hours about", "Torque curves, sorry."),
      ("Perfect date", "A long drive with great music."),
      ("Green flag", "You're up for a 2am drive.")]),
    ("Zayan Sheikh", 25, "Bhopal", "Madhya Pradesh", (77.4126, 23.2599),
     "Wildlife photographer. Patient, curious, terrible at sitting still.",
     ["Photography", "Wildlife", "Hiking", "Travel", "Films"],
     ["Wildlife Photographer", "Freelance", "MANIT Bhopal"], "Muslim",
     ["English", "Hindi", "Urdu"], "figuring_out", 178,
     [("I once waited 6 hours for", "One tiger photo. Worth it."),
      ("Take me to", "A forest at first light."),
      ("I'll fall for you if", "You can be quiet with me.")]),
]


def make_doc(idx: int, m) -> dict:
    (name, age, hometown, state, coords, bio, interests, work, religion,
     langs, intent, height, prompts) = m
    job, workplace, education = work
    lon, lat = coords
    return {
        "email": f"seedmale{idx}@reverse-match.seed",
        "name": name,
        "age": age,
        "dob": datetime.datetime(2026 - age, 6, 1),
        "gender": "male",
        "pronouns": [],
        "orientation": [],
        "bio": bio,
        "interests": interests,
        "photos": [
            {"url": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=80",
             "publicId": f"seedmale_{idx}_a"},
            {"url": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=80",
             "publicId": f"seedmale_{idx}_b"},
        ],
        "prompts": [{"question": q, "answer": a} for q, a in prompts],
        "height": height,
        "ethnicity": [],
        "children": "dont_have",
        "familyPlans": "open",
        "hometown": hometown,
        "jobTitle": job,
        "workplace": workplace,
        "education": education,
        "religion": religion,
        "languages": langs,
        "datingIntentions": intent,
        "relationshipType": "monogamy",
        "vices": {"drinking": "sometimes", "smoking": "no", "marijuana": "no", "drugs": "no"},
        "location": {"type": "Point", "coordinates": [lon, lat], "city": hometown, "state": state},
        "preferences": {"ageMin": 18, "ageMax": 35, "maxDistance": 200, "genderPreference": "women"},
        "selfiePhoto": None,
        "isVerified": True,
        "selfieReviewStatus": "none",
        "daysWithoutMatch": 0,
        "boostLevel": "none",
        "banned": False,
        "role": "user",
        "isProfileComplete": True,
        "isActive": True,
        "fcmTokens": [],
        "refreshSessions": [],
        "__v": 0,
        "createdAt": NOW,
        "updatedAt": NOW,
    }


inserted = 0
skipped = 0
for i, m in enumerate(MEN, start=1):
    email = f"seedmale{i}@reverse-match.seed"
    if db["users"].find_one({"email": email}):
        skipped += 1
        continue
    db["users"].insert_one(make_doc(i, m))
    inserted += 1

total_males = db["users"].count_documents(
    {"isActive": True, "isProfileComplete": True, "gender": "male"})
print(f"inserted={inserted} skipped(existing)={skipped} | total active+complete males now = {total_males}")
