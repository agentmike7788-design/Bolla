#!/usr/bin/env python3
"""Tarifblatt Phase 10 (docs/PHASE10_DESIGN.md §2.4, P1): the coin values of the tariff, read from the data.

    python tools/economy/tariff_report.py                    # the table on stdout
    python tools/economy/tariff_report.py --check            # exit 1 if a P1 row of the data differs from the contract
    python tools/economy/tariff_report.py --update=docs/reviews/phase10_wip/balance.md
                                                             # replaces the block between the tarifblatt markers

Every row: # · Posten · Ort (data/…) · G9 („heute" of §2.4) · Phase 10 (contract) · Daten (read now) · Stand.
„Daten" is formatted exactly like tests/unit/test_tariff_sheet.gd formats it from the loaded resources – the test
compares the generated block in balance.md with the data, row by row (so the sheet can never drift from the data).
Stand: ✓ = data = contract · „mit P2" / „P4" / „P5" = the owner's package brings it · „offen" = see balance.md.
Only the standard library; the .tres reader understands what the economy data use (numbers, strings, StringNames,
Packed*Array, typed Array / Dictionary, nested dictionaries).
"""
from __future__ import annotations

import ast
import glob
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BEGIN = "<!-- tarifblatt:begin (tools/economy/tariff_report.py) -->"
END = "<!-- tarifblatt:end -->"

# Small hill requests (§2.4.1 E8): 1 coin for at most 40 minutes of work, 2 for longer. The minutes are the work the
# request itself asks for beyond the daily duty (gathering, crafting, the act), from the gather / recipe / care data.
SMALL_MINUTES = {
    "hr_brandt_grave": 25, "hr_esch_stone": 30, "hr_esch_vase": 45, "hr_fenner_clear": 40, "hr_fenner_stone": 60,
    "hr_kehr_gate": 30, "hr_lenz_ghost": 30, "hr_lenz_stone": 60, "hr_liesel_paths": 30, "hr_liesel_wash": 25,
    "hr_mangold_bench": 55, "hr_osric_laidout": 35, "hr_osric_wood": 60, "hr_ott_ghost": 30, "hr_quast_exam": 0,
    "hr_rosine_leaves": 40, "hr_rosine_wood": 60, "hr_sieber_cross": 75,
}
SMALL_LIMIT = 40


# --- a small .tres reader ----------------------------------------------------------------------------------------

def _to_python(text: str):
    t = text.strip()
    t = re.sub(r'&"', '"', t)
    t = re.sub(r'\b(ExtResource|SubResource)\("([^"]*)"\)', r'"\1:\2"', t)
    t = re.sub(r'\b(?:Packed\w+Array|Dictionary\[[^\]]*\]|Array\[[^\]]*\]|Dictionary|Array)\(', '(', t)
    t = re.sub(r'\b(?:Vector2i|Vector2|Vector3|Color)\(', '(', t)
    t = re.sub(r'\btrue\b', 'True', t)
    t = re.sub(r'\bfalse\b', 'False', t)
    t = re.sub(r'\bnull\b', 'None', t)
    v = ast.literal_eval(t)
    return v


def read_tres(path: str) -> dict:
    """{"resource": {prop: value}, "sub": {id: {prop: value}}} of a text resource."""
    full = os.path.join(ROOT, path)
    out = {"resource": {}, "sub": {}}
    current = None
    name = None
    buf: list[str] = []

    def flush():
        nonlocal name, buf
        if current is not None and name is not None:
            try:
                current[name] = _to_python("\n".join(buf))
            except (ValueError, SyntaxError):
                current[name] = "\n".join(buf)
        name, buf = None, []

    with open(full, encoding="utf-8") as f:
        for line in f.read().splitlines():
            if line.startswith("["):
                flush()
                m = re.match(r'\[sub_resource [^\]]*id="([^"]+)"', line)
                if m:
                    current = out["sub"].setdefault(m.group(1), {})
                elif line.startswith("[resource]"):
                    current = out["resource"]
                else:
                    current = None
                continue
            m = re.match(r'^([A-Za-z_]\w*) = (.*)$', line)
            if m and current is not None:
                flush()
                name, buf = m.group(1), [m.group(2)]
            elif name is not None:
                buf.append(line)
    flush()
    return out


def res(path: str) -> dict:
    return read_tres(path)["resource"]


# --- formatting (same as test_tariff_sheet.gd) ---------------------------------------------------------------------

def fmt_num(v) -> str:
    if isinstance(v, float):
        s = ("%.2f" % v).rstrip("0").rstrip(".")
        return s.replace(".", ",")
    return str(v)


def fmt_list(values) -> str:
    return "/".join(fmt_num(v) for v in values)


def fmt_range(values) -> str:
    values = list(values)
    if not values:
        return "–"
    lo, hi = min(values), max(values)
    return fmt_num(lo) if lo == hi else "%s–%s" % (fmt_num(lo), fmt_num(hi))


def fmt_avg(values) -> str:
    values = list(values)
    return ("%.2f" % (sum(values) / len(values))).replace(".", ",") if values else "–"


# --- the rows --------------------------------------------------------------------------------------------------------

def _hill(pattern: str) -> dict:
    out = {}
    for f in sorted(glob.glob(os.path.join(ROOT, pattern))):
        r = read_tres(os.path.relpath(f, ROOT))["resource"]
        out[os.path.basename(f)[:-5]] = int(r.get("reward_coins", 0))
    return out


def small_requests() -> str:
    d = _hill("data/hill_requests/hr_*.tres")
    return "%s (Ø %s)" % (fmt_range(d.values()), fmt_avg(d.values()))


def small_requests_ok() -> bool:
    d = _hill("data/hill_requests/hr_*.tres")
    return all(d.get(k) == (1 if m <= SMALL_LIMIT else 2) for k, m in SMALL_MINUTES.items()) and set(d) == set(SMALL_MINUTES)


def large(prefix: str) -> str:
    return fmt_range(_hill("data/hill_requests/large/%s_*.tres" % prefix).values())


def orders_range() -> str:
    vals = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data/orders/o*_*.tres"))):
        base = os.path.basename(f)
        if not (base.startswith("o_") or base.startswith("ob_")):
            continue
        v = int(read_tres(os.path.relpath(f, ROOT))["resource"].get("reward_coins", 0))
        if v > 0:
            vals.append(v)
    return fmt_range(vals)


def shop_buys_range() -> str:
    vals = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data/shops/*.tres"))):
        buys = read_tres(os.path.relpath(f, ROOT))["resource"].get("buys", {})
        if isinstance(buys, dict):
            vals += [int(v.get("price", 0)) for v in buys.values() if isinstance(v, dict)]
    return fmt_range(vals)


def shop_price(shop: str, item: str) -> str:
    sells = res("data/shops/%s.tres" % shop).get("sells", {})
    return fmt_num(sells[item]["price"]) if item in sells else "–"


def organs(names) -> str:
    o = res("data/config/anatomy_config.tres").get("organs", {})
    return fmt_list(o[n]["base_price"] for n in names)


def lecture_fee() -> str:
    return fmt_num(res("data/config/anatomy_config.tres")["lecture"]["fee"])


def license_price() -> str:
    raw = open(os.path.join(ROOT, "data/dialogue/carter.tres"), encoding="utf-8").read()
    m = re.search(r'take_item:coin:(\d+):license', raw)
    return m.group(1) if m else "0"


def stations() -> str:
    return fmt_list(res("data/stations/%s.tres" % s)["build_coins"] for s in ("forge", "loom", "mason", "pult"))


def buildings() -> str:
    parts = []
    for b in ("shed", "chapel", "crypt"):
        t = read_tres("data/buildings/%s.tres" % b)
        coins = [int(v.get("coins", 0)) for k, v in sorted(t["sub"].items()) if k.startswith("level_")]
        parts.append("%s %s" % (b, fmt_list(coins)))
    return " · ".join(parts)


def wares() -> str:
    files = sorted(glob.glob(os.path.join(ROOT, "data/market/wares/*.tres")))
    if not files:
        return "–"
    out = []
    for f in files:
        r = read_tres(os.path.relpath(f, ROOT))["resource"]
        out.append("%s %s" % (r.get("item", "?"), fmt_num(r.get("value", 0))))
    return " · ".join(out)


def agathe(items) -> str:
    f = "data/market/stalls/ms_agathe.tres"
    if not os.path.exists(os.path.join(ROOT, f)):
        return "–"
    t = read_tres(f)
    prices = {v.get("item"): v.get("price") for v in t["sub"].values() if "item" in v}
    return fmt_list(prices.get(i, "–") for i in items)


def cfg(name: str) -> dict:
    return res("data/config/%s.tres" % name)


def treasury(*keys) -> str:
    c = cfg("treasury_config")
    return fmt_list(c[k] for k in keys)


# (id, Posten, Ort, G9, Phase 10, data getter, owner / Stand when it differs, check: None = data == contract)
ROWS = [
    ("E1", "Pflegegeld je Tag nach Ruf", "config/reputation_config `stipend`", "0/1/2/3/4", "0/0/0/0/0",
     lambda: fmt_list(cfg("reputation_config")["stipend"]), "mit P2", None),
    ("E1b", "Pflegegeld-Kappe", "config/reputation_config `stipend_purse_cap`", "80", "0",
     lambda: fmt_num(cfg("reputation_config")["stipend_purse_cap"]), "mit P2", None),
    ("E2", "Friedhofsgeld je Stufe/Woche", "config/treasury_config `tier_pay`", "–", "0/4/7/10/12",
     lambda: fmt_list(cfg("treasury_config")["tier_pay"][t] for t in ("neglected", "orderly", "tended", "dignified", "venerable")), "P2", None),
    ("E2b", "Pflegezuschlag ab Anteil · Kappe", "config/treasury_config `care_steps`, `quality_cap`", "–", "0,5/0,75/0,95/15",
     lambda: fmt_list(list(cfg("treasury_config")["care_steps"]) + [cfg("treasury_config")["quality_cap"]]), "P2", None),
    ("E2c", "Bedarfszulage Schwelle/Teiler/Kappe", "config/treasury_config `need_*`", "–", "60/4/15",
     lambda: treasury("need_threshold", "need_divisor", "need_cap"), "P2", None),
    ("E2d", "Notgroschen bis/Kappe", "config/treasury_config `hardship_*`", "–", "10/8",
     lambda: treasury("hardship_floor", "hardship_cap"), "P2", None),
    ("E3", "Bestattungslohn Grund", "corpses/corpse_tables `base_payment`", "2–4", "2–4",
     lambda: fmt_range(c["base_payment"] for c in res("data/corpses/corpse_tables.tres")["causes"] if c.get("weight", 0) > 0), "", None),
    ("E4", "Lohn je Qualitätspunkt", "config/economy_config `payment_per_quality`", "0,5", "0,5",
     lambda: fmt_num(cfg("economy_config")["payment_per_quality"]), "", None),
    ("E5", "Ruf-Zuschlag auf den Lohn", "config/reputation_config `pay_bonus`", "-2/0/1/2/3", "-2/0/1/2/2",
     lambda: fmt_list(cfg("reputation_config")["pay_bonus"]), "", None),
    ("E6", "Aussegnung Kapelle 1/2/3", "config/chapel_config `service_fee_by_level`", "3/5/7", "3/5/6",
     lambda: fmt_list(cfg("chapel_config")["service_fee_by_level"][1:]), "", None),
    ("E7", "Umbettgeld · Geistergabe", "config/crypt_config `reinter_fee`, ghost_config `gift_coins`", "4/2", "4/2",
     lambda: fmt_list([cfg("crypt_config")["reinter_fee"], cfg("ghost_config")["gift_coins"]]), "", None),
    ("E7b", "Weihe fremd/bekannt/vertraut/befreundet", "config/village_config `consecration_price_by_tier`", "10/10/5/0",
     "10/10/5/0", lambda: fmt_list(cfg("village_config")["consecration_price_by_tier"][t]
                                   for t in ("stranger", "acquainted", "trusted", "friend")), "", None),
    ("E8", "Kleine Bitten", "hill_requests/hr_* `reward_coins`", "1–3 (Ø 1,78)", "1–2: 1 bis 40 Min Arbeit, 2 länger",
     small_requests, "", small_requests_ok),
    ("E9", "Große Bitten Tor", "hill_requests/large/hrl_* `reward_coins`", "2–3", "2",
     lambda: large("hrl"), "", None),
    ("E9b", "Große Bitten Dorf", "hill_requests/large/hrv_* `reward_coins`", "3–5", "3–4",
     lambda: large("hrv"), "", None),
    ("E10", "Aufträge im Dorf", "orders/o_*, ob_* `reward_coins`", "3–11", "3–11", orders_range, "", None),
    ("E11", "Trinkgeld-Kappe je Tag", "config/visitor_config `tip_cap_day`", "4", "3",
     lambda: fmt_num(cfg("visitor_config")["tip_cap_day"]), "", None),
    ("E11b", "Opferstock je Besuch · Kappe/Tag", "config/visitor_config `poor_box_*`", "–", "1/2",
     lambda: fmt_list([cfg("visitor_config")["poor_box_coin"], cfg("visitor_config")["poor_box_cap_day"]]), "P2", None),
    ("E12", "Ilse: Zopf · Zähne", "config/utilization_config `sell_prices`", "4/5", "3/4",
     lambda: fmt_list([cfg("utilization_config")["sell_prices"]["hair_braid"], cfg("utilization_config")["sell_prices"]["teeth_pouch"]]), "", None),
    ("E12b", "Ilse: Aufschlag je Stück nach Pietät", "config/piety_config `buyer_bonus_by_tier`", "1/1/0/0/0", "1/1/0/0/0",
     lambda: fmt_list(cfg("piety_config")["buyer_bonus_by_tier"]), "offen", None),
    ("E13", "Wertsachen im Saum", "corpses/corpse_tables `valuables_coins_*`", "5–8", "4–7",
     lambda: "%s–%s" % (res("data/corpses/corpse_tables.tres")["valuables_coins_min"], res("data/corpses/corpse_tables.tres")["valuables_coins_max"]), "", None),
    ("E14", "Quast: Augen · Hand · Herz", "config/anatomy_config `organs.*.base_price`", "11/12/9", "10/11/8",
     lambda: organs(("eyes", "hand", "heart")), "", None),
    ("E14b", "Vorlesungshonorar", "config/anatomy_config `lecture.fee`", "4", "4", lecture_fee, "", None),
    ("E15", "Brenneisen: Kladde · Schweigen", "config/stranger_config `kladde_price`, `bribe_coins`", "40/15", "40/15",
     lambda: fmt_list([cfg("stranger_config")["kladde_price"], cfg("stranger_config")["bribe_coins"]]), "", None),
    ("E17", "Läden kaufen an", "shops/* `buys.price`", "1–8", "1–8", shop_buys_range, "", None),
    ("E18", "Eigener Stand: Grundwerte", "market/wares/*", "–", "wooden_cross 4 · herbs 1 · herb_bundle 3 · grave_candle 1 · wax_wreath 6",
     wares, "P4", None),
    ("A1", "Steinbruchbrief → Pachtbrief", "dialogue/carter `p5_license`", "20", "0", license_price, "P5", None),
    ("A2", "Stationen Esse/Webstuhl/Steinmetz/Pult", "stations/* `build_coins`", "25/10/15/12", "25/10/15/12", stations, "", None),
    ("A2b", "Gebäude je Stufe", "buildings/* `levels.coins`", "shed 10/15/20 · chapel 25/30/40 · crypt 0/35/35",
     "shed 10/15/20 · chapel 25/30/40 · crypt 0/35/35", buildings, "", None),
    ("A3", "Honigkuchen (Theres)", "shops/grocer `honey_cake`", "1", "2", lambda: shop_price("grocer", "honey_cake"), "", None),
    ("A3b", "Grabgitter (Esch)", "shops/smith `mortsafe`", "12", "12", lambda: shop_price("smith", "mortsafe"), "", None),
    ("A4", "Lehrling je Tag", "config/apprentice_config `wage`", "3", "3", lambda: fmt_num(cfg("apprentice_config")["wage"]), "", None),
    ("A5", "Runde · Spendenschritt · Postgeld", "config/village_config `round_price`, `donation_step`, letters_config `postage`",
     "5/5/1", "5/5/1", lambda: fmt_list([cfg("village_config")["round_price"], cfg("village_config")["donation_step"],
                                         cfg("letters_config")["postage"]]), "", None),
    ("A6", "Ilses Nachtware Leinen/Wacholder/Gold", "config/trader_config `shop`", "2/1/6", "2/1/6",
     lambda: fmt_list(cfg("trader_config")["shop"][k]["price"] for k in ("linen", "juniper", "gold_leaf")), "", None),
    ("A7", "Pacht je Monat", "config/treasury_config `rent`", "–", "8", lambda: treasury("rent"), "P2", None),
    ("A8", "Zehnt % · Kappe", "config/treasury_config `tithe_*`", "–", "10/25", lambda: treasury("tithe_percent", "tithe_cap"), "P2", None),
    ("A9", "Schätzung % · ab · Kappe", "config/treasury_config `estimate_*`", "–", "10/20/15",
     lambda: treasury("estimate_percent", "estimate_min_untracked", "estimate_cap"), "P2", None),
    ("A10", "Standgeld je Markttag", "config/market_config `stall_fee`", "–", "1",
     lambda: fmt_num(cfg("market_config")["stall_fee"]), "P4", None),
    ("A11", "Rosenstock · Messinglaterne (Agathe)", "market/stalls/ms_agathe", "–", "12/10",
     lambda: agathe(("rose_bush", "brass_lantern")), "P4", None),
]


def rows():
    out = []
    for (rid, posten, ort, g9, p10, get, owner, check) in ROWS:
        try:
            data = get()
        except (KeyError, FileNotFoundError, IndexError, TypeError):
            data = "–"
        ok = check() if check is not None else data == p10
        stand = "✓" if ok else (owner or "✗")
        out.append((rid, posten, ort, g9, p10, data, stand, ok, owner))
    return out


def table() -> str:
    lines = ["| # | Posten | Ort (`data/…`) | G9 | Phase 10 (Vertrag) | Daten | Stand |", "|---|---|---|---|---|---|---|"]
    for (rid, posten, ort, g9, p10, data, stand, _ok, _owner) in rows():
        lines.append("| %s | %s | %s | %s | %s | %s | %s |" % (rid, posten, ort, g9, p10, data, stand))
    return "\n".join(lines) + "\n"


def main(argv) -> int:
    update = ""
    check = False
    for a in argv:
        if a.startswith("--update="):
            update = a.split("=", 1)[1]
        elif a == "--check":
            check = True
    text = table()
    if update:
        path = os.path.join(ROOT, update) if not os.path.isabs(update) else update
        doc = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
        block = BEGIN + "\n" + text + END
        if BEGIN in doc and END in doc:
            doc = doc[:doc.index(BEGIN)] + block + doc[doc.index(END) + len(END):]
        else:
            doc = doc + ("\n" if doc and not doc.endswith("\n") else "") + "\n" + block + "\n"
        open(path, "w", encoding="utf-8").write(doc)
    else:
        sys.stdout.write(text)
    if check:
        bad = [r for r in rows() if not r[7] and r[8] == ""]
        for r in bad:
            sys.stderr.write("tariff: %s %s – data %s, contract %s\n" % (r[0], r[1], r[5], r[4]))
        return 1 if bad else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
