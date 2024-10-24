import re
import os
import sys
import csv
import shutil
import datetime

def time_difference(str1, str2):
    """
    Calculate time difference in milliseconds between two given string in "YYYY-MM-DD HH:MM:SS.SSS" format.

    Args:
        str1: The first time string in the format "YYYY-MM-DD HH:MM:SS.SSS"
        str2: The second time string in the format "YYYY-MM-DD HH:MM:SS.SSS"
    
    Return:
        The time difference in milliseconds
    """
    time1 = datetime.datetime.strptime(str1, "%Y-%m-%d %H:%M:%S.%f")
    time2 = datetime.datetime.strptime(str2, "%Y-%m-%d %H:%M:%S.%f")

    time_diff = (time2 - time1).total_seconds() # Retains the milliseconds
    return int(time_diff * 1000)

def main():
    """
    Main program loop taking in container/file name as only argument.

    Args:
        argv[1]: The name of the logfile before .log and of the varfile before .txt
    """
    if len(sys.argv[1:]) != 1:
        print(f"Usage: python logparse.py <logfile name>")
        sys.exit(1)

    start_time = ""
    end_time = ""
    keystrokes = 0
    commands = 0
    delay = None
    interactive="no"
    with open(f"/home/student/honeypot-group-1a/log/{sys.argv[1]}.log") as logfile:
        pattern = r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3}) - \[Debug\] \[(.*)\] (.*)"
        for line in logfile:
            match = re.search(pattern, line)
            if match:
                time = match.group(1)
                type = match.group(2)
                message = match.group(3)
                if type == "LXC Streams":
                    if "New Stream" in message and start_time == "":
                        if start_time == "":
                            start_time = time
                    elif "Removed Stream" in message and end_time == "":
                        if end_time == "":
                            end_time = time
                if type == "SHELL":
                    if start_time != "" and end_time == "":
                        if "Attacker Keystroke" in message:
                            keystrokes += 1
                        if "line from reader" in message:
                            commands += 1
                if type == "EXEC":
                    if start_time != "":
                        if "Noninteractive" in message:
                            interactive="yes"

    current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
    with open(f"/home/student/honeypot-group-1a/var/{sys.argv[1]}.txt") as varfile:
        next(varfile)
        delay = int(varfile.readline())
        attacker_ip = varfile.readline().strip()
    if interactive == "no":
        if start_time != "" and end_time != "":
            row = [sys.argv[1], delay, time_difference(start_time, end_time), commands, keystrokes, attacker_ip, current_time]
        else:
            row = [sys.argv[1], delay, None, commands, keystrokes, attacker_ip, current_time]
    else:
        row = [sys.argv[1], delay, None, commands, keystrokes, attacker_ip, current_time]
    if os.path.isfile(f"/home/student/honeypot-group-1a/dat/data.csv"):
        with open(f"/home/student/honeypot-group-1a/dat/data.csv", 'a', newline='') as data:
            writer = csv.writer(data)
            writer.writerow(row)
    else:
        with open(f"/home/student/honeypot-group-1a/dat/data.csv", 'w', newline='') as data:
            writer = csv.writer(data)
            fields = ["container", "delay", "duration", "num commands", "num keystrokes", "attacker_ip", "time of log"]
            writer.writerow(fields)
            writer.writerow(row)
    shutil.move(f"/home/student/honeypot-group-1a/log/{sys.argv[1]}.log", f"/home/student/honeypot-group-1a/dat/archive/{sys.argv[1]}-{current_time}.log")



if __name__ == "__main__":
    main()