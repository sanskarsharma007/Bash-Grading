#!/bin/bash
#This is the variable that stores repository's path
repo_file=".git_repo"
combine(){
    # Remove existing main.csv file if it exists
    rm -f main.csv

    # Get a list of all CSV files in the directory
    csv_files=$(ls *.csv)

    # Initialize a temporary directory for storing sorted data
    temp_dir=$(mktemp -d)

    # Initialize arrays to store student IDs and names
    declare -A students

    # Iterate over each CSV file
    for file in $csv_files; do
        # Extract the exam name from the file name
        exam=$(echo "$file" | cut -d'.' -f1)
        
        # Read the data from the CSV file and store it in the 'students' array
        awk -F',' -v exam="$exam" 'NR>1 {if (!($1 in students)) {students[$1]=$2}; students[$1]=students[$1] "," $3} END {for (student in students) {print student "," students[student]}}' "$file" | sort -t',' -k1 > "$temp_dir/$exam.tmp"
    done

    # Merge the data from all exams
    awk -F',' 'BEGIN { OFS = "," } {print $0}' "$temp_dir/midsem.tmp" > "$temp_dir/main.tmp"
    for exam in $csv_files; do
        exam=$(echo "$exam" | cut -d'.' -f1)
        # Perform the join operation and fill missing scores with a placeholder value "-"
        #-t sepcifies field seperator -a 1 includes unmatched lines from the first file, and -a 2 includes unmatched lines from the second file.
        #-e 'a': Specifies the string to replace missing fields with.
        #o auto: Automatically determines the fields to output.
        #-1 1 -2 1: Specifies that the first field of the first file (-1 1) and the first field of the second file (-2 1) are the fields to join on.
        join -t',' -a 1 -a 2 -e 'a' -o auto -1 1 -2 1 <(sort -t',' -k1 "$temp_dir/main.tmp") <(sort -t',' -k1 "$temp_dir/$exam.tmp") > "$temp_dir/main_tmp.tmp"
        #-k1 means sort based on first field 
        mv "$temp_dir/main_tmp.tmp" "$temp_dir/main.tmp"
    done

    # Write the combined data to main.csv
    header="Roll_Number,Name"
    for exam in $csv_files; do
        exam=$(echo "$exam" | cut -d'.' -f1)
        #header will contain Roll_Number,Name,Exam_Name
        header="$header,$exam"
    done
    echo "$header" > main.csv

    # Print the combined data, handling missing entries with "a"
    awk -F',' 'BEGIN { OFS = "," } {
        count_ = 2 
        # to ensure student name
        while ($count_ == "a" && count_ <= NF) {
            count_ += 2
        }
        # $5 is marks in first exam 
        printf "%s,%s,%s", $1, $count_, $5
        # now all the marks are after 2 steps
        count = 7
        while (count <= NF) {
            printf "%s%s", OFS, $count
            count += 2
        }
        print ""  # Add newline after printing all fields
    }' "$temp_dir/main.tmp" | sed 's/,,/,a,/' >> main.csv
    
    # Remove temporary directory
    rm -r $temp_dir
}

# Function to upload a new CSV file
upload() {
    # Copy the provided CSV file into the script's directory
    cp "$1" .
    echo "File uploaded successfully."
}

# Function to add a new column "total" with the sum of marks for each student
total() {
    # first combine before total
    combine
    # Add a new column "total" to main.csv
    awk -F',' 'BEGIN { OFS = "," } NR==1{ print $0 ",total"} NR>1 {
        total = 0
        for (i=3; i<=NF; i++) {
            # only add if marks are integer 
            if ($i != "a") {
                total += $i
            }
        }
        print $0,total
    }' main.csv > main_with_total.csv
    # moving all the content to the main file
    mv main_with_total.csv main.csv
    echo "Total column added successfully."
}

# Function to initialize git repository
git_init() {
    # Same name directory already exists
    if [ -d "$1" ]; then
        echo "Error: Remote directory is already initialized as a Git repository."
        exit 1
    fi
    # -p creats all necessary directory
    mkdir -p "$1"
    # repo file now contains path of the directory
    echo "$1" > "$repo_file"
    echo "Git repository initialized successfully at $1."
}

git_commit() {
    # Check if the repository has been initialized
    if [ ! -f "$repo_file" ]; then
        echo "Error: Git repository not initialized. Please run 'git_init' command first."
        exit 1
    fi

    # Retrieve the remote directory from the repository file
    remote_dir=$(cat "$repo_file")
    
    # Validate remote directory path
    if [ ! -d "$remote_dir" ]; then
        echo "Error: Remote directory '$remote_dir' does not exist."
        exit 1
    fi

    # Create temporary directory for storing snapshot
    snapshot_dir=$(mktemp -d)
    
    # Copy files to temporary directory for snapshot
    cp -r "$remote_dir"/* "$snapshot_dir"
    
    # Generate 16-digit random hash value as commit ID
    commit_id=$(LC_ALL=C tr -dc '0-9' < /dev/urandom | head -c 16)
    commit_folder="$remote_dir/.$commit_id"
    
    # Create hidden folder with commit hash name and copy all files into it
    mkdir "$commit_folder"
    cp -r ./* "$commit_folder"

    # Copy files to remote directory itself
    cp -r ./* "$remote_dir"

    # Create or update .git_log file with commit hash ID and message
    echo "$commit_id : $2" >> "$remote_dir/.git_log"
    echo "Files modified since the last commit:"
    my_diff "$snapshot_dir"  # Compare files before and after commit
    
    # Clean up temporary directory
    rm -rf "$snapshot_dir"
    
}
my_diff() {
    git_dir="$1"

    # Loop through files in the current directory
    for file in *; do
        # Check if file is a regular file
        if [ -f "$file" ]; then
            # Check if the file exists in the git directory
            if [ -f "$git_dir/$file" ]; then
                # Perform a line-by-line comparison of the file contents
                if ! cmp -s "$file" "$git_dir/$file"; then
                    # if comparison fails
                    echo "$file"
                fi
            else
                # file not exist in git directory
                echo "$file"
            fi
        fi
    done
}


# Function to revert to a specific commit in git repository
git_checkout() {
    
    # Check if the repository has been initialized
    if [ ! -f "$repo_file" ]; then
        echo "Error: Git repository not initialized. Please run 'git_init' command first."
        exit 1
    fi

    # Retrieve the remote directory from the repository file
    # remote_dir -> contains path to git directory
    # pr_working -> path where script ia running
    remote_dir=$(cat "$repo_file")
    pr_working=$(pwd)

    # Get the argument passed to git_checkout
    if [ "$#" -lt 3 ];then
        # it means hash value is given
        checkout_arg="$2"
    else
        # message is given
        checkout_arg="$3"
    fi
    

    # Check if a commit message or hash value is provided
    if [ -z "$checkout_arg" ]; then
        echo "Error: Commit message or hash value not provided."
        exit 1
    fi

    # Search for commit with provided commit message or hash value
    # -m 1 : stops reading when first match is found
    # -E enables use of extended regular expressions
    if [ "$2" == "-m" ]; then
        found_commit=$(grep -m 1 -E "^[0-9]+ : $checkout_arg" "$remote_dir/.git_log")
    else
        found_commit=$(grep -m 1 -E "^$checkout_arg[0-9a-f]* " "$remote_dir/.git_log")
    fi

    # If the commit message or hash value is not found, exit with an error message
    if [ -z "$found_commit" ]; then
        echo "Error: Commit with message or hash value '$checkout_arg' not found."
        exit 1
    fi

    # Extract commit hash and message from found commit
    commit_hash=$(echo "$found_commit" | cut -d ':' -f 1 | tr -d ' ')
    commit_message=$(echo "$found_commit" | cut -d ':' -f 2-)

    # Check if there are multiple commits with the same prefix of the provided hash value
    num_commits_with_prefix=$(grep -c -E "^$checkout_arg" "$remote_dir/.git_log")
    if [ "$num_commits_with_prefix" -gt 1 ]; then
        echo "Error: Multiple commits found with the same prefix of the provided hash value. Please provide a more specific hash value."
        exit 1
    fi
    # remove all files of current direcory
    rm -r ./*
    #remove all files of git directory
    rm -r "$remote_dir"/*
    # copy all files from hidden folder to git directory
    cp -r "$remote_dir/.$commit_hash"/* "$remote_dir"
    
    # Replace files in original directory with files from hidden folder
    cp -rf "$remote_dir/.$commit_hash"/* "$pr_working"
}


# Function to update marks for a specific student
update() {
    # Prompt user for student details and new marks
    read -p "In which exam do you want to change marks: " exam_
    read -p "Enter Roll Number: " roll_number
    read -p "Enter Name: " name
    read -p "Enter New Marks: " marks

    csv_files=$(ls *.csv)
    found=false
    for file in $csv_files; do
        # Extract the exam name from the file name
        exam=$(echo "$file" | cut -d'.' -f1)
        if [ "$exam" = "$exam_" ]; then
            # Check if roll number exists in the file
            if grep -q "^$roll_number," "$file"; then
                # Update marks in the CSV file
                awk -F',' -v roll_number="$roll_number" -v marks="$marks" '
                    BEGIN { OFS = "," }
                    NR == 1 { print $0 }
                    NR > 1 {
                        if ($1 == roll_number) {
                            print $1, $2, marks
                        } else {
                            print $0
                        }
                    }
                ' "$file" > temp_.csv
                mv temp_.csv "$file"
                # Update marks in main.csv
                last_field=$(awk -F',' 'NR==1 {print $NF}' main.csv)
                if [ "$last_field" = "total" ]; then
                    # Call the total function
                    total
                elif [ "$last_field" = "pass or fail" ];then
                    #call pass_or_fail function
                    pass_or_fail
                else
                    combine
                fi
                found=true
                echo "Marks updated successfully."
                break
            else
                echo "Roll number $roll_number not found in $file."
                echo "Please try again."
                return 1
            fi
        fi
    done

    if ! $found; then
        echo "No CSV file found for exam $exam_"
    fi

}



calculate_statistics() {
    echo "Statistics:"
    # create backup of main.csv
    cp main.csv .backup.csv
    combine
    python3 statistics_script.py main.csv
    cp .backup.csv main.csv
    rm .backup.csv
}

generate_graphs(){
    echo "Generating graphs..."
    cp main.csv .backup.csv
    combine
    python3 graphs_script.py main.csv
    cp .backup.csv main.csv
    rm .backup.csv

}

pass_or_fail(){
    echo "Give me the passing marks"
    read marks
    total
    awk -v marks="$marks" -F',' 'BEGIN { OFS = "," } NR==1{val=NF 
    print $0 ",pass or fail"} NR>1 {
        grade="fail"
        if($val > marks){  
            grade="pass"
        }
        else{
            grade="fail"
        }
        print $0,grade
    }' main.csv > main_with_grade.csv 
    # move this to main.csv
    mv main_with_grade.csv main.csv
}


# Check if command is provided
if [ $# -eq 0 ]; then
    echo "Error: No command provided."
    exit 1
fi

# Execute the appropriate function based on the command
case "$1" in
    combine)
        combine
        ;;
    upload)
        if [ -z "$2" ]; then
            echo "Error: Please provide the file path to upload."
            exit 1
        fi
        upload "$2"
        ;;
    total)
        total
        ;;
    git_init)
        if [ -z "$2" ]; then
            echo "Error: Please provide the path for the remote repository."
            exit 1
        fi
        git_init "$2"
        ;;
    git_commit)
        if [ -z "$2" ]; then
            echo "Error: Please provide the path for the remote repository."
            exit 1
        elif [ -z "$3" ]; then
            echo "Error: Please provide the commit message."
            exit 1
        fi
        git_commit "$2" "$3"
        ;;
    git_checkout)
        if [ -z "$2" ]; then
            echo "Error: Please provide the commit message or hash value to checkout."
            exit 1
        fi
        git_checkout "$@"
        ;;
    update)
        update
        ;;
    statistics)
        calculate_statistics
        ;;
    graphs)
        generate_graphs
        ;;
    pass_or_fail)
        pass_or_fail
        ;;
    *)
        echo "Error: Invalid command."
        exit 1
        ;;
esac

exit 0