#!/bin/bash

# Script to modify a value in a Fortran NAMELIST file
# Usage: ./modify_namelist.sh <namelist_file> <namelist_name> <key> <new_value> <dst>

# Check for required arguments
if [ "$#" -lt 4 ]; then
    echo "Only get $# arguments"
    echo "Usage: $0 <namelist_file> <namelist_name> <key> <new_value> [dst]"
    exit 1
fi

NAMELIST_FILE=$1
NAMELIST_NAME=$2
KEY=$3
NEW_VALUE=$4
if [ "$#" -eq 5 ]; then
    DST=$5
    if [ "$DST" == "inplace" ]; then
        DST=$NAMELIST_FILE
    fi
else
    DST="${NAMELIST_FILE}_updated"
fi

# Ensure the file exists
if [ ! -f "$NAMELIST_FILE" ]; then
    echo "Error: File $NAMELIST_FILE not found."
    exit 1
fi

# Create a temporary file to store the modified content
TEMP_FILE=$(mktemp)

# Use awk to process the NAMELIST and update the key value
awk -v namelist="&$NAMELIST_NAME" \
    -v key="$KEY" \
    -v new_value="$NEW_VALUE" \
    'BEGIN {inside_namelist = 0} \
    {
        if ($0 ~ "^" namelist) {
            inside_namelist = 1
        }
        if (inside_namelist && $0 ~ key "[ \t]*=") {
            if (new_value ~ /^[+-]/) {
                match($0, key "[ \t]*=[ \t]*([^,]*)", m)
                original_value = m[1] + 0  # Convert to numeric
                adjustment = new_value + 0 # Convert to numeric
                updated_value = original_value + adjustment
                sub(key "[ \t]*=[ \t]*[^,]*", key "=" updated_value)
            } else {
                sub(key "[ \t]*=[ \t]*[^,]*", key "=" new_value)
            }
        }
        if (inside_namelist && $0 ~ "/") {
            inside_namelist = 0
        }
        print $0
    }' "$NAMELIST_FILE" > "$TEMP_FILE"

# Replace the original file with the modified content
diff --color "$NAMELIST_FILE" "$TEMP_FILE" 2>&1 && true || true
mv "$TEMP_FILE" $DST
echo "Updated $KEY in $NAMELIST_NAME to $NEW_VALUE."
exit