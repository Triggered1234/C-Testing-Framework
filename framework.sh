#!/bin/bash
# Set the paths
LOG_FILE="frameworklogs.txt"
PATH="$PATH:C:\MinGW\bin"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
SOURCE_FOLDER=""
CHECK_FOLDER=""
OUTPUT_FOLDER="Output"

if [[ $1 == "--help" ]]; then
    echo -e "${YELLOW}Syntax: ./framework.sh <source_folder> <checks_folder> <output_folder>"
    echo -e "${YELLOW}The first 2 arguments are mandatory and the third one is optional."
    echo -e "${YELLOW}If no output_folder is given, then it will be automatically created as Output."
    echo -e "${YELLOW}If the output_folder given doesn't exist, then an output_folder will be created with the given name."
    exit
fi

if [[ $# -le 1 ]]; then
    echo -e "${RED}Not enough arguments given! Minimum number of arguments: 2 -->\n
    1: Path to source directory with .c files\n
    2: Path to Tests directory with .check files"
    exit
fi

if [[ $# -eq 2 ]]; then
    SOURCE_FOLDER=$1
    CHECK_FOLDER=$2
    mkdir -p "$OUTPUT_FOLDER"
    if [[ ! -d $2 ]]; then
        echo "No such path to a directory: $2"
        exit
    fi
fi

if [[ $# -eq 3 ]]; then
    SOURCE_FOLDER=$1
    CHECK_FOLDER=$2
    OUTPUT_FOLDER=$3
    if [[ ! -d $2 ]]; then
        echo "No such path to a directory: $2"
        exit
    fi
    if [[ ! -d $3 ]]; then
        mkdir -p "$OUTPUT_FOLDER"
    fi
fi

if [[ $# -gt 3 ]]; then
    echo -e "${RED}Too many arguments given! Maximum number of arguments: 3"
    exit
fi

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
