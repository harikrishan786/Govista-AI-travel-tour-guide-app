# Govista-AI-travel-tour-guide-app
An AI-powered travel planning app for Himalayan destinations — built with Flutter and Firebase.
An AI-powered travel planning app for Himalayan destinations — built with Flutter and Firebase.

Features

800+ Destinations — Covers Himachal Pradesh, Uttarakhand, Jammu & Kashmir, and Ladakh
AI Travel Chatbot — Powered by Groq Cloud API with voice input (STT) and text-to-speech (TTS)
Firebase Auth — Google Sign-In and Phone OTP authentication
Offline Support — Sync offline requests via sqflite and connectivity_plus
Rich Destination Data — Firestore-backed with 800+ entries across all Himalayan regions


Tech Stack
LayerTechnologyFrameworkFlutter (Dart)State ManagementRiverpodBackendFirebase (Auth, Firestore, Storage)AI ChatbotGroq Cloud APIVoicespeech_to_text + flutter_ttsOffline Syncsqflite + connectivity_plus

Getting Started
Prerequisites

Flutter SDK >=3.0.0
Firebase project with Auth and Firestore enabled
Groq API key

Setup

Clone the repo

bashgit clone https://github.com/your-username/govista.git
cd govista

Install dependencies

bashflutter pub get

Add your google-services.json (Android) inside android/app/
Create a .env file or add your keys to the config:

GROQ_API_KEY=your_key_here

Run the app

bashflutter run
Contributing
Pull requests are welcome. For major changes, please open an issue first.

License
MIT
