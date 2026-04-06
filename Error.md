# SỔ TAY GHI NHẬN VÀ XỬ LÝ SỰ CỐ (TROUBLESHOOTING LOG)

### Lỗi 1: Không tìm thấy thư viện hỗ trợ khi chạy script Python
- **Nguyên nhân:** Môi trường thực thi chưa cài đặt dependencies (YAML, Ultralytics).
- **Giải pháp:** Khởi tạo môi trường ảo `python -m venv venv`, kích hoạt và chạy `pip install pyyaml ultralytics`.

### Lỗi 2: Ultralytics không tìm thấy tập dữ liệu
- **Nguyên nhân:** File `data.yaml` định nghĩa đường dẫn tương đối không khớp với Working Directory.
- **Giải pháp:** Bổ sung tham số `path` gốc vào dòng đầu tiên của file `data.yaml`.

### Lỗi 3: Xung đột chỉ số nhãn (Đã ngăn chặn)
- **Nguyên nhân:** Copy thủ công file `.txt` làm trùng lặp ID của vật thể.
- **Giải pháp:** Lập trình thuật toán re-mapping cộng thêm hệ số lệch (offset) vào ID của tập dữ liệu thứ 2 trước khi ghi ra file.

### Lỗi 4: Không tìm thấy file pubspec.yaml khi chạy Flutter
- **Mô tả lỗi:** `Error: No pubspec.yaml file found. This command should be run from the root of your Flutter project.`
- **Nguyên nhân:** Thực thi lệnh `flutter run` sai vị trí (đang đứng ở thư mục gốc chứa toàn bộ dự án thay vì thư mục chứa mã nguồn Flutter).
- **Giải pháp:** Sử dụng lệnh `cd tak_aura_app` (hoặc tên thư mục Flutter tương ứng) để chuyển hướng Terminal vào đúng không gian làm việc của Flutter trước khi chạy lệnh build.

### Lỗi 5: Build Gradle thất bại do khai báo package sai quy chuẩn mới
- **Mô tả lỗi:** `Incorrect package="com.takaura.app" found in source AndroidManifest.xml... Setting the namespace via the package attribute... is no longer supported.`
- **Nguyên nhân:** Phiên bản Android Gradle Plugin (AGP) mới (từ 8.0 trở lên) đã loại bỏ việc định nghĩa `package` bên trong file `AndroidManifest.xml`. Namespace hiện tại phải được quản lý hoàn toàn ở file `android/app/build.gradle`.
- **Giải pháp:** Mở file `android/app/src/main/AndroidManifest.xml` và xóa bỏ đoạn `package="com..."` nằm trong thẻ `<manifest>`.

### Lỗi 6: Ứng dụng luôn báo "Mô hình AI chưa sẵn sàng"
- **Mô tả lỗi:** Bấm nút kích hoạt AI nhưng app hiển thị thông báo chờ mô hình trong thời gian dài.
- **Nguyên nhân:** Chưa có file `best_float16.tflite` trong `assets/models/` hoặc tên file không khớp với đường dẫn load model.
- **Giải pháp:** Đảm bảo file model nằm đúng tại `tak_aura_app/assets/models/best_float16.tflite`, sau đó chạy lại `flutter pub get` và `flutter run`.

### Lỗi 7: Flutter không nhận thiết bị khi dùng tên có khoảng trắng
- **Mô tả lỗi:** `Target file "A536E" not found.` khi chạy `flutter run -d SM A536E`.
- **Nguyên nhân:** Tên thiết bị có khoảng trắng nên command parser tách sai tham số.
- **Giải pháp:** Dùng device id hoặc đặt tên thiết bị trong dấu nháy kép, ví dụ: `flutter run -d "SM A536E"` hoặc `flutter run -d R5CT82FSLBM`.
