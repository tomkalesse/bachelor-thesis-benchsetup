#!/bin/bash
OUTFILE="/home/ubuntu/metrics/cpu_metrics.csv"
echo "timestamp,cpu_user,cpu_system,cpu_iowait,cpu_idle" > $OUTFILE

while true; do
    TS=$(date +%s)
    # mpstat outputs CPU % without manual calculation (waits 1 sec)
    read cpu_user cpu_system cpu_iowait cpu_idle <<< $(mpstat 1 1 | awk '/Average/ {print $3,$5,$6,$12}')
    echo "$TS,$cpu_user,$cpu_system,$cpu_iowait,$cpu_idle" >> $OUTFILE
done