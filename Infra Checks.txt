#!/bin/bash

##INFRA CHECKS

# Define output file
OUTPUT_FILE="infra_check_output.txt"

# Check Hostname
echo "Hostname:" > $OUTPUT_FILE
hostname >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Check OS version
echo "OS Version:" >> $OUTPUT_FILE
lsb_release -a >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Check CPU information
echo "CPU Information:" >> $OUTPUT_FILE
lscpu | grep -E 'Model name|Socket|Core|Thread|Architecture' >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Check RAM information
echo "RAM Information:" >> $OUTPUT_FILE
free -h >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Check Storage Information
echo "Storage Information:" >> $OUTPUT_FILE
lsblk >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Notify user of completion
echo "Infrastructure check completed. Output saved to $OUTPUT_FILE."

cat infra_check_output.txt