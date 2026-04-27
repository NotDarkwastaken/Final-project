SafeCircle

Meet Up. Stay Safe.

SafeCircle is a Flutter-based mobile application designed to help users stay connected with trusted people in real-time. It allows users to create private circles, share live locations, set meetup points, and send SOS alerts for safety.

Features

Authentication
User sign up & login (Firebase Authentication)
Guest mode supported
Forgot password functionality

Circles (Groups)
Create private circles
Add members using email
Switch between circles
Leave a circle anytime

Live Location Sharing
Real-time GPS tracking using Geolocator
Automatically updates user location
View all circle members on the map

Meetup System
Create meetup points from searched locations
All circle members can see meetup instantly
Members can:
✅ Agree
❌ Disagree
Get directions to meetup using routing API

SOS Alerts
Send emergency alerts to Firestore
Includes user location and circle info

Interactive Map
Built using flutter_map
Satellite & normal map toggle
Zoom, recenter, and navigation controls

Settings & Accessibility
Contact us page
Accessibility options
Clean UI design

UI/UX
Modern glass-style UI
Custom logo and app icon
Bottom tray for circle members

Tech Stack
Flutter (Dart)
Firebase
Authentication
Cloud Firestore
Geolocator & Geocoding
Flutter Map (OpenStreetMap)
HTTP (Routing API - OSRM)

Project Structure
lib/
 ├── main.dart
 ├── firebase_options.dart

assets/
 └── images/
     └── logo1.png

Setup Instructions
Clone project
cd final_yr_project

Install dependencies
flutter pub get

Firebase setup
Create Firebase project
Enable:
Authentication (Email/Password)
Firestore Database
Replace firebase_options.dart with your config

Run app
flutter run

Run on Device

Check devices:

flutter devices

Run on phone:

flutter run -d <device_id>

Firestore Rules (Important)

Make sure your Firestore rules allow circle-based access.

Example:

match /circles/{circleId} {
  allow read, write: if request.auth != null &&
    request.auth.uid in resource.data.members;
}