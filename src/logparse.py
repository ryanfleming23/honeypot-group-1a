import re
import os
import sys
import csv
import shutil
import datetime
import pandas as pd

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

def get_time(archive_name):
    pattern = r"DESKTOP-[1-9]AJRJA-(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3,6})\.log"
    match = re.search(pattern, archive_name)
    return match.group(1)

def get_delay(archive_name):
    df = pd.read_csv("/home/student/honeypot-group-1a/dat/full.csv")

    delay_value = df.loc[df['time of log'] == get_time(archive_name), 'delay']

    if not delay_value.empty:
        return delay_value.iloc[0]
    return None

def process_logfile(filename):
    start_time = ""
    end_time = ""
    attacker_ip = ""
    name = ""
    password=""
    keystrokes = 0
    commands = 0
    login_count = 0
    duration = 0
    interactive=False
    with open(filename) as log:
        pattern = r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3}) - \[Debug\] \[(.*)\] (.*)"
        for line in log:
            if "containerName" in line:
                name_pattern = r"containerName: \'(.*)\',"
                name_match = re.search(name_pattern, line)
                name = name_match.group(1)
            match = re.search(pattern, line)
            if match:
                time = match.group(1)
                type = match.group(2)
                message = match.group(3)
                if type == "Connection":
                    if "Attacker connected" in message:
                        login_count += 1
                        if start_time == "":
                            login_pattern = r"Attacker connected: ((\d{1,3}\.){3}\d{1,3})"
                            login_match = re.search(login_pattern, message)
                            if login_match:
                                attacker_ip = login_match.group(1)
                            start_time = time
                    elif ("Attacker closed the connection" in message or "Attacker closed connection" in message)and end_time == "":
                        if end_time == "":
                            end_time = time
                if type == "SHELL":
                    if start_time != "" and end_time == "":
                        if "Attacker Keystroke" in message:
                            keystrokes += 1
                        if "line from reader" in message:
                            interactive=True
                            commands += 1
                            end_time = time
                if type == "EXEC":
                    if "Noninteractive" in message and end_time == "":
                        commands += 1
                        end_time=time
                if type == "Auto Access":
                    password_pattern = r"Adding the following credentials: \'(.*)\'"
                    password_match = re.search(password_pattern, message)
                    if password_match and password == "":
                        password = password_match.group(1)
        if start_time != "" and end_time != "":
            duration = time_difference(start_time, end_time)
    return attacker_ip, name, password, keystrokes, commands, login_count, duration, interactive

def write_row(row, name):
    if os.path.isfile(f"/home/student/honeypot-group-1a/dat/{name}.csv"):
        with open(f"/home/student/honeypot-group-1a/dat/{name}.csv", 'a', newline='') as data:
            writer = csv.writer(data)
            writer.writerow(row)
    else:
        with open(f"/home/student/honeypot-group-1a/dat/{name}.csv", 'w', newline='') as data:
            writer = csv.writer(data)
            fields = ["name", "interactive", "login count", "duration", "attacker ip", "login", "command count", "keystroke count", "delay", "time of log"]
            writer.writerow(fields)
            writer.writerow(row)


def process_new():
    """
    Main program loop taking in container/file name as only argument.

    Args:
        argv[1]: The name of the logfile before .log and of the varfile before .txt
    """
    attacker_ip, name, password, keystrokes, commands, login_count, duration, interactive = process_logfile(f"/home/student/honeypot-group-1a/log/{sys.argv[1]}.log")

    time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
    with open(f"/home/student/honeypot-group-1a/var/{sys.argv[1]}.txt") as varfile:
        next(varfile)
        delay = int(varfile.readline())

    row = [name, interactive, login_count, duration, attacker_ip, password, commands, keystrokes, delay, time]

    write_row(row, "full")
    shutil.move(f"/home/student/honeypot-group-1a/log/{sys.argv[1]}.log", f"/home/student/honeypot-group-1a/dat/archive/{sys.argv[1]}-{time}.log")

def process_all():
    dat_directory = "/home/student/honeypot-group-1a/dat/archive"

    for filename in os.listdir(dat_directory):
        file_path = os.path.join(dat_directory, filename)

        attacker_ip, name, password, keystrokes, commands, login_count, duration, interactive = process_logfile(file_path)

        delay = get_delay(filename)
        time = get_time(filename)

        row = [name, interactive, login_count, duration, attacker_ip, password, commands, keystrokes, delay, time]

        write_row(row, "full2")


if __name__ == "__main__":
    if len(sys.argv) == 2:
        process_new()
    else:
        process_all()