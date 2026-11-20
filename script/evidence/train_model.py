#!/usr/bin/env python3
"""Trains the optional evidence scorer and exports it for Evidence::Model.

CPU only. Labels come from (a) distilled judgements (Cloudflare Clef or an
LLM labelling stretch features offline), (b) reviewer and Fraud Squad
decisions, and (c) scripted synthetic attacks. This script generates (c) and
accepts (a) and (b) as a CSV with the Evidence::Model::FEATURES columns
plus `label` (1 = real work).

    uv run --with lightgbm --with scikit-learn script/evidence/train_model.py \
        --labels private/labels.csv --out private/evidence_model.json

Keep the output private (EVIDENCE_MODEL_PATH): the code is AGPL, the
weights are not.
"""
import argparse, csv, json, random
import numpy as np
import lightgbm as lgb
from sklearn.isotonic import IsotonicRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score, brier_score_loss

FEATURES = """minutes active_ratio keys_per_min clicks_per_min moves_per_min injected_ratio rhythm jiggler
ai_prompts ai_waiting_ratio edits commits builds tree_changes frames frames_due frames_on_time
research_ratio unrelated_ratio follow_up offline_ratio signed_ratio duplicate_frames hardware_tier""".split()


def honest(r):
    m = r.randint(5, 120)
    due = max(0, round(m * 5 / 60 + r.gauss(0, 0.7)))
    return dict(minutes=m, active_ratio=r.uniform(0.45, 0.95), keys_per_min=r.uniform(15, 140), clicks_per_min=r.uniform(1, 12),
                moves_per_min=r.uniform(10, 80), injected_ratio=r.uniform(0, 0.02), rhythm=r.uniform(0.45, 1), jiggler=r.uniform(0, 0.2),
                ai_prompts=r.randint(0, m // 3), ai_waiting_ratio=r.uniform(0, 0.3), edits=r.randint(m // 3, m * 4), commits=r.randint(0, m // 20 + 1),
                builds=r.randint(0, m // 4), tree_changes=r.randint(1, m // 5 + 1), frames=r.randint(due, due + m // 4), frames_due=due, frames_on_time=due,
                research_ratio=r.uniform(0, 0.35), unrelated_ratio=r.uniform(0, 0.1), follow_up=1, offline_ratio=r.choice([0, 0, 0, r.uniform(0, 0.3)]),
                signed_ratio=r.choice([0, 1, 1]), duplicate_frames=0, hardware_tier=r.choice([0, 1, 1, 3]))


def attack(r):
    row = honest(r)
    kind = r.choice(["jiggler", "autohotkey", "slowed_replay", "fake_client", "idle_tabs", "ai_padding"])
    m = row["minutes"]
    if kind == "jiggler":
        row.update(keys_per_min=r.uniform(0, 2), clicks_per_min=0, moves_per_min=r.uniform(30, 120), jiggler=r.uniform(0.6, 1), rhythm=0.5,
                   edits=r.randint(0, 2), tree_changes=0, follow_up=r.choice([0, 1]))
    elif kind == "autohotkey":
        row.update(injected_ratio=r.uniform(0.2, 1), rhythm=r.uniform(0, 0.15), keys_per_min=r.uniform(60, 300))
    elif kind == "slowed_replay":
        row.update(duplicate_frames=r.randint(1, max(2, m // 4)), frames_on_time=max(0, row["frames_due"] - r.randint(1, 3)),
                   tree_changes=r.randint(0, 1), rhythm=r.uniform(0.1, 0.5), edits=r.randint(0, m // 4))
    elif kind == "fake_client":
        row.update(frames_on_time=0, frames=0, signed_ratio=0, hardware_tier=0, rhythm=r.uniform(0.2, 0.9), tree_changes=r.randint(0, 2),
                   offline_ratio=r.uniform(0.3, 1))
    elif kind == "idle_tabs":
        row.update(active_ratio=r.uniform(0, 0.25), keys_per_min=r.uniform(0, 4), edits=0, commits=0, tree_changes=0, follow_up=0,
                   research_ratio=r.uniform(0.6, 1))
    else:
        row.update(ai_waiting_ratio=r.uniform(0.6, 1), ai_prompts=r.randint(m // 2, m * 2), edits=r.randint(0, 2), tree_changes=0, follow_up=0)
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--labels", help="CSV of distilled and reviewer labels")
    parser.add_argument("--synthetic", type=int, default=20000)
    parser.add_argument("--out", default="evidence_model.json")
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()
    r = random.Random(args.seed)
    rows, labels = [], []
    for _ in range(args.synthetic):
        if r.random() < 0.55:
            rows.append(honest(r)); labels.append(1)
        else:
            rows.append(attack(r)); labels.append(0)
    if args.labels:
        with open(args.labels) as f:
            for rec in csv.DictReader(f):
                rows.append({k: float(rec.get(k) or 0) for k in FEATURES}); labels.append(int(rec["label"]))
    X = np.array([[row[k] for k in FEATURES] for row in rows], dtype=float)
    y = np.array(labels)
    X_train, X_rest, y_train, y_rest = train_test_split(X, y, test_size=0.3, random_state=args.seed, stratify=y)
    X_cal, X_test, y_cal, y_test = train_test_split(X_rest, y_rest, test_size=0.5, random_state=args.seed, stratify=y_rest)

    booster = lgb.train(dict(objective="binary", learning_rate=0.08, num_leaves=15, min_data_in_leaf=40, feature_fraction=0.9,
                             verbose=-1, num_threads=1, seed=args.seed),
                        lgb.Dataset(X_train, y_train, feature_name=FEATURES), num_boost_round=120)
    iso = IsotonicRegression(out_of_bounds="clip", y_min=0, y_max=1).fit(booster.predict(X_cal), y_cal)
    calibrated = iso.predict(booster.predict(X_test))
    print(f"test AUC {roc_auc_score(y_test, calibrated):.4f}  Brier {brier_score_loss(y_test, calibrated):.4f}  n={len(y_test)}")

    dump = booster.dump_model()
    dump["calibration"] = {"x": iso.X_thresholds_.tolist(), "y": iso.y_thresholds_.tolist()}
    dump["name"] = f"lightgbm-{args.seed}"
    # A few rows with expected outputs so the Ruby evaluator can be checked.
    dump["check_rows"] = [{"features": dict(zip(FEATURES, X_test[i].tolist())), "expected": float(calibrated[i])} for i in range(5)]
    with open(args.out, "w") as f:
        json.dump(dump, f)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
