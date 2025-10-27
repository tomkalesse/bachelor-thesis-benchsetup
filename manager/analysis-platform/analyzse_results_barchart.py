import matplotlib.pyplot as plt
import numpy as np

concurrency = [4, 12, 20]
execution_time_sut1 = [32.5, 45.2, 68.4] 
execution_time_sut2 = [28.7, 39.9, 80.1]

x = np.arange(len(concurrency))
width = 0.35

fig, ax = plt.subplots(figsize=(7, 5))
bars1 = ax.bar(x - width/2, execution_time_sut1, width, label='RasDaMan')
bars2 = ax.bar(x + width/2, execution_time_sut2, width, label='OpenDataCube')

ax.set_xlabel('Concurrency')
ax.set_ylabel('Execution Time (seconds)')
ax.set_title('Execution Time vs. Concurrency for Two SUTs')
ax.set_xticks(x)
ax.set_xticklabels(concurrency)
ax.legend()

for bars in [bars1, bars2]:
    ax.bar_label(bars, fmt='%.1f', padding=3)

plt.tight_layout()
plt.show()
