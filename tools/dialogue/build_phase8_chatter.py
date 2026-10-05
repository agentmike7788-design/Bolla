"""Phase 8 chatter (docs/PHASE8_DESIGN.md §2.1.2; P6 writes the texts of data/npc_life/chatter/*).

    python3 tools/dialogue/build_phase8_chatter.py

Takes the W0 templates (tests/fixtures/phase8/chatter/*.tres: who, where, when, conditions) and writes
data/npc_life/chatter/<id>.tres with 3–4 lines each (alternating npcs[0] / npcs[1], the leading lines first).
"""
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "tests", "fixtures", "phase8", "chatter")
DST = os.path.join(ROOT, "data", "npc_life", "chatter")

LINES = {
    "ch_well_spin": ["Du spinnst zu dünn, Dorn. Das reißt.", "Für die Toten reicht's. Die ziehen nicht dran.",
                     "Und wenn doch einer zieht?", "Dann hat er's eilig. Dann soll es reißen."],
    "ch_linden_bench": ["Der Brunnen hält, Esch.", "Der hält länger als wir.", "Das schreibe ich nicht ins Protokoll.",
                        "Musst du nicht. Steht schon im Stein."],
    "ch_inn_council": ["Wieder drei im Sterbebuch diesen Monat, Hochwürden.", "Ich zähle nicht, Fenner. Ich schreibe.",
                       "Einer muss ja zählen.", "Dann zählen Sie. Ich bete hinterher."],
    "ch_inn_carter": ["Faulhaber, du riechst nach Hügel.", "Der Hügel riecht nach mir. Das ist was anderes.",
                      "Setz dich ans Fenster. Da zieht's wenigstens."],
    "ch_bridge_water": ["Sie schauen jeden Abend ins Wasser, Doktor.", "Und Sie jeden Abend mir zu.", "Einer muss ja.",
                        "Muss er nicht, Veit. Er tut es nur."],
    "ch_church_alms": ["Hast du gegessen, Veit?", "Gestern, Hochwürden. Ich spar mir den Rest.",
                       "Dann iss heute. Der Rest wird nicht mehr."],
    "ch_rumor_robber": ["Drüben bei Ellbach haben sie wieder eins offen gefunden.",
                        "Bei uns nicht. Bei uns liegt einer auf dem Hügel, der nicht schläft.", "Der Totengräber?",
                        "Wer sonst. Die Toten schlafen ja."],
    "ch_inn_jakob": ["Hast du dir die Hände gewaschen?", "Zweimal. Die Erde geht nicht ab.", "Dann ein drittes Mal.",
                     "Mutter. Die geht nicht ab. Das ist so bei uns oben."],
    "ch_gate_jakob": ["Was bringst du heute, Herr Faulhaber?", "Heute nichts, Junge. Freu dich nicht zu früh.",
                      "Ich freu mich nicht. Ich frag nur.", "Das ist bei dir dasselbe."],
    "ch_grave_kehr": ["Ich mach nur das Laub weg, Frau Kehr.", "Mach nur. Er hat Laub nie leiden können.",
                      "Ich bin gleich wieder weg.", "Lass dir Zeit. Er hatte nie welche."],
    "ch_market_rival": ["Bei mir kostet der Zwirn einen.", "Bei Ihnen kostet er auch einen, wenn er reißt.",
                        "Bei mir reißt nichts.", "Herzchen, alles reißt. Die Frage ist nur, wann."],
    "ch_gate_peddler": ["Immer noch hier, Veit?", "Wo soll ich hin? Die Toten geben nichts, aber sie nehmen auch nichts.",
                        "Eine Kerze? Für deinen Bruder?", "Meine liegen im Wasser, Hanne."],
    "ch_smith_mayor": ["Ein Gitter für jedes frische Grab, Esch? Was kostet das die Gemeinde?", "Weniger als ein offenes.",
                       "Das ist keine Rechnung.", "Doch. Nur keine für dein Buch."],
    "ch_surgery_priest": ["Bei den Otts brennt Licht.", "Ich weiß. Ich war schon da.", "Dann gehe ich heute Abend.",
                          "Gehen Sie früh, Hochwürden. Spät ist bei denen schnell zu spät."],
    "ch_lights_prepare": ["Wie viele Kerzen dieses Jahr?", "Eine mehr als letztes. Wie jedes Jahr.",
                          "Letztes Jahr ist keiner hinaufgegangen.", "Dann eben zwei mehr."],
    "ch_after_lights": ["Oben brannte jedes Grab. Hat er alle selbst angezündet?", "Er und mein Junge.",
                        "Dein Junge? Der kann doch keine Kerze gerade halten.", "Oben schon."],
}
## The Otts' sick light in the text → the condition names the house (np_kehr has no such line).
CONDITIONS = {"ch_surgery_priest": ["sick_light:house_ott"]}


def q(s):
    return json.dumps(s, ensure_ascii=False)


def main():
    os.makedirs(DST, exist_ok=True)
    names = sorted(f for f in os.listdir(SRC) if f.endswith(".tres"))
    assert len(names) == 16, names
    for f in names:
        cid = f[:-5]
        text = open(os.path.join(SRC, f), encoding="utf-8").read()
        lines = LINES[cid]
        assert 2 <= len(lines) <= 4
        text = re.sub(r"^lines = PackedStringArray\(.*\)$", "lines = PackedStringArray(%s)" % ", ".join(q(x) for x in lines),
                      text, flags=re.M)
        if cid in CONDITIONS:
            text = re.sub(r"^conditions = PackedStringArray\(.*\)$",
                          "conditions = PackedStringArray(%s)" % ", ".join(q(x) for x in CONDITIONS[cid]), text, flags=re.M)
        with open(os.path.join(DST, f), "w", encoding="utf-8") as out:
            out.write(text)
    print("16 chatters written to", DST)


if __name__ == "__main__":
    main()
