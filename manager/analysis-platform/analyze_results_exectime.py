import matplotlib.pyplot as plt
import numpy as np

# SUT 1 RasDaMan
# SUT 2 OpenDataCube
COLORS = {
    "Rasdaman": "#1f77b4",
    "OpenDataCube": "#ff7f0e",
}

concurrency = [4, 12, 20]
execution_time_sut1 = [1.5455, 1.6466, 1.6531] 
execution_time_sut2 = [0.7140, 0.8011, 0.7416]

x = np.arange(len(concurrency))
width = 0.35

fig, ax = plt.subplots(figsize=(7, 5))
bars1 = ax.bar(
    x - width/2,
    execution_time_sut1,
    width,
    label='Rasdaman',
    color=COLORS['Rasdaman'],
    alpha=0.6,
    edgecolor='black',
    linewidth=1.5
)
bars2 = ax.bar(
    x + width/2,
    execution_time_sut2,
    width,
    label='OpenDataCube',
    color=COLORS['OpenDataCube'],
    alpha=0.6,
    edgecolor='black',
    linewidth=1.5
)

ax.set_xlabel('Concurrency')
ax.set_ylabel('Queries Per Second (q/s)')
ax.set_xticks(x)
ax.set_xticklabels(concurrency)
ax.legend(loc='upper center', bbox_to_anchor=(0.5, -0.15), ncol=2)

for bars in [bars1, bars2]:
    ax.bar_label(bars, fmt='%.4f', padding=3)

plt.grid(axis='y', linestyle='--', alpha=0.6)
plt.tight_layout()
plt.savefig('execution_time_comparison.png', dpi=300)