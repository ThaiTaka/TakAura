import argparse
import os
from glob import glob
from pathlib import Path

from ultralytics import YOLO


def resolve_checkpoint(default_path: str, project: str, run_name: str) -> str | None:
    preferred = Path(default_path)
    if preferred.exists():
        return str(preferred)

    project_dir = Path(project)
    name_pattern = f'{run_name}*/weights/last.pt'
    candidates = list(project_dir.glob(name_pattern))
    if not candidates:
        return None

    candidates.sort(key=lambda path: path.stat().st_mtime, reverse=True)
    return str(candidates[0])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Train TakAura YOLO model with robust handheld-money preset.'
    )
    parser.add_argument(
        '--data',
        default='ai_training/datasets/tak_aura_master/data.yaml',
        help='Dataset yaml path',
    )
    parser.add_argument('--epochs', type=int, default=80)
    parser.add_argument('--imgsz', type=int, default=640)
    parser.add_argument('--batch', type=int, default=16)
    parser.add_argument('--project', default='runs/detect')
    parser.add_argument('--name', default='takaura_v1')
    parser.add_argument(
        '--checkpoint',
        default='runs/detect/takaura_v1/weights/last.pt',
        help='Checkpoint path for resume',
    )
    parser.add_argument(
        '--resume',
        action='store_true',
        help='Resume from last checkpoint if available',
    )
    parser.add_argument(
        '--workers',
        type=int,
        default=4,
        help='DataLoader workers',
    )
    return parser.parse_args()


def train_kwargs(args: argparse.Namespace) -> dict:
    return {
        'data': args.data,
        'epochs': args.epochs,
        'imgsz': args.imgsz,
        'batch': args.batch,
        'project': args.project,
        'name': args.name,
        'workers': args.workers,
        'cos_lr': True,
        'close_mosaic': 10,
        'hsv_h': 0.015,
        'hsv_s': 0.75,
        'hsv_v': 0.45,
        'degrees': 8.0,
        'translate': 0.10,
        'scale': 0.35,
        'shear': 2.0,
        'perspective': 0.0008,
        'flipud': 0.0,
        'fliplr': 0.5,
        'mosaic': 0.65,
        'mixup': 0.12,
        'copy_paste': 0.10,
        'erasing': 0.40,
    }


def main() -> None:
    args = parse_args()
    resolved_checkpoint = resolve_checkpoint(
        default_path=args.checkpoint,
        project=args.project,
        run_name=args.name,
    )

    try:
        if args.resume and resolved_checkpoint is not None:
            print('Phát hiện bản lưu trước đó. Đang tiếp tục train (resume)...')
            print(f'Checkpoint: {resolved_checkpoint}')
            model = YOLO(resolved_checkpoint)
            model.train(resume=True)
        else:
            if args.resume:
                print('Không tìm thấy checkpoint. Chuyển sang train từ đầu...')
            else:
                print('Bắt đầu train từ đầu...')

            print(
                'Preset tăng bền vững cho tiền cầm tay: '
                'occlusion, blur-like augmentation, perspective, mixup nhẹ.'
            )
            model = YOLO('yolov8n.pt')
            model.train(**train_kwargs(args))

    except KeyboardInterrupt:
        print('Đã dừng an toàn! File trạng thái lưu tại last.pt')


if __name__ == '__main__':
    main()
