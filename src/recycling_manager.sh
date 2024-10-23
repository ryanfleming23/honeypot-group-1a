#!/bin/bash

# Check if the recycling script is already running
if pgrep -f "recycle.sh"; then
    echo "Recycling script is already running. Waiting for it to finish..."
else
    echo "No recycling process detected. Starting the recycling process..."
    /home/student/honeypot-group-1a/src/recycle.sh
fi