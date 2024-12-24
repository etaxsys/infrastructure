#!/bin/bash

# Define likely directories to search first
# TARGET_DIRECTORIES=(
    # "/Applications"
    # "/Library"
    # "/System/Library"
    # "/usr/local"
    # "$HOME/Library"
# )

TARGET_DIRECTORIES=(
    "$HOME/test-citrix"
)

# Temporary file for storing results
TEMP_FILE=$(mktemp)

echo "Starting targeted search for Citrix-related files..."

# Step 1: Search in likely directories
for dir in "${TARGET_DIRECTORIES[@]}"; do
    echo "Scanning: $dir"
    sudo find "$dir" -iname "*citrix*" 2>/dev/null >> "$TEMP_FILE"
done

# Function to prompt for deletion
prompt_for_deletion() {
    local file=$1
    while true; do
        read -p "Delete this file? (yes/no): " response
        if [[ -z "$response" ]]; then
            echo "Invalid response. Please type 'yes' or 'no'."
            continue
        fi
        case "$response" in
            [Yy]*)
                if [ -d "$file" ]; then
                    echo "Removing directory: $file"
                    sudo rm -rf "$file"
                else
                    echo "Removing file: $file"
                    sudo rm -f "$file"
                fi
                break
                ;;
            [Nn]*)
                echo "Skipping: $file"
                break
                ;;
            *)
                echo "Invalid response. Please type 'yes' or 'no'."
                ;;
        esac
    done
}

# Process found files
if [[ -s "$TEMP_FILE" ]]; then
    echo "Citrix-related files found in targeted directories:"
    cat "$TEMP_FILE"
    echo ""

    while IFS= read -r file; do
        echo "Found: $file"
        prompt_for_deletion "$file"
    done < "$TEMP_FILE"
else
    echo "No Citrix-related files found in targeted directories."
fi

# Step 2: Prompt for full filesystem scan
while true; do
    read -p "Would you like to search the entire filesystem for Citrix-related files? (yes/no): " full_scan
    if [[ -z "$full_scan" ]]; then
        echo "Invalid response. Please type 'yes' or 'no'."
        continue
    fi
    case "$full_scan" in
        [Yy]*)
            echo "Starting full filesystem scan..."
            sudo find / -iname "*citrix*" 2>/dev/null >> "$TEMP_FILE"
            if [[ -s "$TEMP_FILE" ]]; then
                echo "Citrix-related files found in full filesystem scan:"
                cat "$TEMP_FILE"
                echo ""

                while IFS= read -r file; do
                    echo "Found: $file"
                    prompt_for_deletion "$file"
                done < "$TEMP_FILE"
            else
                echo "No additional Citrix-related files found in the full filesystem scan."
            fi
            break
            ;;
        [Nn]*)
            echo "Skipping full filesystem scan."
            break
            ;;
        *)
            echo "Invalid response. Please type 'yes' or 'no'."
            ;;
    esac
done

# Clean up temporary file
rm -f "$TEMP_FILE"
echo "Search and cleanup completed."
