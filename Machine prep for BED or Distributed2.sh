#!/bin/bash

# Source the configuration file
source ./config.sh

# Report file
REPORT_FILE="report.txt"

# Function to log messages
log() {
    echo "$1" | tee -a "$REPORT_FILE"
}

# Function to display a progress bar
progress_bar() {
    local duration=$1
    local interval=0.1
    local total=$(echo "$duration / $interval" | bc)

    echo -n "["
    for ((i=0; i<total; i++)); do
        echo -n "="
        sleep $interval
    done
    echo "]"
}

# Check if the user already exists
if id "$USERNAME" &>/dev/null; then
    log "User $USERNAME already exists."
    echo "Would you like to reset the password? (yes/no)"
    read RESET_PASSWORD

    if [[ "$RESET_PASSWORD" == "yes" ]]; then
        log "Resetting password for user $USERNAME."
        echo "Please enter a new password for the user $USERNAME:"
        sudo passwd "$USERNAME"
        log "Password for user $USERNAME has been reset."
    fi
else
    # Create the user with a home directory and set the default shell
    sudo useradd -m "$USERNAME"
    #log "1. User $USERNAME has been created."

    # Set the password for the new user
    echo "Please enter a password for the user $USERNAME:"
    sudo passwd "$USERNAME"
    
    # Add the user to the sudo group
    sudo usermod -aG sudo "$USERNAME"

    # Safely add user to sudoers file using visudo
    echo "$USERNAME ALL=(ALL) ALL" | sudo EDITOR='tee -a' visudo

    log "User $USERNAME has been created successfully and granted sudo privileges."
fi

# Switch to the new user and install packages with progress indication
#log "Switching to user $USERNAME..."
#log "Installing packages..."
{
    # Start the progress bar in the background
    ( progress_bar 10 ) &

    # Capture the PID of the background progress bar process
    PB_PID=$!

    # Install packages and redirect output to /dev/null to avoid cluttering terminal
    sudo -S apt-get update -y > /dev/null && \
    sudo -S apt-get install -y "${PACKAGES[@]}" > /dev/null

    # Kill the progress bar when installation is complete
    kill $PB_PID 2>/dev/null

} &

wait  # Wait for all background processes to complete
printf "Done!\n"
log "Packages have been installed."

# Loop through each package and check if it is installed
for PACKAGE in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $PACKAGE "; then
        log "	$PACKAGE has been installed."
    else
        log "	$PACKAGE is not installed."
    fi
done

# Ask whether deploying a BED before checking mounting status
read -p "Are you deploying a BED? (yes/no): " DEPLOY_BED

if [[ "$DEPLOY_BED" == "yes" ]]; then
    read -p "Have you done the mounting? (yes/no): " MOUNTING_DONE

    if [[ "$MOUNTING_DONE" == "yes" ]]; then
        mkdir -p "$DATA_DISK_DIR/arcgisserver/logs"
        mkdir -p "$DATA_DISK_DIR/arcgisserver/config-store"
        mkdir -p "$DATA_DISK_DIR/arcgisdatastore/data"
        mkdir -p "$DATA_DISK_DIR/arcgisdatastore/backups/tilecache"
        mkdir -p "$DATA_DISK_DIR/arcgisdatastore/backups/relational"
        mkdir -p "$DATA_DISK_DIR/arcgisportal/logs"
        mkdir -p "$DATA_DISK_DIR/arcgisportal/content"

        sudo chown -R "$USERNAME:$USERNAME" "$DATA_DISK_DIR"

        log "Directory structure created under $DATA_DISK_DIR and ownership assigned to $USERNAME."
    else
       log "Skipping directory creation as mounting has not been done."
    fi

else 
   #log "Not deploying a BED. Please choose an option:"
   echo "Enter 1 for Portal, Enter 2 for Server, Enter 3 for Datastore, or Enter 4 for Web Adaptor:"
   read OPTION

   case $OPTION in 
       1)
           read -p "Have you done the mounting? (yes/no): " MOUNTING_DONE_PORTAL 
           if [[ "$MOUNTING_DONE_PORTAL" == "yes" ]]; then 
               mkdir -p "$DATA_DISK_DIR/arcgisportal/logs"
               mkdir -p "$DATA_DISK_DIR/arcgisportal/content"
               sudo chown -R "$USERNAME:$USERNAME" "$DATA_DISK_DIR/arcgisportal"
               log "Portal directories created and ownership assigned to $USERNAME." 
           else 
               log "Skipping Portal directory creation as mounting has not been done." 
           fi 
           ;;
       2) 
           read -p "Have you done the mounting? (yes/no): " MOUNTING_DONE_SERVER 
           if [[ "$MOUNTING_DONE_SERVER" == "yes" ]]; then 
               mkdir -p "$DATA_DISK_DIR/arcgisserver/logs"
               mkdir -p "$DATA_DISK_DIR/arcgisserver/config-store"
               sudo chown -R "$USERNAME:$USERNAME" "$DATA_DISK_DIR/arcgisserver"
               log "Server directories created and ownership assigned to $USERNAME." 
           else 
               log "Skipping Server directory creation as mounting has not been done." 
           fi 
           ;;
       3) 
           read -p "Have you done the mounting? (yes/no): " MOUNTING_DONE_DATASTORE 
           if [[ "$MOUNTING_DONE_DATASTORE" == "yes" ]]; then 
               mkdir -p "$DATA_DISK_DIR/arcgisdatastore/data"
               mkdir -p "$DATA_DISK_DIR/arcgisdatastore/backups/tilecache"
               mkdir -p "$DATA_DISK_DIR/arcgisdatastore/backups/relational"
               sudo chown -R "$USERNAME:$USERNAME" "$DATA_DISK_DIR/arcgisdatastore"
               log "Datastore directories created and ownership assigned to $USERNAME." 
           else 
               log "Skipping Datastore directory creation as mounting has not been done." 
           fi 
           ;;
       4) 
           log "No directories will be created for Web Adaptor."
           ;;
       *) 
           log "Invalid option selected. No directories created." 
           exit 1 
           ;; 
   esac 
fi 

# Install cinc-client version from config file and extract ArcGIS cookbooks version from config file.
log "Installed cinc-client $CINC_VERSION..."
curl -L https://omnitruck.cinc.sh/install.sh | sudo bash -s -- -v $CINC_VERSION 

log "Downloaded ArcGIS cookbooks version $ARCGIS_COOKBOOK_VERSION"
wget https://github.com/Esri/arcgis-cookbook/releases/download/v$ARCGIS_COOKBOOK_VERSION/arcgis-$ARCGIS_COOKBOOK_VERSION-cookbooks.tar.gz 

# Extracting ArcGIS cookbooks
log "Extracting ArcGIS cookbooks to /opt/cinc"
sudo mkdir -p /opt/cinc/
sudo tar -xvf arcgis-$ARCGIS_COOKBOOK_VERSION-cookbooks.tar.gz -C /opt/cinc/

# Change ownership of the /opt/cinc/ directory to the new user with full control.
sudo chown -R "$USERNAME:$USERNAME" /opt/cinc/
#log "/opt/cinc/ directory has been assigned full control to $USERNAME."

# Print version of cinc-client installed.
#log "Checking cinc-client version..."
cinc-client -v 

log "Installation and setup completed successfully."
