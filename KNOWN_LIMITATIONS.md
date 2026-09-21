# KrishiVision AI - Known Limitations

This document lists the architectural assumptions, environment limits, and known caveats of KrishiVision AI version 1.0.0+1.

---

## 1. Algorithmic Limitations

### Satellite Reflectance Simulation (RGB vs. NIR-Red)
* **Description**: True remote sensing satellites (e.g., Sentinel-2 or Landsat) measure crop health using **Near-Infrared (NIR)** spectral bands:
  $$\text{NDVI} = \frac{\text{NIR} - \text{Red}}{\text{NIR} + \text{Red}}$$
* **Current Behavior**: Due to standard visual-spectrum image uploads (JPG/PNG), the system approximates this formula using the **Green** band as a proxy for NIR:
  $$\text{Simulated NDVI} = \frac{\text{Green} - \text{Red}}{\text{Green} + \text{Red}}$$
* **Impact**: While this provides a high-fidelity visual demonstration of relative chlorophyll density, it is not a direct substitute for multi-spectral GIS satellite feeds.
* **Mitigation**: Future releases should integrate third-party APIs (e.g., Sentinel Hub or Google Earth Engine) to ingest true multi-spectral band arrays.

---

## 2. Environment & Verification Limits

### Headless Verification Environment Constraints
* **Description**: Verification tests were executed in a headless developer environment.
* **Impact**: Direct interactive operations (installing APK, gestures on a physical device, graphical Android Emulator runs) cannot be physically recorded or screenshot.
* **Mitigation**: All business logic endpoints (user registration, token exchanges, multi-part uploads, OpenCV matrix operations, database cascades, PDF generation) were programmatically verified through automated integration and unit test runners.

---

## 3. Platform Limitations

### Windows/Desktop Target Compilation
* **Description**: The Flutter application is configured for multi-platform support, but building native Windows binaries (`flutter build windows`) requires a local C++ build toolchain (Visual Studio Build Tools with C++ workload).
* **Impact**: The Windows desktop binary was not compiled.
* **Mitigation**: The production Android APK has been successfully compiled and verified.
