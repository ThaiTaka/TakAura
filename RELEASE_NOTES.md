# TakAura Release Notes

## v1.0.0-alpha (2026-04-09)

Bản tổng hợp nhanh sau giai đoạn train thành công 50 epochs và tích hợp model vào app.

## ✅ What We Shipped

- Hoàn thiện pipeline: **Dataset -> Train (YOLOv8) -> Export TFLite -> Flutter integration**.
- Cập nhật `train_takaura.py` với preset augmentation tối ưu cho bối cảnh tiền cầm tay.
- Cập nhật `export_tflite.py`:
  - Hỗ trợ export `fp16`/`int8`.
  - Tự tìm `best.pt` mới nhất.
  - Cải thiện thông báo lỗi khi thiếu dependency/pipeline export lỗi.
- Tích hợp model vào app Flutter:
  - Assets model trong `tak_aura_app/assets/models/`.
  - Cập nhật luồng camera + TFLite service trong app.
- Nâng cấp tài liệu dự án:
  - `README.md` có benchmark, media, roadmap, known issues, next experiments.

## 📊 KPI Snapshot (Run: `takaura_v1`, Epoch 50)

Nguồn: `runs/detect/runs/detect/takaura_v1/results.csv`

| Metric | Value |
|---|---:|
| Precision | 0.92112 |
| Recall | 0.86008 |
| mAP50 | 0.90579 |
| mAP50-95 | 0.77615 |

| Artifact | Size |
|---|---:|
| `best_float16.tflite` | 5.82 MB |
| `takaura_fp16.tflite` | 11.56 MB |

## ⚠️ Known Issues

- Có nhiều `results.csv` trong workspace; dễ đọc nhầm run nếu không chốt đúng path.
- Chưa có benchmark latency chuẩn hóa theo từng thiết bị mục tiêu.
- Chưa có `demo.gif` inference realtime trong README.
- Git có cảnh báo dọn kho object (`unreachable loose objects`) trên local.

## 🧪 Next Experiments (Priority)

1. So sánh `fp16` vs `int8` trên cùng thiết bị (mAP, latency, memory).
2. Ablation augmentation (`mosaic`, `mixup`, `copy_paste`, `erasing`).
3. Bổ sung ảnh khó (blur, backlight, che khuất mạnh) và đo lại confusion matrix.
4. Chuẩn hóa release KPI: mAP50, mAP50-95, FPS, P95 latency, model size.
5. Thêm video/GIF demo inference trực tiếp từ app.

## 🔖 Notes

- Trạng thái branch đã được chỉnh về tracking `origin/master`.
- Tài liệu này phục vụ cập nhật nhanh cho team/dev và showcase trên GitHub.
