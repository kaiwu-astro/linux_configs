#!/bin/bash

# Script to modify a value in a Fortran NAMELIST file
# Usage: ./modify_namelist.sh <namelist_file> <key> <new_value> [dst]

# Check for required arguments
if [ "$#" -lt 3 ]; then
    echo "Only get $# arguments"
    echo "Usage: $0 <namelist_file> <key> <new_value> [dst]"
    echo "Example: $0 N1m.inp N 20000 inplace"
    exit 1
fi

NAMELIST_FILE=$1
KEY=$2
NEW_VALUE=$3
if [ "$#" -eq 4 ]; then
    DST=$4
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

# Use awk to process the file and update the key value globally
awk -v key="$KEY" \
    -v new_value="$NEW_VALUE" \
    '{
        # Skip comment lines that start with whitespace followed by exclamation mark
        if ($0 ~ /^[ \t]*!/) {
            # skip
        } else if ($0 ~ "(^|,[ \t]*)"key"[ \t]*=") {
            if (new_value ~ /^[+-]/) {
                # More portable extraction of value that works in both mawk and GNU awk
                gsub(/^.*=[ \t]*/, "", $0)  # Remove everything up to and including =
                gsub(/[ \t]*,.*$/, "", $0)  # Remove trailing comma and anything after
                original_value = $0 + 0  # Convert to numeric
                adjustment = new_value + 0 # Convert to numeric
                updated_value = original_value + adjustment
                sub(key "[ \t]*=[ \t]*[^,]*", key "=" updated_value)
            } else {
                sub(key "[ \t]*=[ \t]*[^,]*", key "=" new_value)
            }
        }
        print $0
    }' "$NAMELIST_FILE" > "$TEMP_FILE"

# Replace the original file with the modified content
diff --color "$NAMELIST_FILE" "$TEMP_FILE" 2>&1 && true || true
mv "$TEMP_FILE" $DST
echo "Updated $KEY to $NEW_VALUE."
exit