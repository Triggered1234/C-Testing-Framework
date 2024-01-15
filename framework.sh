#!/bin/bash
SECONDS=0
# Set the paths
COMPILATION_FAILED_INDEX=0
CHECK_INDEX=0
CHECK_FAILED_INDEX=0
CHECK_TODO_INDEX=0
CHECK_TODO_STRING=""
FILE_INDEX=0
COMPILATION_FAILED_STRING=""
SOURCE_FOLDER="$1"
OUTPUT_FOLDER="Output"
CHECK_FOLDER="checks"
LOG_FILE="frameworklogs.txt"
PATH="$PATH:C:\MinGW\bin"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
> "$LOG_FILE"
# Create Output folder if it doesn't exist
mkdir -p "$OUTPUT_FOLDER"
echo "------------------->Running C Testing framework<-------------------"

# Function to compile C programs
compile_program() {
    echo -e "${NC}----------------------------------------------------------------------------------------"
    local source_file="$1"
    local relative_path="${source_file#$SOURCE_FOLDER/}"
    local output_file="$OUTPUT_FOLDER/$(basename "$source_file" .c)"
    echo "Trying to compile $relative_path..."
    # Compile C program and redirect stderr to a temporary file
    gcc "$source_file" -o "$output_file" 2> >(sed -e "s/^/$(printf ${RED})/" > /tmp/compile_error)

    # Check compilation success
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$relative_path compiled successfully!${NC}"
        ((COMPILATION_INDEX++))
        return 0
    else
        echo -e "${RED}Compilation failed for $relative_path.${NC}"
        cat /tmp/compile_error >&2
        ((COMPILATION_FAILED_INDEX++))
        COMPILATION_FAILED_STRING="$COMPILATION_FAILED_STRING $COMPILATION_FAILED_INDEX. $relative_path\n"
        return 1
    fi
}

# Function to run C programs
run_program() {
    local source_file="$1"
    local relative_path="${source_file#$SOURCE_FOLDER/}"
    local output_file="$OUTPUT_FOLDER/$(basename "$source_file" .c)"
    echo "Executing $relative_path..."
    # Run the compiled program
    "$output_file"

    # Check exit code
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}$relative_path executed successfully.${NC}"
        return 0
    else
        echo -e "${RED}Program execution failed with exit code $exit_code.${NC}"
        return 1
    fi
}

# Function to compare output with check file
compare_output() {
    local source_file="$1"
    local relative_path="${source_file#$SOURCE_FOLDER/}"
    local output_file="$OUTPUT_FOLDER/$(basename "$source_file" .c)"
    echo "Running checks on $relative_path"
    local check_file="$CHECK_FOLDER/$(basename "$source_file" .c).check"
    if [ -e "$check_file" ]; then
        ((CHECK_INDEX++))
        diff_output=$(diff <("$output_file") "$check_file")
        if [ -z "$diff_output" ]; then
            echo -e "${GREEN}$relative_path output matches the check file."
            return 0
        else
            ((CHECK_FAILED_INDEX++))
            CHECK_FAILED_STRING="$CHECK_FAILED_STRING $CHECK_FAILED_INDEX. $relative_path\n"
            echo -e "${RED}Test FAILED at $relative_path:"
            echo "Actual output:"
            "$output_file"
            echo "Expected output:"
            cat "$check_file"
            return 1
        fi
    else
        ((CHECK_TODO_INDEX++))
        CHECK_TODO_STRING="$CHECK_TODO_STRING $CHECK_TODO_INDEX. $relative_path\n"
        echo "No check file found for $relative_path."
        return 1
    fi
}

exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)

# Find C source files in the source folder and its subfolders
while IFS= read -r -d $'\0' source_file; do
    ((FILE_INDEX++))
    compile_program "$source_file" && run_program "$source_file" && compare_output "$source_file"
done < <(find "$SOURCE_FOLDER" -name "*.c" -type f -print0)

duration=$SECONDS

echo -e "${NC}----------------------------------------------------------------------------------------"

if [[ COMPILATION_INDEX -eq 0 ]]; then
    echo -e "${GREEN}All $FILE_INDEX files compiled successfully"
else
    echo -e "${RED}The following $COMPILATION_FAILED_INDEX out of $FILE_INDEX files FAILED at compilation:\n$COMPILATION_FAILED_STRING"
fi

echo -e "${NC}----------------------------------------------------------------------------------------"

if [[ CHECK_FAILED_INDEX -eq 0 ]]; then
    echo -e "${GREEN}All $CHECK_INDEX checks had the expected results."
    echo -e "${NC}----------------------------------------------------------------------------------------"
else
    echo -e "${RED}The following $CHECK_FAILED_INDEX out of $CHECK_INDEX checks FAILED.\n$CHECK_FAILED_STRING"
    echo -e "${NC}----------------------------------------------------------------------------------------"
fi

if [[ CHECK_TODO_INDEX -gt 0 ]]; then
    echo -e "${YELLOW}The following $CHECK_TODO_INDEX files have no corresponding check files:\n$CHECK_TODO_STRING"
    echo -e "${NC}----------------------------------------------------------------------------------------"
fi

echo -e "${NC}Script took $((duration / 60)) minutes and $((duration % 60)) seconds to run."
