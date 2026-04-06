import os

from ultralytics import YOLO


def main() -> None:
    checkpoint_path = 'runs/detect/takaura_v1/weights/last.pt'

    try:
        if os.path.exists(checkpoint_path):
            print('Phát hiện bản lưu trước đó. Đang tiếp tục train (resume)...')
            model = YOLO(checkpoint_path)
            model.train(resume=True)
        else:
            print('Bắt đầu train từ đầu...')
            model = YOLO('yolov8n.pt')
            model.train(
                data='ai_training/datasets/tak_aura_master/data.yaml',
                epochs=50,
                imgsz=640,
                batch=16,
                project='runs/detect',
                name='takaura_v1',
            )

    except KeyboardInterrupt:
        print('Đã dừng an toàn! File trạng thái lưu tại last.pt')


if __name__ == '__main__':
    main()
