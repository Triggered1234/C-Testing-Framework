#!/bin/bash

#---------- GLOBALS ----------

SECONDS=0
COMPILATION_FAILED_INDEX=0
CHECK_INDEX=0
CHECK_FAILED_INDEX=0
CHECK_TODO_INDEX=0
CHECK_TODO_STRING=""
FILE_INDEX=0
COMPILATION_FAILED_STRING=""
LOG_FILE="frameworklogs.txt"
PATH="$PATH:C:\MinGW\bin"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
SOURCE_FOLDER=""
CHECK_FOLDER=""
OUTPUT_FOLDER="Output"

#---------- HELP FLAG ----------

if [[ $1 == "--help" ]]; then
    echo -e "${YELLOW}Syntax: ./framework.sh <source_folder> <checks_folder> <output_folder>"
    echo -e "${YELLOW}The first 2 arguments are mandatory and the third one is optional."
    echo -e "${YELLOW}If no output_folder is given, then it will be automatically created as Output."
    echo -e "${YELLOW}If the output_folder given doesn't exist, then an output_folder will be created with the given name."
    exit
fi

#---------- ARGUMENTS VALIDATION ----------

if [[ $# -le 1 ]]; then
    echo -e "${RED}Not enough arguments given! Minimum number of arguments: 2 -->\n
    1: Path to source directory with .c files\n
    2: Path to Tests directory with .check files"
    exit
fi

#---------- ARGUMENTS VALIDATION ----------

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

> "$LOG_FILE"

echo "------------------->Running C Testing framework<-------------------"

# COMPILATION FUNCTION
# 1. Receives source files and their paths.
# 2. Tries compiling them.
# 3. If successful, displays success message and increments success index, creates output file, returns.
# 4. If failed, displays failed message, increments failed index, returns.
# --------------------------------------------------------------------------------

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

# RUNNING FUNCTION
# 1. Receives source files and their paths.
# 2. Tries executing them
# 3. If successful displays success message, returns.
# 4. If failed, displays error message, returns.
# --------------------------------------------------------------------------------

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

# RUNNING FUNCTION
# 1. Receives source files, check files and their paths.
# 2. Compares source files output to expected output from check files
# 3. If successful displays success message, increments check success index, returns.
# 4. If failed, displays error message, increments check failed index, returns.
# 5. If no checks are found, displays warning message, increments checks todo index, returns.
# ---------------------------------------------------------------------------------------

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

while IFS= read -r -d $'\0' source_file; do
    ((FILE_INDEX++))
    compile_program "$source_file" && run_program "$source_file" && compare_output "$source_file"
done < <(find "$SOURCE_FOLDER" -name "*.c" -type f -print0)

duration=$SECONDS

#----------------------------------------------Logging----------------------------------------------

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
