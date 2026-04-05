from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path


DEFAULT_WEIGHTS = Path("runs/detect/takaura_v1/weights/best.pt")
DEFAULT_OUTPUT_DIR = Path("ai_training/tak_aura_app/assets/models")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export TakAura YOLO model to TFLite.")
    parser.add_argument("--weights", type=Path, default=DEFAULT_WEIGHTS, help="Path to best.pt")
    parser.add_argument("--mode", choices=["fp16", "int8"], default="fp16", help="Mobile optimization mode")
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_DIR, help="Output directory for Flutter assets")
    return parser.parse_args()


def print_missing_lib_help() -> None:
    print("\n[FIX] Thiếu thư viện export.")
    print("Cài đặt:")
    print("pip install ultralytics tensorflow")


def print_export_error_help(exc: Exception) -> None:
    message = str(exc).lower()

    if any(token in message for token in ["no module named", "importerror", "modulenotfounderror"]):
        print_missing_lib_help()
        return

    if any(token in message for token in ["tflite", "tensorflow", "onnx", "saved_model"]):
        print("\n[FIX] Lỗi pipeline export TFLite.")
        print("- Cập nhật ultralytics + tensorflow")
        print("- Dùng Python 3.10/3.11")
        print("- Thử mode fp16 trước nếu int8 lỗi")
        print("Lệnh:")
        print("pip install --upgrade ultralytics tensorflow")
        return

    print("\n[FIX] Lỗi chưa phân loại. Kiểm tra traceback chi tiết phía trên.")


def find_latest_tflite(search_root: Path) -> Path | None:
    candidates = list(search_root.rglob("*.tflite"))
    if not candidates:
        return None
    candidates.sort(key=lambda path: path.stat().st_mtime, reverse=True)
    return candidates[0]


def main() -> int:
    args = parse_args()

    try:
        from ultralytics import YOLO
    except Exception:
        print_missing_lib_help()
        return 1

    weights_path = args.weights.resolve()
    if not weights_path.exists():
        print(f"[ERROR] Không tìm thấy weights: {weights_path}")
        print("Hãy train trước hoặc truyền --weights đúng đường dẫn.")
        return 1

    output_dir = args.output.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        model = YOLO(str(weights_path))
        export_kwargs = {
            "format": "tflite",
            "imgsz": args.imgsz,
        }

        if args.mode == "fp16":
            export_kwargs["half"] = True
        else:
            export_kwargs["int8"] = True

        print(f"[INFO] Exporting with mode={args.mode} ...")
        model.export(**export_kwargs)
    except Exception as exc:
        print(f"\n[ERROR] Export failed: {exc}")
        print_export_error_help(exc)
        return 1

    exported_tflite = find_latest_tflite(weights_path.parent.parent)
    if not exported_tflite:
        print("[ERROR] Export báo thành công nhưng không tìm thấy file .tflite")
        return 1

    target_name = f"takaura_{args.mode}.tflite"
    target_path = output_dir / target_name
    shutil.copy2(exported_tflite, target_path)

    print("\n[SUCCESS] Export hoàn tất.")
    print(f"- Source: {exported_tflite}")
    print(f"- Copied to: {target_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
