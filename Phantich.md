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

## 5. Module TFLiteService (Kiến trúc tách lớp AI)
- **Vai trò:** Tách riêng tầng suy luận mô hình khỏi tầng giao diện camera.
- **Lý do:** Thiết kế service độc lập giúp code dễ bảo trì, dễ kiểm thử, và cho phép tối ưu hậu xử lý (lọc confidence, NMS, mapping bounding box) mà không làm rối luồng UI.

## 6. Chiến lược kiểm thử trên thiết bị thực (Real Device Testing)
- **Vai trò:** Đánh giá hiệu năng và UX/UI trong điều kiện thực tế.
- **Lý do lựa chọn:** Trình giả lập (Emulator) trên máy tính không thể phản ánh chính xác độ trễ của API Camera và giới hạn tài nguyên (RAM/CPU) của điện thoại. Việc triển khai trực tiếp lên phần cứng ARM64 (Samsung SM A536E) là bắt buộc để kiểm chứng tốc độ suy luận của mô hình YOLOv8-TFLite có đáp ứng được yêu cầu thời gian thực của người khiếm thị hay không.

## 7. Splash Screen và tính liên tục trải nghiệm
- **Vai trò:** Tạo lớp đệm trải nghiệm khi ứng dụng khởi động trước khi vào camera realtime.
- **Lý do:** Màn hình chào mừng giúp quá trình chuyển cảnh mượt hơn, tăng cảm giác ổn định hệ thống, đồng thời giữ tính nhất quán với nguyên tắc thiết kế tương phản cao của TakAura.
