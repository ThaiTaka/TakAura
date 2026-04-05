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
