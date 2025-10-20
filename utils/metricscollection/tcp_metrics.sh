#!/bin/bash
OUTFILE="/home/ubuntu/metrics/tcp_metrics.csv"
echo "timestamp,tcp_established,tcp_syn_recv,tcp_time_wait,tcp_listen" > $OUTFILE

while true; do
    TS=$(date +%s)
    # netstat counts TCP connections by state
    established=$(netstat -an | grep -c "ESTABLISHED")
    syn_recv=$(netstat -an | grep -c "SYN_RECV")
    time_wait=$(netstat -an | grep -c "TIME_WAIT")
    listen=$(netstat -an | grep -c "LISTEN")
    echo "$TS,$established,$syn_recv,$time_wait,$listen" >> $OUTFILE
    sleep 1
done