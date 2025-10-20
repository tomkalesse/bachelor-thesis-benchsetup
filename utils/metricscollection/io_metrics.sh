#!/bin/bash
OUTFILE="/home/ubuntu/metrics/io_metrics.csv"
echo "timestamp,r_iops,w_iops,r_kB_s,w_kB_s,r_await_ms,w_await_ms,util_percent" > $OUTFILE

while true; do
    TS=$(date +%s)
    # iostat -dx 1 2 gives extended disk stats (waits 1 sec)
    read r_iops w_iops r_kB_s w_kB_s r_await w_await util <<< \
    $(iostat -dx 1 2 | awk '/^Device/ {header=NR} NR>header && $1=="vda" {print $2,$8,$3,$9,$6,$12,$23}')
    echo "$TS,$r_iops,$w_iops,$r_kB_s,$w_kB_s,$r_await,$w_await,$util" >> $OUTFILE
done