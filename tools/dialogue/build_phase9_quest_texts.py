"""Phase 9: writes the chain texts (tools/dialogue/phase9_quest_texts.json, P6) into data/quests/<id>.tres (structure P1).

    python3 tools/dialogue/build_phase9_quest_texts.py [--dir=<folder with q_*.tres>]

docs/PHASE9_DESIGN.md §3.2: P1 owns the structure of data/quests/{q_who_knows,q_letters,q_case}.tres (steps, conditions,
choices, actions), P6 the texts (title, summary, hint, the choice labels and block texts, the endings' title / summary /
closing_line). This tool replaces only those text fields, matched by the sub-resource's script (QuestStepData /
QuestChoiceData / QuestEndingData) and id – choices by their step – and leaves everything else byte-identical. A missing
file or id is reported, never created. Idempotent; run it after every merge that touches data/quests.
"""
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEXTS = os.path.join(os.path.dirname(__file__), "phase9_quest_texts.json")
SCRIPTS = {"quest": "quest_data.gd", "step": "quest_step_data.gd", "choice": "quest_choice_data.gd", "ending": "quest_ending_data.gd"}


def q(s):
    return json.dumps(s, ensure_ascii=False)


def _set(block, field, value):
    line = "%s = %s" % (field, q(value))
    pat = re.compile(r'^%s = ".*"$' % field, re.M)
    if pat.search(block):
        return pat.sub(lambda _m: line, block, count=1)
    return block.rstrip("\n") + "\n" + line


def apply(path, texts):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    ext = {}
    for m in re.finditer(r'\[ext_resource type="Script"[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"\]', text):
        for kind, script in SCRIPTS.items():
            if m.group(1).endswith("/" + script):
                ext[kind] = m.group(2)
    blocks = text.split("\n\n")
    missing = []
    # step id of every choice: the step block lists its choices as SubResource ids.
    choice_step = {}
    sub_ids = {}
    for i, b in enumerate(blocks):
        m = re.match(r'\[sub_resource type="Resource" id="([^"]+)"\]', b.strip())
        if m:
            sub_ids[m.group(1)] = i
    for b in blocks:
        if 'script = ExtResource("%s")' % ext.get("step", "?") in b:
            sid = re.search(r'^id = &"([^"]+)"$', b, re.M).group(1)
            m = re.search(r'^choices = .*\(\[(.*)\]\)$', b, re.M)
            for ref in re.findall(r'SubResource\("([^"]+)"\)', m.group(1) if m else ""):
                choice_step[ref] = sid
    done = {"steps": set(), "choices": set(), "endings": set()}
    for i, b in enumerate(blocks):
        head = re.match(r'\[sub_resource type="Resource" id="([^"]+)"\]', b.strip())
        mid = re.search(r'^id = &"([^"]+)"$', b, re.M)
        if b.strip().startswith("[resource]"):
            for field in ("title", "summary"):
                b = _set(b, field, texts[field])
        elif head and mid and 'script = ExtResource("%s")' % ext.get("step", "?") in b:
            t = texts["steps"].get(mid.group(1))
            if t:
                b = _set(_set(b, "title", t["title"]), "hint", t["hint"])
                done["steps"].add(mid.group(1))
        elif head and mid and 'script = ExtResource("%s")' % ext.get("choice", "?") in b:
            step = choice_step.get(head.group(1), "")
            t = texts.get("choices", {}).get(step, {}).get(mid.group(1))
            if t:
                b = _set(b, "label", t["label"])
                if "block_text" in t:
                    b = _set(b, "block_text", t["block_text"])
                done["choices"].add(step + ":" + mid.group(1))
        elif head and mid and 'script = ExtResource("%s")' % ext.get("ending", "?") in b:
            t = texts.get("endings", {}).get(mid.group(1))
            if t:
                for field in ("title", "summary", "closing_line"):
                    b = _set(b, field, t[field])
                done["endings"].add(mid.group(1))
        blocks[i] = b
    for sid in texts["steps"]:
        if sid not in done["steps"]:
            missing.append("step " + sid)
    for step, choices in texts.get("choices", {}).items():
        for cid in choices:
            if step + ":" + cid not in done["choices"]:
                missing.append("choice %s:%s" % (step, cid))
    for eid in texts.get("endings", {}):
        if eid not in done["endings"]:
            missing.append("ending " + eid)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(blocks))
    return missing


def main():
    folder = os.path.join(ROOT, "data", "quests")
    for a in sys.argv[1:]:
        if a.startswith("--dir="):
            folder = os.path.abspath(a[len("--dir="):])
    with open(TEXTS, encoding="utf-8") as f:
        all_texts = json.load(f)
    status = 0
    for quest_id, texts in all_texts.items():
        if quest_id.startswith("_"):
            continue
        path = os.path.join(folder, quest_id + ".tres")
        if not os.path.exists(path):
            print("skip %s: %s does not exist (P1 writes it)" % (quest_id, path))
            continue
        missing = apply(path, texts)
        for m in missing:
            print("%s: no %s in the data" % (quest_id, m))
            status = 1
        print("texts written:", path)
    sys.exit(status)


if __name__ == "__main__":
    main()
