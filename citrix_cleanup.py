import os
import shutil

def find_citrix_files(base_paths, dry_run=True):
    """
    Search for files containing 'citrix' in their names and prompt for deletion.
    """
    for base_path in base_paths:
        for root, dirs, files in os.walk(base_path):
            # Check directories
            for directory in dirs:
                if 'citrix' in directory.lower():
                    target_path = os.path.join(root, directory)
                    handle_file_or_dir(target_path, dry_run)
            
            # Check files
            for file in files:
                if 'citrix' in file.lower():
                    target_path = os.path.join(root, file)
                    handle_file_or_dir(target_path, dry_run)

def handle_file_or_dir(target_path, dry_run):
    """
    Prompt the user to delete the file or directory.
    """
    action = "Would delete" if dry_run else "Delete"
    print(f"[{action}] {target_path}")
    
    if not dry_run:
        while True:
            response = input(f"Do you want to delete {target_path}? (yes/no): ").strip().lower()
            if response == 'yes':
                try:
                    if os.path.isfile(target_path):
                        os.remove(target_path)
                    elif os.path.isdir(target_path):
                        shutil.rmtree(target_path)
                    print(f"Deleted: {target_path}")
                except Exception as e:
                    print(f"Error deleting {target_path}: {e}")
                break
            elif response == 'no':
                print(f"Skipped: {target_path}")
                break
            else:
                print("Invalid response. Please type 'yes' or 'no'.")

if __name__ == "__main__":
    # Directories to target
    target_dirs = [
        "/Applications",
        "/Library",
        "/System/Library",
        "/usr/local",
        "/Users",
        "/private/var",
        "/tmp",
    ]

    # Set dry_run to True for a dry run, False to actually delete files
    dry_run = False  # Change to False to enable deletion
    print("Starting targeted search for Citrix-related files...")
    find_citrix_files(target_dirs, dry_run=dry_run)
    print("Search and cleanup completed.")
