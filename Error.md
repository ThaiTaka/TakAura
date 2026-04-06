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

### Lỗi 5: Build Gradle thất bại do khai báo package sai quy chuẩn mới
- **Mô tả lỗi:** `Incorrect package="com.takaura.app" found in source AndroidManifest.xml... Setting the namespace via the package attribute... is no longer supported.`
- **Nguyên nhân:** Phiên bản Android Gradle Plugin (AGP) mới (từ 8.0 trở lên) đã loại bỏ việc định nghĩa `package` bên trong file `AndroidManifest.xml`. Namespace hiện tại phải được quản lý hoàn toàn ở file `android/app/build.gradle`.
- **Giải pháp:** Mở file `android/app/src/main/AndroidManifest.xml` và xóa bỏ đoạn `package="com..."` nằm trong thẻ `<manifest>`.
