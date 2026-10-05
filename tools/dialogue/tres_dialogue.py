"""Write / patch DialogueData .tres files (docs/PHASE8_DESIGN.md §3.2: P6 owns data/dialogue/*).

Small, dependency-free helpers used by build_phase8_dialogue.py:
  N(id, text, choices, cond, fb, act)  – a DialogueNode
  C(text, next, cond, act)             – a DialogueChoice
  write_new(path, dlg_id, speaker, start, nodes)
  patch(path, prefix, nodes, menus, fallbacks, start)  – idempotent: every block whose sub_resource id
      starts with `prefix` is removed first (and every reference to it), then the new blocks are added.
"""
import json
import re

NODE_SCRIPT = "res://src/systems/dialogue/dialogue_node.gd"
CHOICE_SCRIPT = "res://src/systems/dialogue/dialogue_choice.gd"
DATA_SCRIPT = "res://src/systems/dialogue/dialogue_data.gd"


class N:
    def __init__(self, id, text, choices=None, cond=None, fb="", act=None):
        self.id = id
        self.text = text
        self.choices = choices or []
        self.cond = cond or []
        self.fb = fb
        self.act = act or []


class C:
    def __init__(self, text, next="", cond=None, act=None):
        self.text = text
        self.next = next
        self.cond = cond or []
        self.act = act or []


def q(s):
    return json.dumps(s, ensure_ascii=False)


def _arr(values):
    return "Array[String]([" + ", ".join(q(v) for v in values) + "])"


def _blocks(nodes, prefix, node_ext, choice_ext):
    """[sub_resource] blocks for `nodes` (choices first, like the editor writes them) + the node ids."""
    out = []
    node_refs = []
    for n in nodes:
        refs = []
        for i, c in enumerate(n.choices):
            cid = "%s%s_c%02d" % (prefix, n.id, i + 1)
            lines = ['[sub_resource type="Resource" id="%s"]' % cid, 'script = ExtResource("%s")' % choice_ext,
                     "text = " + q(c.text)]
            if c.next:
                lines.append('next = &"%s"' % c.next)
            if c.cond:
                lines.append("conditions = " + _arr(c.cond))
            if c.act:
                lines.append("actions = " + _arr(c.act))
            out.append("\n".join(lines))
            refs.append('SubResource("%s")' % cid)
        nid = "%snode_%s" % (prefix, n.id)
        lines = ['[sub_resource type="Resource" id="%s"]' % nid, 'script = ExtResource("%s")' % node_ext,
                 'id = &"%s"' % n.id, "text = " + q(n.text)]
        if refs:
            lines.append('choices = Array[ExtResource("%s")]([%s])' % (choice_ext, ", ".join(refs)))
        if n.cond:
            lines.append("conditions = " + _arr(n.cond))
        if n.fb:
            lines.append('fallback_next = &"%s"' % n.fb)
        if n.act:
            lines.append("actions = " + _arr(n.act))
        out.append("\n".join(lines))
        node_refs.append('SubResource("%s")' % nid)
    return out, node_refs


def write_new(path, dlg_id, speaker, start, nodes):
    ids = [n.id for n in nodes]
    assert len(ids) == len(set(ids)), "duplicate node ids in " + dlg_id
    blocks, refs = _blocks(nodes, dlg_id + "_", "1", "2")
    head = ('[gd_resource type="Resource" script_class="DialogueData" format=3]\n\n'
            '[ext_resource type="Script" path="%s" id="1"]\n'
            '[ext_resource type="Script" path="%s" id="2"]\n'
            '[ext_resource type="Script" path="%s" id="3"]\n' % (NODE_SCRIPT, CHOICE_SCRIPT, DATA_SCRIPT))
    res = ('[resource]\nscript = ExtResource("3")\nid = &"%s"\nspeaker_name = %s\nstart_node = &"%s"\n'
           'nodes = Array[ExtResource("1")]([%s])\n' % (dlg_id, q(speaker), start, ", ".join(refs)))
    with open(path, "w", encoding="utf-8") as f:
        f.write(head + "\n" + "\n\n".join(blocks) + "\n\n" + res)


def _ext_id(text, script):
    m = re.search(r'\[ext_resource type="Script" path="%s" id="([^"]+)"\]' % re.escape(script), text)
    assert m, "no ext_resource " + script
    return m.group(1)


def patch(path, prefix, nodes, menus=None, fallbacks=None, start=None, insert_before=None):
    """Adds `nodes` (ids unique), choices into existing nodes (menus = {node_id: [C, …]}, inserted before the
    gift / bye choices), changes fallback_next of existing nodes (fallbacks = {node_id: new_fb}) and the start
    node. Idempotent through `prefix` (e.g. "p8_")."""
    menus = menus or {}
    fallbacks = fallbacks or {}
    with open(path, encoding="utf-8") as f:
        text = f.read()
    node_ext = _ext_id(text, NODE_SCRIPT)
    choice_ext = _ext_id(text, CHOICE_SCRIPT)
    head, _, rest = text.partition("\n\n")
    parts = rest.split("\n\n")
    blocks = [p.strip("\n") for p in parts if p.strip()]
    # 1. Drop the blocks of an earlier run and every reference to them.
    keep = []
    for b in blocks:
        m = re.match(r'\[sub_resource type="Resource" id="([^"]+)"\]', b)
        if m and m.group(1).startswith(prefix):
            continue
        keep.append(b)
    blocks = keep
    ref_re = re.compile(r'(, )?SubResource\("%s[^"]*"\)(, )?' % re.escape(prefix))

    def _strip_refs(b):
        def repl(m):
            return ", " if (m.group(1) and m.group(2)) else ""
        return ref_re.sub(repl, b)
    blocks = [_strip_refs(b) for b in blocks]
    # Existing node ids → their block index.
    by_node = {}
    by_sub = {}
    for i, b in enumerate(blocks):
        m = re.match(r'\[sub_resource type="Resource" id="([^"]+)"\]', b)
        if m:
            by_sub[m.group(1)] = i
            mid = re.search(r'^id = &"([^"]+)"$', b, re.M)
            if mid and 'script = ExtResource("%s")' % node_ext in b:
                by_node[mid.group(1)] = i
    for n in nodes:
        assert n.id not in by_node, "%s: node %s exists" % (path, n.id)
    new_blocks, new_refs = _blocks(nodes, prefix, node_ext, choice_ext)
    # 2. Menu choices.
    for node_id, choices in menus.items():
        i = by_node[node_id]
        b = blocks[i]
        cb, crefs = [], []
        for k, c in enumerate(choices):
            cid = "%smenu_%s_%02d" % (prefix, node_id, k + 1)
            lines = ['[sub_resource type="Resource" id="%s"]' % cid, 'script = ExtResource("%s")' % choice_ext,
                     "text = " + q(c.text)]
            if c.next:
                lines.append('next = &"%s"' % c.next)
            if c.cond:
                lines.append("conditions = " + _arr(c.cond))
            if c.act:
                lines.append("actions = " + _arr(c.act))
            cb.append("\n".join(lines))
            crefs.append('SubResource("%s")' % cid)
        new_blocks = cb + new_blocks
        m = re.search(r'^choices = Array\[ExtResource\("[^"]+"\)\]\(\[(.*)\]\)$', b, re.M)
        existing = [r.strip() for r in m.group(1).split(",") if r.strip()] if m else []
        pos = len(existing)
        for k, r in enumerate(existing):
            sid = re.search(r'SubResource\("([^"]+)"\)', r).group(1)
            sb = blocks[by_sub[sid]] if sid in by_sub else ""
            if "open_gifts:" in sb or 'next = &"bye"' in sb or (insert_before and insert_before in sb):
                pos = k
                break
        merged = existing[:pos] + crefs + existing[pos:]
        line = 'choices = Array[ExtResource("%s")]([%s])' % (choice_ext, ", ".join(merged))
        if m:
            b = b[:m.start()] + line + b[m.end():]
        else:
            b = b.replace('text = ', line + "\ntext = ", 1) if False else b + "\n" + line
        blocks[i] = b
    # 3. Fallbacks of existing nodes.
    for node_id, fb in fallbacks.items():
        i = by_node[node_id]
        b = blocks[i]
        if re.search(r'^fallback_next = &"[^"]*"$', b, re.M):
            b = re.sub(r'^fallback_next = &"[^"]*"$', 'fallback_next = &"%s"' % fb, b, flags=re.M)
        else:
            b = b + '\nfallback_next = &"%s"' % fb
        blocks[i] = b
    # 4. The resource: new node refs, start node.
    ri = [i for i, b in enumerate(blocks) if b.startswith("[resource]")][0]
    res = blocks[ri]
    m = re.search(r'^nodes = Array\[ExtResource\("[^"]+"\)\]\(\[(.*)\]\)$', res, re.M)
    existing = [r.strip() for r in m.group(1).split(",") if r.strip()]
    res = res[:m.start()] + 'nodes = Array[ExtResource("%s")]([%s])' % (node_ext, ", ".join(existing + new_refs)) + res[m.end():]
    if start:
        res = re.sub(r'^start_node = &"[^"]*"$', 'start_node = &"%s"' % start, res, flags=re.M)
    blocks[ri] = res
    # New blocks right after the ext_resources: existing nodes (the menus) reference the new choices, and a
    # SubResource must be defined before it is used.
    first = 1 if blocks and blocks[0].startswith("[ext_resource") else 0
    out = blocks[:first] + new_blocks + blocks[first:]
    with open(path, "w", encoding="utf-8") as f:
        f.write(head + "\n\n" + "\n\n".join(out) + "\n")
