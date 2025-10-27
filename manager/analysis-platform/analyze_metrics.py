import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import sys

if len(sys.argv) < 2:
    argument = "default"
else:
    argument = sys.argv[1]

cpu_df = pd.read_csv(f"/home/ubuntu/analysis-platform/metrics/{argument}/cpu_metrics.csv", on_bad_lines="skip")
io_df  = pd.read_csv(f"/home/ubuntu/analysis-platform/metrics/{argument}/io_metrics.csv",  on_bad_lines="skip")
mem_df = pd.read_csv(f"/home/ubuntu/analysis-platform/metrics/{argument}/mem_metrics.csv", on_bad_lines="skip")
disk_df = pd.read_csv(f"/home/ubuntu/analysis-platform/metrics/{argument}/disk_metrics.csv", on_bad_lines="skip")
tcp_df = pd.read_csv(f"/home/ubuntu/analysis-platform/metrics/{argument}/tcp_metrics.csv", on_bad_lines="skip")

cpu_df["timestamp"] = pd.to_datetime(cpu_df["timestamp"], unit="s", errors="coerce", utc=True)
io_df["timestamp"]  = pd.to_datetime(io_df["timestamp"],  unit="s", errors="coerce", utc=True)
mem_df["timestamp"] = pd.to_datetime(mem_df["timestamp"], unit="s", errors="coerce", utc=True)
disk_df["timestamp"] = pd.to_datetime(disk_df["timestamp"], unit="s", errors="coerce", utc=True)
tcp_df["timestamp"] = pd.to_datetime(tcp_df["timestamp"], unit="s", errors="coerce", utc=True)

cpu_df["timestamp"] = cpu_df["timestamp"].dt.tz_convert("Europe/Berlin")
io_df["timestamp"]  = io_df["timestamp"].dt.tz_convert("Europe/Berlin")
mem_df["timestamp"] = mem_df["timestamp"].dt.tz_convert("Europe/Berlin")
disk_df["timestamp"] = disk_df["timestamp"].dt.tz_convert("Europe/Berlin")
tcp_df["timestamp"] = tcp_df["timestamp"].dt.tz_convert("Europe/Berlin")

fig, axs = plt.subplots(5, 1, figsize=(12, 15), sharex=True)

# cpu
axs[0].plot(cpu_df['timestamp'], cpu_df['cpu_user'], label='CPU User %')
axs[0].plot(cpu_df['timestamp'], cpu_df['cpu_system'], label='CPU System %')
axs[0].plot(cpu_df['timestamp'], cpu_df['cpu_idle'], label='CPU Idle %')
axs[0].plot(cpu_df['timestamp'], cpu_df['cpu_iowait'], label='CPU IOwait %', linestyle='--', color='purple')
axs[0].set_ylabel("CPU %")
axs[0].legend(loc="upper right")
axs[0].grid(True)

# mem
axs[1].plot(mem_df['timestamp'], mem_df['mem_available'], color='green', label='Memory Available %')
axs[1].set_ylabel("Memory %")
axs[1].legend(loc="upper right")
axs[1].grid(True)

# io
ax1 = axs[2]
ax2 = ax1.twinx()
ax1.plot(io_df['timestamp'], io_df['r_iops'], label='Read IOPS', color='blue')
ax1.plot(io_df['timestamp'], io_df['w_iops'], label='Write IOPS', color='orange')
ax1.set_ylabel("IOPS")
ax2.plot(io_df['timestamp'], io_df['util_percent'], label='Disk Util %', color='red', linestyle='--')
ax2.set_ylabel("Utilization %")

lines1, labels1 = ax1.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
ax1.legend(lines1 + lines2, labels1 + labels2, loc="upper right")
ax1.grid(True)

# disk
axs[3].plot(disk_df['timestamp'], disk_df['disk_used_percent'], color='brown', label='Disk Used %')
axs[3].set_ylabel("Disk Usage %")
axs[3].legend(loc="upper right")
axs[3].grid(True)

# tcp
axs[4].plot(tcp_df['timestamp'], tcp_df['tcp_established'], label='Established')
axs[4].plot(tcp_df['timestamp'], tcp_df['tcp_syn_recv'], label='SYN_RECV')
axs[4].plot(tcp_df['timestamp'], tcp_df['tcp_time_wait'], label='TIME_WAIT')
axs[4].set_ylabel("TCP Connections")
axs[4].legend(loc="upper right")
axs[4].grid(True)

# x-axis
date_fmt = mdates.DateFormatter("%Y-%m-%d %H:%M", tz=cpu_df["timestamp"].dt.tz)
axs[-1].xaxis.set_major_formatter(date_fmt)
fig.autofmt_xdate(rotation=30)

plt.suptitle("System Metrics During Benchmark")
plt.tight_layout(rect=[0, 0, 1, 0.95])

# footer legend
fig.text(
    0.5, 0.01,
    f"Time format: YYYY-MM-DD HH:MM | Timezone: {cpu_df['timestamp'].dt.tz.zone}",
    ha="center", fontsize=9
)

plt.savefig(f"/home/ubuntu/analysis-platform/results/metrics_{argument}.png", dpi=300)
print(f"Plot saved as metrics_{argument}.png")
