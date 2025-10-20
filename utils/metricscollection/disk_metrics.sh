#!/bin/bash
OUTFILE="/home/ubuntu/metrics/disk_metrics.csv"
echo "timestamp,disk_used_percent,disk_available_gb,disk_total_gb" > $OUTFILE

while true; do
    TS=$(date +%s)
    # df -h gives disk usage info
    read used_percent avail_gb total_gb <<< $(df -BG / | awk 'NR==2 {gsub(/G/,"",$2); gsub(/G/,"",$4); gsub(/%/,"",$5); print $5,$4,$2}')
    echo "$TS,$used_percent,$avail_gb,$total_gb" >> $OUTFILE
    sleep 1
done