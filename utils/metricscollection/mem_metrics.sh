#!/bin/bash
# mem_metrics.sh
OUTFILE="/home/ubuntu/metrics/mem_metrics.csv"
echo "timestamp,mem_available" > $OUTFILE

while true; do
    TS=$(date +%s)
    # free -m with awk gives available memory in percent (instantly)
    mem_avail=$(free | awk '/Mem:/ {printf "%.2f", $7/$2*100}')
    echo "$TS,$mem_avail" >> $OUTFILE
    sleep 1
done
