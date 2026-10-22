#!/usr/bin/env python3
"""Aggregate the RQ3 benchmark CSVs into the layout of Table 4 (mean latency).

Usage: rq3_table4.py OUT_DIR   (OUT_DIR = artifact/out/rq3, as written by
artifact/rq3_benchmark.sh). Uses the most recent run of each setup:
  OUT_DIR/gdprsocial/{baseline,enforced}/minitwitter_<timestamp>/report.csv
  OUT_DIR/gdprfs/<mode>/simple_perf_results_preload<sizes>.csv
"""
import csv
import statistics
import sys
from collections import defaultdict
from pathlib import Path

SIZES = [100, 1000, 10000]

SOCIAL_ROWS = [  # (label, scenario in report.csv)
    ("Timeline", "timeline"), ("Post", "post_tweet"), ("Consent", "give_consent"),
    ("Revoke", "revoke_consent"), ("Notices", "privacy_notices"), ("Access", "right_to_info"),
]
FS_ROWS = [  # (label, column in the GDPRFS CSV)
    ("Read", "t_read_file"), ("Write", "t_write_file"), ("Consent", "t_give_consent"),
    ("Revoke", "t_remove_consent"), ("Erasure", "t_request_erasure"),
    ("Rectification", "t_request_rectification"),
]
# Table 4 of the paper (ms): (baseline, instrumented) for n = 10^2, 10^3, 10^4.
PAPER_SOCIAL = {
    "Timeline": ((61, 61, 63), (91, 106, 102)), "Post": ((60, 66, 57), (104, 103, 102)),
    "Consent": ((75, 58, 62), (74, 102, 111)), "Revoke": ((62, 56, 54), (85, 92, 95)),
    "Notices": ((72, 58, 68), (70, 90, 76)), "Access": ((65, 59, 72), (85, 75, 77)),
}
PAPER_FS = {  # instrumented = with LLM analyzer
    "Read": (("<1",) * 3, (74, 67, 79)), "Write": (("<1",) * 3, ("2.3s", "2.2s", "2.2s")),
    "Consent": (("--",) * 3, (12, 13, 14)), "Revoke": (("--",) * 3, (13, 14, 15)),
    "Erasure": (("--",) * 3, ("1.0s",) * 3), "Rectification": (("--",) * 3, (21, 22, 22)),
}


def latest(paths):
    paths = sorted(paths, key=lambda p: p.stat().st_mtime)
    return paths[-1] if paths else None


def fmt(ms):
    if ms is None:
        return "n/a"
    if ms >= 1000:
        return f"{ms / 1000:.1f}s"
    return "<1" if ms < 1 else f"{ms:.0f}"


def social(out, setup):
    """{(scenario, n): mean ms} from the latest report.csv of a setup."""
    path = latest(list((out / "gdprsocial" / setup).glob("*/report.csv")))
    if path is None:
        return None, None
    acc = defaultdict(list)
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            acc[(r["sc"], int(r["n"]))].append(float(r["t"]) * 1000)
    return {k: statistics.mean(v) for k, v in acc.items()}, path


def fs(out, mode):
    """{(column, preload): mean ms} from the latest preload CSV of a mode."""
    path = latest(list((out / "gdprfs" / mode).glob("simple_perf_results_preload*.csv")))
    if path is None:
        return None, None
    acc = defaultdict(list)
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            for _, col in FS_ROWS:
                if r.get(col) not in (None, ""):
                    acc[(col, int(r["preload"]))].append(float(r[col]) * 1000)
    return {k: statistics.mean(v) for k, v in acc.items()}, path


def row(label, cells, paper):
    return f"  {label:<14}" + "".join(f"{c:>9}" for c in cells) + "   | paper: " + \
        " / ".join(str(p) for p in paper)


def main():
    out = Path(sys.argv[1])
    lines = []
    head = f"  {'':<14}" + "".join(f"{'n=' + str(n):>9}" for n in SIZES)

    lines.append("GDPRSocial — mean latency (ms) per request, by number of posts n")
    for setup, idx, title in (("baseline", 0, "Baseline"), ("enforced", 1, "Instrumented")):
        data, path = social(out, setup)
        lines.append(f"\n  {title}  ({path if path else 'no results found'})")
        lines.append(head)
        for label, sc in SOCIAL_ROWS:
            cells = [fmt(data.get((sc, n))) if data else "n/a" for n in SIZES]
            lines.append(row(label, cells, PAPER_SOCIAL[label][idx]))

    lines.append("\nGDPRFS — mean latency (ms) per operation, by number of preloaded files n")
    for mode, idx, title in (("baseline", 0, "Baseline"),
                             ("gdpr_no_llm", 1, "Instrumented, without LLM analyzer"),
                             ("gdpr_with_llm", 1, "Instrumented, with LLM analyzer (paper setup)")):
        data, path = fs(out, mode)
        if data is None and mode == "gdpr_with_llm":
            lines.append(f"\n  {title}: not run (make artifact-rq3-full)")
            continue
        lines.append(f"\n  {title}  ({path if path else 'no results found'})")
        lines.append(head)
        for label, col in FS_ROWS:
            cells = [fmt(data.get((col, n))) if data else "n/a" for n in SIZES]
            lines.append(row(label, cells, PAPER_FS[label][idx]))
    lines.append("\nPaper values for GDPRFS 'Instrumented' include the LLM analyzer"
                 " (Write: ~2s); compare the without-LLM rows on Read/Consent/Revoke/"
                 "Erasure/Rectification only.")

    text = "\n".join(lines)
    print(text)
    (out / "table4.txt").write_text(text + "\n")


if __name__ == "__main__":
    main()
