import os
import re
from collections import defaultdict


FOLDER = "./odc"
pattern = re.compile(r"results_execution(\d+)_(\d+)\.txt")
durations = defaultdict(float)

for filename in os.listdir(FOLDER):
    match = pattern.match(filename)
    if not match:
        continue

    num1 = int(match.group(1))
    filepath = os.path.join(FOLDER, filename)

    with open(filepath, "r") as f:
        content = f.read().strip()

        if content.endswith("ms"):
            value = float(content[:-2]) / 1000
        elif "m" in content and content.endswith("s"):
            minutes, seconds = content.split("m")
            value = float(minutes) * 60 + float(seconds[:-1])
        elif content.endswith("s"):
            value = float(content[:-1])
        else:
            raise ValueError(f"Unknown duration format in {filename}: {content}")
        
        durations[num1] += value

with open("results_summary.txt", "w") as out:
    for num1 in sorted(durations):
        out.write(f"execution{num1}: {durations[num1]:.6f}s\n")

print("Summary written to results_summary.txt")
