# TakAura — Real-time Handheld Money Detection

[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Flutter](https://img.shields.io/badge/Flutter-Mobile_App-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![YOLOv8](https://img.shields.io/badge/YOLOv8-Ultralytics-111111)](https://github.com/ultralytics/ultralytics)
[![TensorFlow Lite](https://img.shields.io/badge/TFLite-On--device-FF6F00?logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![Status](https://img.shields.io/badge/Status-Active%20Development-2ea44f)](#roadmap)

TakAura là dự án AI + Flutter để nhận diện tiền trong điều kiện thực tế (cầm tay, góc nghiêng, che khuất nhẹ), huấn luyện bằng YOLOv8 và triển khai trên mobile bằng TensorFlow Lite.

## ✨ Highlights

- End-to-end pipeline: **Dataset → Train → Export TFLite → Flutter app**
- Preset augmentation tối ưu cho tiền cầm tay (occlusion, perspective, mixup nhẹ)
- Script export TFLite có xử lý lỗi thân thiện và tự tìm `best.pt` mới nhất
- Cấu trúc repo rõ ràng cho cả team AI và mobile

## 🧱 Project Structure

```text
ai_training/
├── train_takaura.py                      # Train YOLOv8 với preset robust
├── export_tflite.py                      # Export model sang TFLite (fp16/int8)
├── requirements.txt
├── datasets/
│   ├── tak_aura_master/
│   ├── money/
│   └── obstacles/
└── tak_aura_app/                         # Flutter app chạy model on-device
	├── lib/
	├── assets/models/
	└── pubspec.yaml
```

## 🚀 Quick Start (Training)

```powershell
Set-Location d:\TakAura_Project\ai_training
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python train_takaura.py --data ai_training/datasets/tak_aura_master/data.yaml --epochs 80 --imgsz 640
```

Model sẽ được lưu trong `runs/detect/<run_name>/weights/`.

## 📦 Export to TFLite

```powershell
Set-Location d:\TakAura_Project\ai_training
.\.venv\Scripts\Activate.ps1
python export_tflite.py --mode fp16
```

Kết quả được copy vào:

- `ai_training/tak_aura_app/assets/models/takaura_fp16.tflite` hoặc
- `ai_training/tak_aura_app/assets/models/takaura_int8.tflite`

## 📱 Flutter App Run

```powershell
Set-Location d:\TakAura_Project\ai_training\tak_aura_app
flutter pub get
flutter run
```

Yêu cầu tối thiểu:

- File model trong `assets/models/`
- File nhãn `assets/models/labels.txt`

## 🔁 Training Preset (Current)

`train_takaura.py` đang dùng preset giúp mô hình bền hơn trong bối cảnh thực:

- `cos_lr=True`, `close_mosaic=10`
- `mosaic=0.65`, `mixup=0.12`, `copy_paste=0.10`
- `degrees=8.0`, `translate=0.10`, `scale=0.35`
- `hsv_s=0.75`, `hsv_v=0.45`, `erasing=0.40`

## 🛣️ Roadmap

- [x] Huấn luyện YOLOv8 baseline
- [x] Export TFLite và tích hợp vào Flutter assets
- [x] Camera flow + inference service trong app
- [ ] Đánh giá thêm mAP/F1 theo từng denomination
- [ ] Tối ưu latency và memory cho thiết bị tầm trung
- [ ] Thêm demo GIF/video vào README

## 🤝 Contributing

1. Tạo branch từ `master`
2. Commit theo nhóm thay đổi rõ ràng
3. Mở Pull Request mô tả mục tiêu + kết quả test

## 📄 Notes

- Repo này tập trung vào ứng dụng thực tế và iteration nhanh.
- Có thể điều chỉnh nhanh tham số train qua CLI trong `train_takaura.py`.
