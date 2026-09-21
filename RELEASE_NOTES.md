# KrishiVision AI - Release Notes

**Version**: `1.0.0+1 (Production)`  
**Release Date**: July 31, 2026  
**Target Platform**: Android (APK) & Backend FastAPI Web Service  
**Status**: `Production-Ready`

---

## 1. Release Deliverables

1. **Android Application Package**:
   * **Filename**: `app-release.apk`
   * **Output Path**: [app-release.apk](file:///c:/Users/keert/Downloads/Krishi222-fixed/krishivision_ai/build/app/outputs/flutter-apk/app-release.apk)
   * **Size**: 54,586,822 bytes (~52.1 MB)
   * **Signature Status**: Sign-ready for release deployment

2. **Backend API Service**:
   * Production-grade Docker Compose setup including automatic database seeding, uvicorn runtime, and OpenCV analytics tools.

---

## 2. Key Features Included

* **Remote Sensing / Crop Health Simulation**: Matrix-level greenness extraction to produce colorized NDVI mappings dynamically from RGB files.
* **Role-Based Access Control (RBAC)**: Secure separation between regular `user` tasks and administrative overview tools.
* **Interactive Field Boundary Tools**: Live map UI to draw geo-polygons and calculate crop field acreage.
* **ReportLab PDF Exporter**: PDF generation module for farming data, crop classifications, harvest estimation, and colorized greenness index mappings.
* **Theme Customization**: Full Light Mode and Dark Mode support.
* **Localization**: Complete UI translation for English and Kannada.

---

## 3. Deployment & Setup instructions

1. **Backend Deployment**:
   * Ensure Docker & Docker Compose are running.
   * Launch backend service using:
     ```bash
     docker-compose up --build -d
     ```
   * Alternatively, run via virtualenv locally:
     ```bash
     cd krishivision_ai/backend
     .venv312\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
     ```

2. **Android Client Installation**:
   * Transfer [app-release.apk](file:///c:/Users/keert/Downloads/Krishi222-fixed/krishivision_ai/build/app/outputs/flutter-apk/app-release.apk) to an Android device.
   * Enable "Install from Unknown Sources" and launch the package installer.

---

## 4. Verification Verdict

All automated verification checkmarks have **Passed** successfully. The build is production-ready.
