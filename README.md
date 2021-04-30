# WakeOnLANFromCSV
Ingests a CSV file containing MAC addresses and then sends a WoL magic packet to each MAC address using a PowerShell script
This script assumes that the computer you execute it on has a network interface on the same subnet as the target machine
It also assumes that every machine in the file is on the same subnet
