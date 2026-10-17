"""Phase 9 remarks of the villagers (docs/PHASE9_DESIGN.md §2.2.8 „Gerede", §2.4.2, §2.5.2; P6 – the texts of the villagers).

    python3 tools/dialogue/build_phase9_remarks.py

Adds the event remarks of Phase 9 to data/village/villagers/<npc>.tres (VillagerData.remarks, key event_<event>; the
reaction days are NpcLifeConfig.reactions: q_sent_away / q_stayed / q_public 3 days, letter_delivered / register_sold 2):
  q_sent_away      – ending A „Über den Hügel" (H6 away)
  q_stayed         – ending B „Bei Grete" (H6 stay)
  q_public         – ending C „Vor der Gemeinde" (H6 public)
  letter_delivered – a letter from a pocket reached the living (Letters, P3)
  register_sold    – a copy of the register went to Brenneisen (Stranger, P5; Rosine tells it two days later)
Idempotent: the keys are replaced on a re-run; every other remark stays as it is.
"""
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VIL = os.path.join(ROOT, "data", "village", "villagers")

REMARKS = {
    "innkeeper": {
        "q_sent_away": "Der alte Sieber ist fort, sagt Anna. Mit einem Bündel. Bei mir hat er nie was getrunken. Jetzt kann er's "
                       "nicht mehr nachholen. Oder woanders.",
        "q_stayed": "Du hast beim Sieber gesessen, sagt Anna. Zwei Abende. Das macht keiner. Nicht mal ich, und ich sitz gern.",
        "q_public": "Fenner hat einen Wächter vor die Siebers gestellt. Jetzt schließen alle ihre Läden zu, sobald es dunkel ist. "
                    "Und trinken drinnen. Mir soll's recht sein.",
        "letter_delivered": "Den Zettel vom Fuhrknecht hab ich hinter den Schanktisch gehängt. Die Leute fragen. Ich sag: Schulden. "
                            "Stimmt ja auch.",
        "register_sold": "Der Herr aus der Stadt hat ein Heft mit Namen bei sich. Unserem Friedhof seine Namen. Ich hab's gesehen, "
                         "er schreibt beim Essen darin. Das erzähl ich dem Pfarrer. Ich erzähl's jedem.",
    },
    "smith": {
        "q_sent_away": "Der Sieber ist fort. Gut zu Fuß war er nie. Ich hätt ihm einen Stock beschlagen, wenn er gefragt hätt.",
        "q_stayed": "Du sitzt beim Sieber, hör ich. Recht so. Einer muss sitzen, wenn einer geht.",
        "q_public": "Ein Wächter vor der Tür eines Sterbenden. Fenner meint's gut. Ich mein, man lässt einen in Ruh sterben.",
    },
    "grocer": {
        "q_sent_away": "Johann Sieber hat bei mir Brot für drei Tage gekauft. Bar. Er hat noch nie bar gezahlt. Jetzt weiß ich, "
                       "warum.",
        "q_stayed": "Anna kauft wieder Honig. Für den Alten. Er mag ihn nicht, aber er isst ihn, damit sie Ruhe gibt.",
        "q_public": "Seit der Wächter steht, kauft keiner mehr Lampenöl. Als wäre das Licht ansteckend. Das ist schlecht fürs "
                    "Geschäft und gut für die Dunkelheit.",
        "letter_delivered": "Ich hab Mutters Rezept ausprobiert. Es wird erst zu Lichtmess fertig. Wie es sich gehört.",
    },
    "priest": {
        "q_sent_away": "Johann ist fortgegangen, ohne Segen. Ich hätte ihm einen mitgegeben. Er hätte gesagt, der ist zu "
                       "schwer. Vielleicht hat er recht.",
        "q_stayed": "Ich war bei Johann. Er hat mir Grete beschrieben, eine Stunde lang. Ich kenne sie jetzt besser als manche, die "
                    "ich getraut habe.",
        "q_public": "Sie haben mich vor Fenner gestellt. Ich war trotzdem da. Ich bin immer da. Das hätten Sie auch so erfahren.",
        "letter_delivered": "Der Opferstock hat einen Gulden mehr, als im Buch steht. Ich lasse es so. Gott rechnet anders.",
        "register_sold": "Man hat mir erzählt, das Register ist jetzt in der Stadt. Abgeschrieben. Die Toten haben nicht "
                         "unterschrieben, Totengräber. Ich auch nicht.",
    },
    "mayor": {
        "q_sent_away": "Leute fortschicken ist nicht Ihr Amt, Totengräber. Es ist auch nicht meins. Ich habe ihn als verzogen "
                       "eingetragen. Unbekannt wohin.",
        "q_stayed": "Johann Sieber hat mir gesagt, er bekommt den Platz neben seiner Frau. Ich habe genickt. Ich nicke selten "
                    "ohne Akte.",
        "q_public": "Das Lichterbuch hat einen Eintrag. Einen. Ich hoffe, es bleibt dünn. Ein dünnes Buch ist ein gutes Buch.",
        "register_sold": "Eine Abschrift des Grabregisters, in der Stadt. Ohne Siegel. Ohne Genehmigung. Ich sage nichts. Noch "
                         "nicht.",
    },
    "surgeon": {
        "q_sent_away": "Johann ist fort, sagt man. Ich hatte ihm Tropfen gerichtet. Ich habe sie behalten. Vielleicht braucht "
                       "sie ein anderer. Es braucht sie immer ein anderer.",
        "q_stayed": "Zwei Abende auf einer Bank. Das hilft mehr als meine Tropfen. Schreiben Sie das nicht auf, sonst glaubt "
                    "es einer.",
        "q_public": "Der Wächter hat mich notiert. Quast, Wundarzt, zehn nach elf. Seit dreißig Jahren um zehn nach elf. Jetzt "
                    "bin ich verdächtig, weil ich pünktlich bin.",
    },
    "washer": {
        "q_sent_away": "Lorenz hat sie auch fortgeschickt. Nicht alle sind angekommen. Ich bete nicht dafür. Ich wasche nur, "
                       "und für ihn gibt es nichts zu waschen. Das ist gut.",
        "q_stayed": "Ich habe zwei Abende mit euch gesessen und nichts gesagt. Das war das Beste, was ich je für einen getan "
                    "habe, der noch lebt.",
        "q_public": "Fenner hat meinen Namen neben die Nacht geschrieben. Ich wasche trotzdem. Die Toten lesen kein Lichterbuch.",
    },
}


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("'", "\\'")


def patch(npc, lines):
    path = os.path.join(VIL, npc + ".tres")
    with open(path, encoding="utf-8") as f:
        text = f.read()
    m = re.search(r'^remarks = Dictionary\[StringName, PackedStringArray\]\(\{\n(.*?)\n\}\)$', text, re.M | re.S)
    assert m, npc + ": no remarks block"
    entries = [e for e in m.group(1).split("\n") if e.strip()]
    keep = []
    for e in entries:
        key = re.match(r'&"([^"]+)"', e).group(1)
        if key[len("event_"):] in lines and key.startswith("event_"):
            continue
        keep.append(e.rstrip(","))
    for event, line in lines.items():
        keep.append('&"event_%s": PackedStringArray("%s")' % (event, esc(line)))
    keep.sort(key=lambda e: re.match(r'&"([^"]+)"', e).group(1))
    block = "remarks = Dictionary[StringName, PackedStringArray]({\n" + ",\n".join(keep) + "\n})"
    text = text[:m.start()] + block + text[m.end():]
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    for npc, lines in REMARKS.items():
        patch(npc, lines)


if __name__ == "__main__":
    main()
