![Optional Alt Text](https://github.com/nrebra/Skin-Disease-Diagnosis-AI-App/blob/d6827dbb074d16fa8c33ddc7bd9c8b09757ef8a4/skindisease.png?raw=tru)


# AI-Powered Skin Disease Detection & Doctor Consultation App

This Flutter-based mobile application is developed to support dermatologists and medical professionals in the early detection and analysis of skin conditions. The current repository includes only the **doctor-side interface** of the project.

---

## 🎯 Project Overview

The application aims to enhance diagnostic efficiency using artificial intelligence. With a user-friendly interface and integrated AI services, it enables doctors to upload images, review smart analysis results, and communicate with an AI chatbot.

---

## 🩺 Key Features 

- Upload skin images via camera or gallery
- Receive AI-powered diagnostic results (requires backend)
- Integrated chatbot powered by Google Generative AI (Gemini)
- Voice input and output support (speech-to-text / text-to-speech)
- Secure login system for doctors
- Access patient analysis history

> Patient-side features and backend (Python, YOLOv8, Flask, MySQL) are not included in this repository.

---

## 🧪 Technologies Used

- **Flutter** (UI & logic)
- **Provider** (state management)
- **Image Picker** (image upload)
- **HTTP** (API communication)
- **Speech to Text** / **Text to Speech** (voice interaction)
- **Google Generative AI** (chatbot)

---

## 🚀 Getting Started

```bash
git clone https://github.com/nrebra/Skin-Disease-AI-App.git
cd Skin-Disease-AI-App
flutter pub get
flutter run
