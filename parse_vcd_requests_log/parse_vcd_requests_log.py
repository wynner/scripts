import re
import csv
import sys
import os
import glob
from collections import defaultdict
from datetime import datetime

# Regex pattern to match the VCD request log line
log_pattern = re.compile(
    r'^(?P<ip>\d{1,3}(?:\.\d{1,3}){3}) - - \[(?P<timestamp>\d{2}/[A-Za-z]+/\d{4}:\d{2}:\d{2}:\d{2} [+-]\d{4})\] ".*?" (?P<status>\d{3})'
)

# Stats collection structure
stats = defaultdict(lambda: {
    "api_calls": 0,
    "ips": set(),
    "success": 0,
    "fail": 0
})

def parse_log_file(file_path):
    try:
        with open(file_path, "r") as file:
            for line in file:
                match = log_pattern.search(line)
                if not match:
                    continue

                ip = match.group("ip")
                status = int(match.group("status"))
                timestamp_str = match.group("timestamp")

                try:
                    timestamp = datetime.strptime(timestamp_str, "%d/%b/%Y:%H:%M:%S %z")
                except ValueError:
                    continue

                key = (timestamp.date().isoformat(), timestamp.hour)
                stats[key]["api_calls"] += 1
                stats[key]["ips"].add(ip)
                if 200 <= status < 400:
                    stats[key]["success"] += 1
                else:
                    stats[key]["fail"] += 1
    except Exception as e:
        print(f"❌ Failed to read {file_path}: {e}")

def write_csv(output_path):
    with open(output_path, mode="w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow([
            "Date", "Hour", "Number of API Calls",
            "Number of Different IPs",
            "Number of Successful API Calls",
            "Number of Unsuccessful API Calls"
        ])
        for (date, hour), data in sorted(stats.items()):
            writer.writerow([
                date,
                hour,
                data["api_calls"],
                len(data["ips"]),
                data["success"],
                data["fail"]
            ])
    print(f"✅ Report written to: {output_path}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 parse_vcd_requests_log.py <logfile | directory>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_dir = os.getcwd()

    if os.path.isfile(input_path):
        parse_log_file(input_path)
        base_name = os.path.basename(input_path)
        output_file = os.path.splitext(base_name)[0] + "_VCD_api_stats.csv"
        write_csv(os.path.join(output_dir, output_file))

    elif os.path.isdir(input_path):
        log_files = glob.glob(os.path.join(input_path, "*.request.log"))
        if not log_files:
            print(f"No .request.log files found in directory: {input_path}")
            sys.exit(1)
        for file in log_files:
            parse_log_file(file)
        write_csv(os.path.join(output_dir, "vcd_api_stats.csv"))

    else:
        print(f"Invalid path: {input_path}")
        sys.exit(1)

if __name__ == "__main__":
    main()