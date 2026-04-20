# GoVista 🏔️

An AI-powered travel planning app for Himalayan destinations — built with Flutter and Firebase.


## Features

- **800+ Destinations** — Covers Himachal Pradesh, Uttarakhand, Jammu & Kashmir, and Ladakh
- **AI Travel Chatbot** — Powered by Groq Cloud API with voice input (STT) and text-to-speech (TTS)
- **Firebase Auth** — Google Sign-In and Phone OTP authentication
- **Offline Support** — Sync offline requests via sqflite and connectivity_plus
- **Rich Destination Data** — Firestore-backed with 800+ entries across all Himalayan regions

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State Management | Riverpod |
| Backend | Firebase (Auth, Firestore, Storage) |
| AI Chatbot | Groq Cloud API |
| Voice | `speech_to_text` + `flutter_tts` |
| Offline Sync | sqflite + connectivity_plus |

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0`
- Firebase project with Auth and Firestore enabled
- Groq API key

### Setup

1. Clone the repo

```bash
git clone https://github.com/your-username/govista.git
cd govista
```

2. Install dependencies

```bash
flutter pub get
```

3. Add your `google-services.json` (Android) inside `android/app/`

4. Create a `.env` file or add your keys to the config:

```
GROQ_API_KEY=your_key_here
```

5. Run the app

```bash
flutter run

## Contributing

Pull requests are welcome. For major changes, please open an issue first.

---

## License

[MIT](LICENSE)
