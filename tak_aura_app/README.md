# TakAura

Flutter starter for TakAura mobile app.

## Environment Setup (Windows)

Nếu lệnh `flutter` chưa nhận diện, thực hiện theo thứ tự:

```powershell
# 1) Tải Flutter SDK và giải nén vào D:\tools\flutter (ví dụ)

# 2) Thêm vào PATH (User scope)
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";D:\tools\flutter\bin", "User")

# 3) Mở PowerShell mới và kiểm tra
flutter --version
flutter doctor
```

## Quick Start

1. Place your model file in `assets/models/`, for example:
	- `assets/models/best_float16.tflite`
2. Confirm labels file exists:
	- `assets/models/labels.txt`
3. Install packages and run:

```powershell
Set-Location d:\TakAura_Project\ai_training\tak_aura_app
flutter pub get
flutter run
```

Nếu dự án chưa có đầy đủ native scaffold do chưa chạy Flutter trước đó, chạy thêm 1 lần:

```powershell
Set-Location d:\TakAura_Project\ai_training\tak_aura_app
flutter create .
flutter pub get
flutter run
```

## Current Scope

- Realtime camera preview screen
- Camera permission request flow
- High-contrast accessibility UI
- TFLite and TTS dependencies configured (infrastructure only)
