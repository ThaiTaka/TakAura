from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml


DEFAULT_DATASET_YAML = Path("ai_training/datasets/tak_aura_master/data.yaml")


def ensure_yaml_path_key(dataset_yaml_path: Path, auto_fix: bool = True) -> None:
    with dataset_yaml_path.open("r", encoding="utf-8") as file:
        data = yaml.safe_load(file) or {}

    dataset_root = dataset_yaml_path.parent.resolve()
    current_path = data.get("path")

    if current_path and Path(current_path).exists():
        return

    if not auto_fix:
        print("[WARN] data.yaml chưa có 'path' hợp lệ.")
        print(f"[HINT] Thêm dòng: path: {dataset_root}")
        return

    data["path"] = str(dataset_root)
    with dataset_yaml_path.open("w", encoding="utf-8") as file:
        yaml.safe_dump(data, file, allow_unicode=True, sort_keys=False)

    print(f"[INFO] Đã cập nhật path trong data.yaml -> {dataset_root}")


def print_missing_lib_help() -> None:
    print("\n[FIX] Thiếu thư viện. Cài dependencies bằng:")
    print("pip install ultralytics pyyaml")
    print("pip install --upgrade pip")


def print_path_error_help(dataset_yaml_path: Path) -> None:
    dataset_root = dataset_yaml_path.parent.resolve()
    print("\n[FIX] Có lỗi đường dẫn dataset.")
    print("1) Kiểm tra file có tồn tại:")
    print(f"   {dataset_yaml_path}")
    print("2) Trong data.yaml, thêm/sửa dòng:")
    print(f"   path: {dataset_root}")
    print("3) Chạy lại script từ root project.")


def print_oom_help() -> None:
    print("\n[FIX] GPU Out Of Memory (OOM). Thử các cấu hình an toàn hơn:")
    print("- Giảm batch: 16 -> 8 hoặc 4")
    print("- Giảm imgsz: 640 -> 512 hoặc 416")
    print("- Dùng AMP: amp=True (mặc định đã bật)")
    print("- Nếu vẫn lỗi, train bằng CPU: device=cpu")
    print("\nVí dụ:")
    print("python train_takaura.py --batch 8 --imgsz 512")


def analyze_training_exception(exc: Exception, dataset_yaml_path: Path) -> None:
    message = str(exc).lower()

    if any(token in message for token in ["no module named", "importerror", "modulenotfounderror"]):
        print_missing_lib_help()
        return

    if any(token in message for token in ["out of memory", "cuda out of memory", "cudnn", "oom"]):
        print_oom_help()
        return

    if any(token in message for token in ["data", "yaml", "not found", "path", "filenotfound"]):
        print_path_error_help(dataset_yaml_path)
        return

    print("\n[FIX] Lỗi chưa được phân loại tự động.")
    print("- Kiểm tra traceback phía trên")
    print("- Kiểm tra file data.yaml và quyền truy cập file")


def train_model(dataset_yaml_path: Path, epochs: int, imgsz: int, batch: int, device: str) -> None:
    try:
        from ultralytics import YOLO
    except Exception:
        print_missing_lib_help()
        raise

    model = YOLO("yolov8n.pt")
    model.train(
        data=str(dataset_yaml_path),
        epochs=epochs,
        imgsz=imgsz,
        batch=batch,
        project="runs/detect",
        name="takaura_v1",
        device=device,
        amp=True,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train YOLOv8n for TakAura dataset.")
    parser.add_argument("--data", type=Path, default=DEFAULT_DATASET_YAML, help="Path to data.yaml")
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--device", type=str, default="0", help="0,1,... hoặc cpu")
    parser.add_argument("--no-autofix-path", action="store_true", help="Không tự thêm path vào data.yaml")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    dataset_yaml_path = args.data.resolve()

    if not dataset_yaml_path.exists():
        print(f"[ERROR] Không tìm thấy data.yaml: {dataset_yaml_path}")
        print_path_error_help(dataset_yaml_path)
        return 1

    ensure_yaml_path_key(dataset_yaml_path, auto_fix=not args.no_autofix_path)

    try:
        train_model(
            dataset_yaml_path=dataset_yaml_path,
            epochs=args.epochs,
            imgsz=args.imgsz,
            batch=args.batch,
            device=args.device,
        )
    except Exception as exc:
        print(f"\n[ERROR] Training failed: {exc}")
        analyze_training_exception(exc, dataset_yaml_path)
        return 1

    print("\n[SUCCESS] Training hoàn tất.")
    print("Best weight thường nằm tại: runs/detect/takaura_v1/weights/best.pt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
