#!/usr/bin/env python3
"""Fails CI unless the expected tests actually ran and passed.

Reads a report written by `flutter test --file-reporter json:<path>`.

    check_test_report.py REPORT [--expect FILE] [--min-tests N]
                                [--allow-skip SUBSTRING ...]

- Every visible test must pass. Hidden "loading" entries are ignored.
- Any skipped test fails the check unless its name contains an
  --allow-skip substring (used only for the opt-in destructive test).
- Every line of --expect FILE (full test names, `#` comments allowed) must
  match exactly one test that passed (or was explicitly allowed to skip).
- At least --min-tests tests must have passed.

Prints test names and counts only, never test output.
"""

import argparse
import json
import sys


def load_events(path):
    events = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line.startswith("{"):
                events.append(json.loads(line))
    if not events:
        raise SystemExit(f"Empty or missing test report: {path}")
    return events


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("report")
    parser.add_argument("--expect")
    parser.add_argument("--min-tests", type=int, default=1)
    parser.add_argument("--allow-skip", action="append", default=[])
    args = parser.parse_args()

    names = {}
    results = {}
    finished = False
    for event in load_events(args.report):
        kind = event.get("type")
        if kind == "testStart":
            test = event["test"]
            names[test["id"]] = test.get("name", "")
        elif kind == "testDone":
            results[event["testID"]] = event
        elif kind == "done":
            finished = True

    if not finished:
        raise SystemExit("The test run did not finish.")

    passed, skipped_allowed, problems = [], [], []
    for test_id, done in results.items():
        if done.get("hidden"):
            continue
        name = names.get(test_id, f"<unknown {test_id}>")
        if done.get("skipped"):
            if any(allowed in name for allowed in args.allow_skip):
                skipped_allowed.append(name)
            else:
                problems.append(f"skipped unexpectedly: {name}")
        elif done.get("result") != "success":
            problems.append(f"failed: {name}")
        else:
            passed.append(name)

    if args.expect:
        with open(args.expect, encoding="utf-8") as handle:
            expected = [
                line.strip()
                for line in handle
                if line.strip() and not line.lstrip().startswith("#")
            ]
        for name in expected:
            if passed.count(name) == 1 or name in skipped_allowed:
                continue
            if passed.count(name) > 1:
                problems.append(f"ran more than once: {name}")
            else:
                problems.append(f"expected test did not pass: {name}")

    if len(passed) < args.min_tests:
        problems.append(
            f"only {len(passed)} tests passed; at least {args.min_tests} required"
        )

    print(
        f"passed={len(passed)} skipped_allowed={len(skipped_allowed)} "
        f"problems={len(problems)}"
    )
    for name in skipped_allowed:
        print(f"allowed skip: {name}")
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
