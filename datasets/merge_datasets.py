import os
import shutil
import yaml


def resolve_dataset_dir(base_dir, dataset_name):
    dataset_dir = os.path.join(base_dir, dataset_name)

    if os.path.exists(os.path.join(dataset_dir, "data.yaml")):
        return dataset_dir

    if not os.path.isdir(dataset_dir):
        return dataset_dir

    for child in os.listdir(dataset_dir):
        child_dir = os.path.join(dataset_dir, child)
        if os.path.isdir(child_dir) and os.path.exists(os.path.join(child_dir, "data.yaml")):
            return child_dir

    return dataset_dir

def read_yaml(yaml_path):
    with open(yaml_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

def write_yaml(yaml_path, data):
    with open(yaml_path, 'w', encoding='utf-8') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)

def process_and_copy_dataset(src_dir, dest_dir, splits, label_offset=0):
    for split in splits:
        src_images_dir = os.path.join(src_dir, split, 'images')
        src_labels_dir = os.path.join(src_dir, split, 'labels')
        
        dest_images_dir = os.path.join(dest_dir, split, 'images')
        dest_labels_dir = os.path.join(dest_dir, split, 'labels')
        
        # Bỏ qua nếu thư mục split (train/valid/test) không tồn tại
        if not os.path.exists(src_images_dir) or not os.path.exists(src_labels_dir):
            continue

        os.makedirs(dest_images_dir, exist_ok=True)
        os.makedirs(dest_labels_dir, exist_ok=True)

        # Copy hình ảnh và xử lý file nhãn (txt)
        for img_name in os.listdir(src_images_dir):
            # Copy ảnh
            shutil.copy(os.path.join(src_images_dir, img_name), os.path.join(dest_images_dir, img_name))
            
            # Xử lý label tương ứng
            label_name = os.path.splitext(img_name)[0] + '.txt'
            src_label_path = os.path.join(src_labels_dir, label_name)
            dest_label_path = os.path.join(dest_labels_dir, label_name)
            
            if os.path.exists(src_label_path):
                with open(src_label_path, 'r') as f_in, open(dest_label_path, 'w') as f_out:
                    for line in f_in:
                        parts = line.strip().split()
                        if len(parts) >= 5:
                            class_id = int(parts[0])
                            new_class_id = class_id + label_offset
                            # Ghi lại với ID mới, giữ nguyên tọa độ bbox
                            f_out.write(f"{new_class_id} {' '.join(parts[1:])}\n")

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    money_dir = resolve_dataset_dir(base_dir, "money")
    obs_dir = resolve_dataset_dir(base_dir, "obstacles")
    master_dir = os.path.join(base_dir, "tak_aura_master")
    
    # 1. Đọc data.yaml từ 2 bộ dữ liệu
    money_yaml = read_yaml(os.path.join(money_dir, "data.yaml"))
    obs_yaml = read_yaml(os.path.join(obs_dir, "data.yaml"))
    
    money_classes = money_yaml.get('names', [])
    obs_classes = obs_yaml.get('names', [])
    
    # 2. Gộp danh sách nhãn
    master_classes = money_classes + obs_classes
    money_offset = 0
    obs_offset = len(money_classes) # Vật cản sẽ nối tiếp sau chỉ số của Tiền
    
    print(f"Tổng số lớp (classes): {len(master_classes)}")
    print(f"Các lớp Tiền (0 đến {obs_offset - 1}): {money_classes}")
    print(f"Các lớp Vật cản ({obs_offset} đến {len(master_classes) - 1}): {obs_classes}")

    # 3. Tạo data.yaml mới cho master dataset
    os.makedirs(master_dir, exist_ok=True)
    master_yaml_data = {
        'train': 'train/images',
        'val': 'valid/images',
        'test': 'test/images',
        'nc': len(master_classes),
        'names': master_classes
    }
    write_yaml(os.path.join(master_dir, "data.yaml"), master_yaml_data)

    # 4. Copy và re-map labels
    splits = ['train', 'valid', 'test']
    
    print("Đang xử lý dataset Tiền Việt Nam...")
    process_and_copy_dataset(money_dir, master_dir, splits, label_offset=money_offset)
    
    print("Đang xử lý dataset Vật cản (đang re-map labels)...")
    process_and_copy_dataset(obs_dir, master_dir, splits, label_offset=obs_offset)
    
    print(f"\nTuyệt vời! Master dataset đã được tạo thành công tại: {master_dir}")

if __name__ == "__main__":
    main()