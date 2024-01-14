#!/bin/bash
# Set the paths
SOURCE_FOLDER=$1
OUTPUT_FOLDER="Output"
CHECK_FOLDER="checks"
LOG_FILE="frameworklogs.txt"
PATH="$PATH:C:\MinGW\bin"
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
# Create Output folder if it doesn't exist
mkdir -p "$OUTPUT_FOLDER"
echo "Running C Testing framework"
# Function to compile C programs
compile_program() {
    echo -e "${NC}--------------------------------------------"
    local source_file="$1"
    local output_file="$OUTPUT_FOLDER/$(basename "$source_file" .c)"
    echo "Trying to compile $source_file..."
    # Compile C program and redirect stderr to a temporary file
    gcc "$source_file" -o "$output_file" 2> >(sed -e "s/^/$(printf ${RED})/" > /tmp/compile_error)

    # Check compilation success
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$source_file compiled successfully!${NC}"
        return 0
    else
        echo -e "${RED}Compilation failed for $source_file.${NC}"
        cat /tmp/compile_error >&2
        return 1
    fi
}

# Function to run C programs
run_program() {
    local source_file="$1"
    local output_file="$OUTPUT_FOLDER/$(basename "$source_file" .c)"
    echo "Executing $source_file..."
    # Run the compiled program
    "$output_file"
    
    # Check exit code
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}$source_file executed successfully.${NC}"
        return 0
    else
        echo -e "${RED}Program execution failed with exit code $exit_code.${NC}"
        return 1
    fi
}

# Function to compare output with check file
compare_output() {
    local source_file="$1"
    local output_file="$OUTPUT_FOLDER/$(basename "$source_file" .c)"
    echo "Running checks on $source_file"
    local check_file="$CHECK_FOLDER/$(basename "$source_file" .c).check"
    if [ -e "$check_file" ]; then
        diff_output=$(diff <("$output_file") "$check_file")
        if [ -z "$diff_output" ]; then
            echo "$source_file output matches the check file."
            return 0
        else
            echo -e "${RED}Test FAILED at $source_file:"
            echo "Actual output:"
            "$output_file"
            echo "Expected output:"
            cat "$check_file"
            return 1
        fi
    else
        echo "No check file found for $source_file."
        return 1
    fi
}

exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)

# Find C source files in the source folder
find "$SOURCE_FOLDER" -name "*.c" -print0 | while IFS= read -r -d $'\0' source_file; do
    compile_program "$source_file" && run_program "$source_file" && compare_output "$source_file"
done
