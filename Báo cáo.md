# BÁO CÁO TIẾN ĐỘ ĐỒ ÁN: TÌM HIỂU VÀ XÂY DỰNG ỨNG DỤNG TAKAURA HỖ TRỢ NGƯỜI KHIẾM THỊ DỰA TRÊN TRÍ TUỆ NHÂN TẠO

## CHƯƠNG 1: TỔNG QUAN DỰ ÁN
**1.1. Giới thiệu bài toán**
Người khiếm thị tại Việt Nam gặp nhiều khó khăn trong việc di chuyển an toàn và nhận diện các vật dụng thiết yếu hàng ngày, đặc biệt là tiền mặt. Dự án "TakAura" (Tầm nhìn Chim ưng + Hào quang bảo vệ) được đề xuất nhằm giải quyết vấn đề này thông qua một ứng dụng di động thông minh, tích hợp mô hình thị giác máy tính (Computer Vision) hoạt động theo thời gian thực.

**1.2. Mục tiêu nghiên cứu**
- Xây dựng một mô hình nhận diện vật thể (Object Detection) thống nhất có khả năng phát hiện đồng thời Mệnh giá tiền Việt Nam và Các vật cản nguy hiểm (cột điện, ổ gà,...).
- Tích hợp mô hình AI vào ứng dụng di động đa nền tảng (Flutter) với khả năng chạy cục bộ (offline) để đảm bảo tốc độ phản hồi và tính bảo mật.

## CHƯƠNG 2: TIỀN XỬ LÝ VÀ CHUẨN BỊ DỮ LIỆU
**2.1. Đánh giá hiện trạng bộ dữ liệu**
Dữ liệu ban đầu bao gồm 2 tập dataset độc lập: Dataset 1: Tiền Việt Nam (10 nhãn); Dataset 2: Vật cản giao thông (7 nhãn).
Thách thức đặt ra là sự trùng lặp về không gian vector nhãn (label indices), khiến mô hình không thể học tập trung nếu không được xử lý đồng nhất.

**2.2. Phương pháp tích hợp và chuẩn hóa**
Đã tiến hành xây dựng kịch bản tự động hóa (Python Script) để dung hợp 2 tập dữ liệu:
- **Label Re-mapping:** Áp dụng tịnh tiến chỉ số (index offset) cho bộ dữ liệu Vật cản. Chỉ số mới được nối tiếp ngay sau tập Tiền Việt Nam, tạo ra không gian nhãn tuyến tính 17 lớp.
- **Data Consolidation:** Tổng hợp cấu trúc thư mục YOLO chuẩn. 
- **Kết quả:** Tập dữ liệu tổng hợp đạt quy mô 7047 ảnh huấn luyện, 933 ảnh kiểm chứng và 115 ảnh đánh giá.

## CHƯƠNG 3: THIẾT KẾ VÀ HUẤN LUYỆN MÔ HÌNH
**3.1. Lựa chọn kiến trúc mạng**
Mạng nơ-ron tích chập YOLOv8 phiên bản Nano (yolov8n) được lựa chọn dựa trên sự cân bằng tối ưu giữa độ chính xác (mAP) và chi phí tính toán (FLOPs thấp), phù hợp cho thiết bị biên.
**3.2. Cấu hình tham số siêu liên kết (Hyperparameters)**
- Image Size: 640x640. Batch Size: 16. Epochs: 50.

## CHƯƠNG 4: TRIỂN KHAI THỰC TẾ TRÊN THIẾT BỊ BIÊN
**4.1. Cấu hình môi trường thiết bị biên (Edge Device)**
Hệ thống đã cấu hình thành công Android Toolchain. Quá trình kiểm thử và suy luận mô hình được tiến hành trực tiếp trên thiết bị thực tế (Samsung SM A536E, kiến trúc android-arm64, Android 16) thay vì trình giả lập (Emulator). Điều này nhằm đảm bảo tính chính xác khi đánh giá tốc độ khung hình (FPS) của Camera và hiệu năng xử lý Tensor thực tế của phần cứng.

**4.2. Kết quả kiểm thử phiên bản Camera Runtime**
- Ứng dụng khởi chạy thành công trên thiết bị thật.
- Quyền Camera được xin và cấp hợp lệ, không phát sinh crash.
- Preview Camera hiển thị ổn định với giao diện tương phản cao.

## CHƯƠNG 5: MỞ RỘNG HỆ THỐNG AI VÀ TRẢI NGHIỆM NGƯỜI DÙNG
**5.1. Chiến lược huấn luyện thật (Phương án 1)**
Script huấn luyện được nâng cấp theo hướng auto-resume dựa trên checkpoint `last.pt`. Cơ chế này cho phép tiếp tục quá trình train khi có gián đoạn, giảm rủi ro mất tiến độ ở các phiên huấn luyện dài.

**5.2. Thiết kế màn hình chào mừng (Splash Screen)**
Ứng dụng được bổ sung Splash Screen với phong cách thị giác tương phản cao (nền đen, chữ vàng lớn, thanh chờ) trong ~3 giây trước khi điều hướng sang màn hình Camera. Thiết kế này giúp khởi tạo mềm mại hơn, tránh cảm giác "nhảy thẳng" vào luồng camera và cải thiện UX cho người dùng mục tiêu.

**5.3. Chuẩn bị tích hợp mô hình YOLOv8-TFLite**
Kiến trúc module `TFLiteService` đã được tách riêng để xử lý nạp model, nạp nhãn, nhận frame và suy luận. Cấu trúc này giúp mở rộng thuận lợi cho các bước tối ưu hóa hậu xử lý (NMS, threshold tuning) và kết hợp thêm TTS cảnh báo trong các giai đoạn tiếp theo.
