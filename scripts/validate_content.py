#!/usr/bin/env python3
"""Checks the bundled course content before building the app."""
import json, sys, pathlib

root = pathlib.Path(__file__).resolve().parent.parent / "SansFaute" / "Resources"
errors = []

def load(name):
    try:
        return json.loads((root / f"{name}.json").read_text(encoding="utf-8"))
    except Exception as e:
        errors.append(f"{name}.json: {e}")
        return []

def check_question(q, where):
    for k in ("id", "topic", "level", "prompt", "options", "answer", "explanation"):
        if k not in q:
            errors.append(f"{where}: question missing '{k}'")
            return
    if not (0 <= q["answer"] < len(q["options"])):
        errors.append(f"{where} {q['id']}: answer index out of range")
    if len(set(q["options"])) != len(q["options"]):
        errors.append(f"{where} {q['id']}: duplicate options")
    if q["level"] not in ("B2", "C1", "C2"):
        errors.append(f"{where} {q['id']}: unknown level {q['level']}")

lessons = load("lessons"); grammar = load("grammar"); vocab = load("vocab")
listening = load("listening"); reading = load("reading"); plan = load("plan")

ids = []
lesson_ids = {l["id"] for l in lessons}
for q in grammar:
    check_question(q, "grammar"); ids.append(q["id"])
    if q["topic"] not in lesson_ids:
        errors.append(f"grammar {q['id']}: topic '{q['topic']}' has no lesson")
for l in listening:
    ids.append(l["id"])
    if not l["segments"]: errors.append(f"listening {l['id']}: no audio text")
    for q in l["questions"]: check_question(q, f"listening {l['id']}"); ids.append(q["id"])
for r in reading:
    ids.append(r["id"])
    for q in r["questions"]: check_question(q, f"reading {r['id']}"); ids.append(q["id"])
vids = [v["id"] for v in vocab]
for name, lst in (("question/item", ids), ("vocab", vids)):
    dup = {x for x in lst if lst.count(x) > 1}
    if dup: errors.append(f"duplicate {name} ids: {sorted(dup)}")

refs = {"listening": {l["id"] for l in listening}, "lesson": lesson_ids, "reading": {r["id"] for r in reading}}
for d in plan:
    for t in d["tasks"]:
        ref = t.get("ref")
        if ref and t["kind"] in refs and ref not in refs[t["kind"]]:
            errors.append(f"plan day {d['day']}: unknown {t['kind']} ref {ref}")

print(f"lessons {len(lessons)} · grammar {len(grammar)} · vocab {len(vocab)} · listening {len(listening)} · reading {len(reading)} · plan days {len(plan)}")
if errors:
    print("\n".join(errors)); sys.exit(1)
print("Content OK")
