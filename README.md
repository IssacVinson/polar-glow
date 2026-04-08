# Polar Glow Detailing

A modern **Flutter + Firebase** mobile application for **Polar Glow Car Detailing** in the Anchorage, Alaska area.

Customers can easily browse services and book appointments. Detailers manage their schedule and clock in/out, while admins have full oversight of users, bookings, and business operations.

## ✨ Features

### 👤 Customer
- Browse professional car detailing services
- Book appointments (choose specific detailer or next available)
- Smart address autocomplete with Google Places
- Secure credit card payments via Stripe
- View past and upcoming bookings

### 👷 Employee / Detailer
- Clock in / Clock out with timestamps
- Set availability (bulk scheduling + daily overrides)
- Service region selection (Anchorage, Wasilla, Eagle River, Base, etc.)
- View assigned jobs and manage bookings

### ⚡ Admin
- User role management (Customer → Employee → Admin promotion)
- Track employee activity, hours, and schedules
- Full service management (CRUD operations)
- Business oversight and reporting tools

### 🔧 Technical Highlights
- Email/password authentication (Firebase Auth)
- Real-time data with Firestore
- Image upload support
- Premium UI with smooth animations and Google Fonts
- Secure backend operations via Cloud Functions

## 🛠 Tech Stack

- **Framework**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore, Storage, Cloud Functions)
- **State Management**: Provider
- **Payments**: flutter_stripe
- **Address Autocomplete**: google_places_flutter
- **UI & Utils**: table_calendar, flutter_animate, google_fonts, intl, image_picker
- **Security**: flutter_dotenv (for Stripe keys)

## 📁 Project Structure (Key Folders)
polar-glow/
├── lib/
│   ├── core/              # Core utilities, services & helpers
│   ├── providers/         # State management providers
│   ├── screens/           # All UI screens & pages
│   ├── auth_wrapper.dart
│   ├── main.dart
│   └── firebase_options.dart
├── functions/             # Firebase Cloud Functions (Node.js)
├── assets/images/         # App logos and graphics
├── android/, ios/, web/   # Platform folders
└── .env         # Containes keys

## 🚀 Setup & Run

1. **Clone the repo**
   ```bash
   git clone https://github.com/IssacVinson/polar-glow.git
   cd polar-glow
   flutter pub get
   flutterfire configure
   flutter run