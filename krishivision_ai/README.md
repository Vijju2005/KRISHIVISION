# KrishiVision

Smart Crop Monitoring Using Satellite Images — full project: Flutter app + FastAPI backend.

```
krishivision_ai/
├── lib/            → Flutter app (Riverpod architecture, Google Maps integration)
├── backend/         → FastAPI backend (auth, upload, analysis, history, map boundary)
└── pubspec.yaml
```

## 1. Run the Backend First

To start the FastAPI backend server using the configured virtual environment (which includes all requirements like `reportlab`):

```bash
cd backend
# Windows command to run using the pre-configured virtual environment
.\.venv312\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- **Interactive API Documentation**: http://127.0.0.1:8000/docs
- **Database**: Uses SQLite by default (`krishivision.db`, created automatically) — zero setup needed.
- **Seeded Mock Data**: Pre-seeded with historical reports and farm boundaries centered in Davanagere (`14.4644, 75.9218`).

---

## 2. Run the Flutter App

To launch the app on an Android emulator, iOS simulator, or connected physical device:

```bash
flutter pub get
flutter run
```

### **Dynamic API base URL resolution & detection**
The Flutter application is equipped with an automatic network detection system inside `api_client.dart`:
1. **Emulators**: Automatically detects Android emulators (`10.0.2.2:8000`) and Genymotion emulators (`10.0.3.2:8000`) by probing host loopback ports at startup.
2. **Physical Devices**: Resolves the default base URL from `AppConfig.backendBaseUrl` (pre-configured to the host machine LAN IP `http://192.168.9.107:8000`).
3. **Runtime Configuration**: Users can customize and save a custom host URL inside the **API Server Settings** screen (accessible from the `Profile` tab or the connection recovery screen), saved persistently in `SharedPreferences`.

### **Fail-Safe Startup Recovery Screen**
On startup, the app automatically calls `GET /health`. If the server is offline or unreachable:
* The splash screen displays a friendly connection error screen.
* Shows the current target IP address and connection type (Wi-Fi, Mobile Data, or Offline).
* Provides a **Retry Connection** button and a **Change Server** button to update configurations on the fly without rebuilds.

---

## API Endpoints (Fully Integrated)

| Method | Path | Description | Authentication |
|---|---|---|---|
| GET | `/health` | Core server health check | None |
| POST | `/auth/register` | User sign-up & token generation | None |
| POST | `/auth/login` | User verification & token generation | None |
| GET | `/auth/me` | Retrieve profile payload | JWT Bearer |
| POST | `/analysis/upload` | Upload image for Sentinel analysis | JWT Bearer |
| GET | `/analysis/{job_id}/status` | Analysis execution progress % | JWT Bearer |
| GET | `/analysis/{job_id}/results` | Fetch analyzed NDVI metrics | JWT Bearer |
| GET | `/analysis/history` | Historical monitoring record lists | JWT Bearer |
| GET | `/fields/{job_id}/boundary` | Farm boundary GeoJSON coordinates | JWT Bearer |
| GET | `/weather/current` | Current weather (lat/lng query params) | None |

*Every protected request automatically appends the `Authorization: Bearer <token>` header resolved from secure storage on dispatch.*

---

## Build Steps: Fresh Clone Compilation

To compile a fresh clean build of the release APK:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

**Output Binary Location**: `build/app/outputs/flutter-apk/app-release.apk`
(Successfully copied to the workspace root as `krishivision-release.apk`).
