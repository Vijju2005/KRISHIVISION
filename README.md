# KRISHIVISION

### Better Farming, Better Tomorrow 🌱

KRISHIVISION is an Android agricultural intelligence application designed to provide location-specific crop information and crop monitoring through an interactive map, government agricultural data, and satellite-based analysis.

## 👥 Team Members

- **Vijayalaxmi C Choudari** — U23E01AI069
- **Syed Hashim** — U23E01AI061

## 🎯 Project Objective

The main objective of KRISHIVISION is to provide users with location-specific agricultural information through a single mobile application.

The application allows users to navigate from:

**India → State → District → Crop → Crop Details → Health & Growth Analysis → Harvest Information → PDF Report**

## ✨ Key Features

- 🔐 Secure user authentication
- 🗺️ Interactive India map
- 📍 State and district selection
- 🌾 District-specific crop information
- 📊 Government agricultural APY data
- 🛰️ Satellite-based crop observation
- 🌿 NDVI and EVI analysis
- ❤️ Crop health information
- 📈 Crop growth-stage information
- 🌾 Expected harvest information
- 📄 Agricultural PDF report generation
- 📱 Android mobile application
- ☁️ Hosted backend services

## 🛠️ Technology Stack

### Frontend
- Flutter
- Dart
- Android

### Backend
- Python
- FastAPI
- REST API

### Database
- PostgreSQL

### Maps & GIS
- Google Maps
- Geographic state and district boundaries

### Agricultural Data
- Government Area, Production and Yield (APY) data
- District-specific crop statistics

### Satellite Analysis
- Satellite-based vegetation analysis
- NDVI
- EVI

### Authentication
- JWT Authentication

### Deployment
- GitHub
- Render

## 🏗️ System Architecture

```text
                 KRISHIVISION
                      │
                      ▼
          ┌─────────────────────┐
          │   FLUTTER ANDROID   │
          │       CLIENT        │
          ├─────────────────────┤
          │ Login               │
          │ Dashboard           │
          │ Interactive Map     │
          │ District Crops      │
          │ Crop Details        │
          │ Health & Growth     │
          │ Harvest             │
          │ PDF Report          │
          └──────────┬──────────┘
                     │
                     │ REST API
                     ▼
          ┌─────────────────────┐
          │   FASTAPI BACKEND   │
          │       PYTHON        │
          ├─────────────────────┤
          │ Authentication      │
          │ Map APIs            │
          │ Crop APIs           │
          │ Satellite Analysis  │
          │ Health Analysis     │
          │ Growth Analysis     │
          │ Harvest Information │
          │ PDF Generation      │
          └──────────┬──────────┘
                     │
                     ▼
          ┌─────────────────────┐
          │     POSTGRESQL      │
          │      DATABASE       │
          ├─────────────────────┤
          │ States              │
          │ Districts           │
          │ Crops               │
          │ APY Statistics      │
          │ Analysis Data       │
          └─────────────────────┘
