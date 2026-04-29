# Scripts Overview

This repository contains a collection of PowerShell, Python, PHP, and PXE/iPXE utilities. Each script resides in its own folder with a detailed README explaining usage and dependencies.

## Directory Summary

- **audit-exchange2016** – Health and best practices audit for Exchange Server 2016.
- **check-dns-exchange-health** – Windows based DNS validation for Exchange records.
- **check-dns-exchange-health-mac** – macOS/Linux variant using `dig`.
- **cpu-topology** – Reports VM CPU topology and highlights non-default settings.
- **dns-check** – Validates hostnames or IPs against a DNS server using `nslookup`.
- **evc-mode** – Lists VMs that may block enabling EVC mode in a cluster.
- **parse_vcd_requests_log** – Python parser for VMware Cloud Director request logs.
- **pxe-deployment** – iPXE and kickstart framework for imaging ESXi hosts from customer-supplied ESXi media.
- **sanitize-rvtools** – Sanitizes RVTools `.xlsx` exports and can restore them using a protected JSON mapping file.
- **share** – RVTools assessment project in development.
- **tpm-backup** – Backup TPM recovery keys from ESXi hosts.

Each folder contains the script file and a README describing required modules and how to run it.
