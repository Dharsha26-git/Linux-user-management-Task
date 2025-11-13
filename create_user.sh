#!/bin/bash

INPUT_FILE="users.txt"

LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/user_management.log"
PASSWORD_FILE="$LOG_DIR/user_passwords.txt"

mkdir -p "$LOG_DIR"

# Create log + password file
touch "$LOG_FILE" "$PASSWORD_FILE"
chmod 600 "$LOG_FILE" "$PASSWORD_FILE"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}


if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with sudo"
    exit 1
fi

log "----- Starting User Creation Process -----"

while IFS= read -r line; do

   
    line=$(echo "$line" | tr -d '\r' | tr -d '\t')

    # Skip empty lines or comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Remove all spaces safely
    clean=$(echo "$line" | sed 's/[[:space:]]//g')

    
    username=$(echo "$clean" | cut -d ';' -f 1)
    groups=$(echo "$clean" | cut -d ';' -f 2)

    log "Processing user: $username"

    
    IFS=',' read -ra GROUP_LIST <<< "$groups"

    for grp in "${GROUP_LIST[@]}"; do

        
        [[ -z "$grp" ]] && continue

        # Create group if missing
        if ! getent group "$grp" >/dev/null 2>&1; then
            groupadd "$grp"
            log "Created group: $grp"
        else
            log "Group exists: $grp"
        fi

    done

    # Create user
    if id "$username" >/dev/null 2>&1; then
        log "User $username already exists."
    else
        useradd -m -s /bin/bash -G "$groups" "$username"
        log "Created user: $username"
    fi

    
    if [ -d "/home/$username" ]; then
        chown "$username:$username" "/home/$username" 2>/dev/null
    fi

    # Generate password
    password=$(openssl rand -base64 12)
    echo "$username:$password" | chpasswd 2>/dev/null

    # Save password
    echo "$username : $password" >> "$PASSWORD_FILE"
    log "Password set for $username"

done < "$INPUT_FILE"

log "----- User Creation Process Completed -----"

echo "Done! Check logs in: $LOG_FILE"
