#!/bin/bash

# Function to log actions
log_action() {
    local message=$1
    echo "$(date): $message" >> /var/log/user_management.log
}

# Check if the input file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <name-of-text-file>"
    exit 1
fi

INPUT_FILE=$1

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "File $INPUT_FILE not found!"
    exit 1
fi

# Create directories for logs and secure storage if they don't exist
mkdir -p /var/log /var/secure

# Ensure only root can read/write to the secure password file
touch /var/secure/user_passwords.txt
chmod 600 /var/secure/user_passwords.txt

# Process each line in the input file
while IFS=';' read -r username groups; do
    username=$(echo "$username" | xargs) # Trim whitespace

    # Create personal group for the user
    if ! getent group "$username" > /dev/null; then
        groupadd "$username"
        log_action "Group $username created."
    else
        log_action "Group $username already exists."
    fi

    # Create user with a personal group
    if ! id "$username" > /dev/null 2>&1; then
        useradd -m -g "$username" -s /bin/bash "$username"
        log_action "User $username created."
    else
        log_action "User $username already exists."
    fi

    # Assign the user to the specified groups
    IFS=',' read -r -a group_array <<< "$(echo "$groups" | xargs)"
    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs) # Trim whitespace
        if ! getent group "$group" > /dev/null; then
            groupadd "$group"
            log_action "Group $group created."
        fi
        usermod -aG "$group" "$username"
        log_action "User $username added to group $group."
    done

    # Generate a random password for the user
    password=$(openssl rand -base64 12)
    echo "$username:$password" | chpasswd
    log_action "Password for user $username set."

    # Store the password securely
    echo "$username,$password" >> /var/secure/user_passwords.txt

done < "$INPUT_FILE"

echo "User and group creation process completed."
