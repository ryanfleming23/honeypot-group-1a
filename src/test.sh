#!/bin/bash

MITM_PATH="/home/student/MITM/mitm.js"
LOG_PATH="/home/student/honeypot-group-1a/log/"
VAR_PATH="/home/student/honeypot-group-1a/var/"

MAX_MIN=30
IDLE_MIN=4

name="c2"

if grep -q "Attacker authenticated and is inside container" "$LOG_PATH""$name".log; then
    if grep -q "Attacker closed connection" "$LOG_PATH""$name".log; then
        echo "closed: DELETE"
    fi
    if (( $(date +%s) - $(stat -c %Y "$LOG_PATH$name.log") > IDLE_MIN * 60 )); then
        echo "idle: DELETE"
    fi
fi
if (( $(date +%s) - $(head -n 1 "$VAR_PATH$name.txt") > MAX_MIN * 60 )); then
    echo "max time: DELETE"
fi
echo "KEEP RUNNING"