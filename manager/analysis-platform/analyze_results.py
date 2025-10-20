import os
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path
import re

RASDAMAN_DIR = Path("/home/ubuntu/analysis-platform/results/rasdaman")
ODC_DIR = Path("/home/ubuntu/analysis-platform/results/odc")
OUTPUT_DIR = Path("/home/ubuntu/analysis-platform/results")
OUTPUT_DIR.mkdir(exist_ok=True)
FILE_PREFIX = "results_execution"
COLORS = {
    "Rasdaman": "#1f77b4",
    "OpenDataCube": "#ff7f0e",
}


def extract_run_number(filename: str, prefix: str):
    pattern = rf"{prefix}(\d+)_\d+\.csv"
    match = re.match(pattern, filename)
    return int(match.group(1)) if match else None


def group_files_by_run(directory: Path, prefix: str):
    files = list(directory.glob(f"{prefix}*.csv"))
    runs = {}
    
    for file in files:
        run_num = extract_run_number(file.name, prefix)
        if run_num is not None:
            if run_num not in runs:
                runs[run_num] = []
            runs[run_num].append(file)
    
    return runs


def find_matching_runs(dir1: Path, dir2: Path, prefix: str):
    ras_runs = group_files_by_run(dir1, prefix)
    odc_runs = group_files_by_run(dir2, prefix)
    
    common_runs = set(ras_runs.keys()) & set(odc_runs.keys())
    return [(run_num, ras_runs[run_num], odc_runs[run_num]) for run_num in sorted(common_runs)]


def load_results(path: Path, sut_name: str):
    df = pd.read_csv(path)
    df["SUT"] = sut_name
    df["file"] = path.name
    return df


def load_run_results(file_list: list, sut_name: str):
    all_dfs = []
    for file_path in file_list:
        df = load_results(file_path, sut_name)
        all_dfs.append(df)
    return pd.concat(all_dfs, ignore_index=True)

def create_summary_table(df_combined: pd.DataFrame, run_number: int):
    summary_rows = []
    for sut in df_combined["SUT"].unique():
        sut_df = df_combined[df_combined["SUT"] == sut]

        total_exec_time = sut_df["latency_ms"].sum()
        p90 = sut_df["latency_ms"].quantile(0.90)
        p99 = sut_df["latency_ms"].quantile(0.99)
        avg_latency = sut_df["latency_ms"].mean()

        summary_rows.append({
            "SUT": sut,
            "Execution time (ms)": round(total_exec_time, 2),
            "ω.90 (ms)": round(p90, 2),
            "ω.99 (ms)": round(p99, 2),
            "Avg. latency (ms)": round(avg_latency, 2),
        })

    df_summary = pd.DataFrame(summary_rows)
    df_summary.to_csv(OUTPUT_DIR / f"run{run_number}_summary.csv", index=False)
    print(f"Summary table saved: run{run_number}_summary.csv")
    return df_summary

def plot_boxplot(df_combined: pd.DataFrame, run_number: int):
    plt.figure(figsize=(6, 4))

    data = [df_combined[df_combined["SUT"] == sut]["latency_ms"] for sut in COLORS.keys()]

    bp = plt.boxplot(
        data,
        patch_artist=True,
        labels=COLORS.keys(),
        widths=0.5,
        showmeans=True,
        meanprops={"marker": "o", "markerfacecolor": "black", "markeredgecolor": "black"},
    )

    for patch, sut in zip(bp["boxes"], COLORS.keys()):
        patch.set_facecolor(COLORS[sut])
        patch.set_alpha(0.6)
        patch.set_edgecolor("black")
        patch.set_linewidth(1.5)

    for whisker in bp["whiskers"]:
        whisker.set_linewidth(1.2)
    for cap in bp["caps"]:
        cap.set_linewidth(1.2)
    for median in bp["medians"]:
        median.set_color("black")
        median.set_linewidth(1.5)

    plt.grid(axis="y", linestyle="--", alpha=0.6)
    plt.ylabel("Latency (ms)")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / f"run{run_number}_latency_boxplot.png", dpi=200, bbox_inches="tight")
    plt.close()

def create_overall_summary(df_all: pd.DataFrame):
    summary_rows = []
    for sut in df_all["SUT"].unique():
        sut_df = df_all[df_all["SUT"] == sut]

        total_exec_time = sut_df["latency_ms"].sum()
        p90 = sut_df["latency_ms"].quantile(0.90)
        p99 = sut_df["latency_ms"].quantile(0.99)
        avg_latency = sut_df["latency_ms"].mean()

        summary_rows.append({
            "SUT": sut,
            "Execution time (ms)": round(total_exec_time, 2),
            "ω.90 (ms)": round(p90, 2),
            "ω.99 (ms)": round(p99, 2),
            "Avg. latency (ms)": round(avg_latency, 2),
        })

    df_summary = pd.DataFrame(summary_rows)
    df_summary.to_csv(OUTPUT_DIR / "overall_summary.csv", index=False)
    print("Overall summary table saved: overall_summary.csv")

def plot_overall_boxplot(df_all: pd.DataFrame):
    plt.figure(figsize=(6, 4))
    data = [df_all[df_all["SUT"] == sut]["latency_ms"] for sut in COLORS.keys()]

    bp = plt.boxplot(
        data,
        patch_artist=True,
        labels=COLORS.keys(),
        widths=0.5,
        showmeans=True,
        meanprops={"marker": "o", "markerfacecolor": "black", "markeredgecolor": "black"},
    )

    for patch, sut in zip(bp["boxes"], COLORS.keys()):
        patch.set_facecolor(COLORS[sut])
        patch.set_alpha(0.6)
        patch.set_edgecolor("black")
        patch.set_linewidth(1.5)

    for whisker in bp["whiskers"]:
        whisker.set_linewidth(1.2)
    for cap in bp["caps"]:
        cap.set_linewidth(1.2)
    for median in bp["medians"]:
        median.set_color("black")
        median.set_linewidth(1.5)

    plt.grid(axis="y", linestyle="--", alpha=0.6)
    plt.ylabel("Latency (ms)")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "overall_latency_boxplot.png", dpi=200, bbox_inches="tight")
    plt.close()


def main():
    matching_runs = find_matching_runs(RASDAMAN_DIR, ODC_DIR, FILE_PREFIX)
    all_combined = []

    if not matching_runs:
        print("No matching runs found!")
        return

    for run_num, ras_files, odc_files in matching_runs:
        df_ras = load_run_results(ras_files, "Rasdaman")
        df_odc = load_run_results(odc_files, "OpenDataCube")
        df_combined = pd.concat([df_ras, df_odc], ignore_index=True)
        df_combined = df_combined[df_combined["status_code"] == 200]

        all_combined.append(df_combined)

        plot_boxplot(df_combined, run_num)
        create_summary_table(df_combined, run_num)

        print(f"Compared run {run_num}: {len(ras_files)} Rasdaman files, {len(odc_files)} ODC files")

    df_all = pd.concat(all_combined, ignore_index=True)
    plot_overall_boxplot(df_all)
    create_overall_summary(df_all)

    print(f"All plots saved in: {OUTPUT_DIR.resolve()}")


if __name__ == "__main__":
    main()