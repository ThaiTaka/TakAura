# PHÂN TÍCH KIẾN TRÚC VÀ CÔNG NGHỆ ÁP DỤNG TRONG TAKAURA

## 1. Ultralytics YOLOv8 (Phiên bản Nano)
- **Vai trò:** Bộ não thị giác nhận diện vật thể.
- **Lý do:** YOLO là mạng one-stage detector ưu tiên tốc độ realtime. Bản Nano có dung lượng weights nhỏ (<10MB), tối thiểu hóa RAM.

## 2. Python 3
- **Vai trò:** Viết scripts tự động hóa làm sạch, dung hợp dữ liệu và pipeline huấn luyện.
- **Lý do:** Hệ sinh thái thư viện phong phú (PyTorch, OpenCV), tiêu chuẩn công nghiệp ngành Học máy.

## 3. TensorFlow Lite (TFLite)
- **Vai trò:** Cầu nối giữa mô hình huấn luyện và thiết bị di động.
- **Lý do:** TFLite cung cấp thuật toán lượng tử hóa (Quantization FP16/Int8) giúp tăng tốc độ suy luận bằng NPU/CPU của điện thoại mà không làm sụt giảm nhiều mAP.

## 4. Flutter (Dart)
- **Vai trò:** Xây dựng UI và xử lý logic (Camera, AI, TTS).
- **Lý do:** Biên dịch chéo đa nền tảng, hỗ trợ tốt packages camera và Text-to-Speech, đáp ứng chuẩn UI độ tương phản cao cho người khiếm thị.
