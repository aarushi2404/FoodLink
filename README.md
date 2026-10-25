# FoodLink

Rescue surplus food near you. A Flutter + Firebase app that connects vendors
(canteens, restaurants, bakeries) holding surplus food with people nearby.

## Setup

API keys are **not** committed to this repository. After cloning, add your own:

1. **Firebase**: run `flutterfire configure` with your Firebase project.
   Or copy the templates and fill in your keys:
   - `lib/firebase_options.example.dart` → `lib/firebase_options.dart`
   - `android/app/google-services.example.json` → `android/app/google-services.json`
2. **Google Maps** (Android): add this line to `android/local.properties`
   (Android Studio / Flutter creates the file on the first build):

   ```
   MAPS_API_KEY=your_google_maps_api_key
   ```

   You can also set a `MAPS_API_KEY` environment variable instead.
3. Run `flutter pub get`, then `flutter run`.
