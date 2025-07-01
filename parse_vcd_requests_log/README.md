# VCD Request Log Parser

A Python tool that analyzes VMware Cloud Director (VCD) request logs to generate API usage statistics aggregated by hour.

## Overview

This script parses VCD request log files (`.request.log`) and generates a CSV report containing:
- API call counts per hour
- Number of unique client IP addresses
- Successful vs. unsuccessful API call metrics

The tool is useful for VMware administrators who need to analyze VCD API traffic patterns, troubleshoot performance issues, or understand API usage trends.

## Features

- Parses VCD request logs in standard format
- Aggregates API statistics by date and hour
- Supports processing individual log files or entire directories
- Identifies successful (status 200-399) vs. unsuccessful API calls
- Tracks unique client IP addresses making API requests
- Generates a clean CSV report for further analysis

## Requirements

- Python 3.6+
- No external dependencies beyond the Python standard library

## Installation

Clone or download this repository:

```bash
git clone <repository-url>
cd parse_vcd_requests_log
```

## Usage

The script can process either a single log file or a directory containing multiple `.request.log` files:

```bash
python3 parse_vcd_requests_log.py <logfile | directory>
```

### Examples

Process a single log file:

```bash
python3 parse_vcd_requests_log.py /path/to/vcd.request.log
```

Process all `.request.log` files in a directory:

```bash
python3 parse_vcd_requests_log.py /path/to/log/directory/
```

## Output

The script generates a CSV file with the following columns:
- **Date**: ISO format date (YYYY-MM-DD)
- **Hour**: Hour of the day (0-23)
- **Number of API Calls**: Total API requests in that hour
- **Number of Different IPs**: Count of unique IP addresses making requests
- **Number of Successful API Calls**: Requests with HTTP status codes 200-399
- **Number of Unsuccessful API Calls**: Requests with error status codes

### Output Location

- Single file input: Creates `[filename]_VCD_api_stats.csv` in the current directory
- Directory input: Creates `vcd_api_stats.csv` in the current directory

## Log Format Requirements

The script expects VCD logs in the standard format:
```
IP_ADDRESS - - [DD/MMM/YYYY:HH:MM:SS +ZZZZ] "REQUEST" STATUS_CODE
```

## Disclaimer

This script is provided as is without any warranty. Use at your own risk. I hold no liability for the accuracy of the information produced by this tool.

## License
