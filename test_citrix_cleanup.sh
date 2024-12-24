#!/bin/bash

TARGET_DIRECTORIES=(
    "$HOME/test-citrix"
)

SEARCH_TERM="*citrix*"

function confirm_and_delete() {
    local file="$1"
    echo "Found: $file"
    while true; do
        read -p "Do you want to delete this file? (yes/no): " response
        case "$response" in
            [Yy][Ee][Ss]|[Yy])
                echo "Deleting: $file"
                rm -rf "$file" 2>/dev/null || echo "Failed to delete: $file"
                break
                ;;
            [Nn][Oo]|[Nn])
                echo "Skipping: $file"
                break
                ;;
            *)
                echo "Invalid response. Please type 'yes' or 'no'."
                ;;
        esac
    done
}

echo "Starting targeted search for Citrix-related files..."
for dir in "${TARGET_DIRECTORIES[@]}"; do
    echo "Scanning: $dir"
    find "$dir" -iname "$SEARCH_TERM" 2>/dev/null | while read -r file; do
        confirm_and_delete "$file"
    done
done

echo "Search and cleanup completed."
