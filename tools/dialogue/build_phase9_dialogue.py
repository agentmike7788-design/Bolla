"""Phase 9 dialogues (docs/PHASE9_DESIGN.md §1.2, §2.2–§2.5, §2.10, §2.11, §3.4; P6 owns data/dialogue/*).

    python3 tools/dialogue/build_phase9_dialogue.py

Writes the new dialogues (stranger – Cornelius Brenneisen, kin_sieber_v – Johann on the bench in the village, sieber_door –
Anna behind the Siebers' door) and patches the existing ones idempotently: every Phase-9 block carries the sub_resource
prefix "p9_" and is replaced on a re-run (the Phase-8 "p8_" blocks and G8 Runde 6 hill_* entries stay as they are).
Texts: German, dry, melancholic, warm; death is a craft, not horror (§ „Sprache"). The leading texts of §1–§2 are the basis.

Gates used everywhere:
  clue_known:c_q_dates     – Lorenz' list is known (H1) → the „[Die Liste]" lines
  quest_step:q_who_knows:… – the visible step of the main chain (P1's Quests)
  quest_ending:q_who_knows:<away|stay|public|silent> – the ending of H6 (reactions)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tres_dialogue import C, N, patch, write_new  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DLG = os.path.join(ROOT, "data", "dialogue")
P = "p9_"
LIST = "clue_known:c_q_dates"
MAIN = "q_who_knows"


def path(name):
    return os.path.join(DLG, name + ".tres")


def back(text="…", to="menu"):
    return [C(text, to)]


def ending(e):
    return "quest_ending:%s:%s" % (MAIN, e)


def once(flag):
    """Conditions + action of a line said once."""
    return ["!flag:%s" % flag], ["set_flag:%s" % flag]


def remark(node_id, text, conditions, flag, fb, extra_act=(), reply="…"):
    """A start-chain node said once when `conditions` hold (reactions to the endings, §2.2.8)."""
    cond, act = once(flag)
    return N(node_id, text, back(reply), list(conditions) + cond, fb, act + list(extra_act))


def witness(entry, npc, text, friend_text="", extra_nodes_cond=(), gate_extra=(), label=None):
    """§2.2.4: the „[Die Liste]" question to a witness (menu choice + node, + a friend-tier variant)."""
    label = label or "[Die Liste] Ein Licht, das keiner angezündet hat – haben Sie so eins gesehen?"
    gate = [LIST, "!light:%s:witnessed" % entry] + list(gate_extra)
    nodes = []
    if friend_text:
        menu = [C(label, "p9_witness_friend", gate)]
        nodes.append(N("p9_witness_friend", text + " " + friend_text, back("Danke."), ["rel_tier:%s:friend" % npc],
                       "p9_witness", ["witness:%s" % entry]))
    else:
        menu = [C(label, "p9_witness", gate)]
    nodes.append(N("p9_witness", text, back("Danke."), list(extra_nodes_cond), "", ["witness:%s" % entry]))
    return menu, nodes


def confide(npc, answer, underlined_extra=""):
    """§2.2.6 H5: „[Die Liste] Ich muss Ihnen etwas zeigen." – the choice confide_<npc> (Quests.choose runs its actions)."""
    menu = [C("[Die Liste] Ich muss Ihnen etwas zeigen.", "p9_confide", ["quest_step:%s:h5" % MAIN])]
    nodes = [N("p9_confide", "(Du zeigst die Rückseite der Kladde, die sechs Daten, das „S.“, und erzählst von den Lichtern.)",
               [C("Ich wollte, dass es einer weiß.", "p9_confide_yes", act=["quest_choose:%s:h5:confide_%s" % (MAIN, npc)]),
                C("Vergessen Sie es. Es ist nichts.", "menu")])]
    if underlined_extra:
        nodes.append(N("p9_confide_yes", answer + " " + underlined_extra, back("…"), ["underlined:washer"], "p9_confide_plain"))
        nodes.append(N("p9_confide_plain", answer, back("…")))
    else:
        nodes.append(N("p9_confide_yes", answer, back("…")))
    return menu, nodes


def named_publicly(npc, confided_line, named_line, fb):
    """§2.2.7 ending C: the three are named before the community (−4), the confidant of H5 is not."""
    return [
        N("p9_public_confidant", confided_line, back("…"), [ending("public"), "confided:%s" % npc, "!flag:p9_public_%s" % npc],
          "p9_public_named", ["set_flag:p9_public_%s" % npc]),
        N("p9_public_named", named_line, back("…"), [ending("public"), "!flag:p9_public_%s" % npc], fb,
          ["set_flag:p9_public_%s" % npc]),
    ]


def letter_menu(text_choice, node_text, cond=None, action="letter_deliver", reply="…"):
    """§2.4.2 „[Brief] Das lag in seiner Tasche." – the held letter to the speaker."""
    return ([C(text_choice, "p9_letter", (cond or ["letter_for:speaker"]), [action])],
            [N("p9_letter", node_text, back(reply))])


def post_menu(carrier, node_text):
    """§2.4.2 / §2.10: a letter for the town (or an answer) with the post – 1 coin postage."""
    return ([C("[Brief] Nimmst du den mit in die Stadt? (1 Münze)", "p9_post", ["letter_for:town", "has_item:coin:1"],
               ["letter_post:%s" % carrier]),
             C("[Brief] Nimmst du meine Antwort mit? (1 Münze)", "p9_post", ["!letter_for:town", "has_item:letter_reply:1",
                                                                             "has_item:coin:1"], ["letter_post:%s" % carrier])],
            [N("p9_post", node_text, back("Danke."))])


# --- Osric (carter.tres, carter_village.tres) ---------------------------------------------------------------

def carter():
    nodes = [
        N("p9_intro", "Der Pfarrer hat gefragt, ob du das Heft vom Aschau noch hast. Ich hab gesagt, ich frag nicht nach Heften. "
          "Und Fenner sagt, es gibt noch eine Reihe am Lindenacker. Die letzte, sagt er. Das hat er bei der dritten auch gesagt.",
          [C("Wer liest eigentlich die Post für die Toten?", "p9_post_who"), C("Gut.", "menu")],
          ["p9_open", "!flag:p9_intro"], "p9_away_soon", ["set_flag:p9_intro"]),
        N("p9_away_soon", "Der alte Sieber will fort, sagt das Dorf. Wenn die Vogelsang nicht vorher kommt, nehm ich ihn mit. "
          "Hinten auf der Ladefläche ist Platz, zwischen den Kisten. Bis Ellbach. Weiter fahr ich nicht. Ich frag nicht, warum.",
          back("Danke, Osric."), [ending("away"), "!sieber_gone", "!flag:p9_carter_away"], "p9_away_done",
          ["set_flag:p9_carter_away"]),
        N("p9_away_done", "Der alte Sieber ist fort, sagt das Dorf. Ich hab nicht gefragt, wohin. Man fragt einen nicht, der mit "
          "einem Bündel geht. Man nimmt ihm höchstens das Bündel ab.",
          back("…"), ["sieber_gone", "!flag:p9_carter_gone"], "p9_stranger_seen", ["set_flag:p9_carter_gone"]),
        N("p9_stranger_seen", "Da steht einer in einem Stadtrock unten am Tor. Glänzende Schuhe. Die sind nicht für den Hügel "
          "gemacht, und er weiß es. Er hat mich gefragt, wie schwer ein Sarg ist. Leer, hab ich gesagt. Er hat es aufgeschrieben.",
          back("Ich seh ihn mir an."), ["stranger_here", "!flag:p9_carter_stranger"], "p8_robber_seen",
          ["set_flag:p9_carter_stranger"]),
        N("p9_post_who", "Die Post weiß nicht, wer tot ist. Ich schon. Wenn welche für einen von oben kommt, bring ich sie dir. "
          "Lesen musst du sie selber. Oder auch nicht. Ich hab sie nur gefahren.", back("Bring sie mir.")),
        N("p9_witness", "Bei der Quendel brannte Licht, oben, um eins. Ich fahr da nachts vorbei, wenn ich aus Ellbach komme. "
          "Ich hab gedacht, die kann nicht schlafen. Ich halte nie an. Diesmal hätte ich vielleicht sollen.",
          back("Du hättest nichts ändern können."), [], "", ["witness:e_quendel"]),
        N("p9_cart", "Hinten auf der Ladefläche ist Platz. Zwischen den Kisten. Bis Ellbach. Weiter fahr ich nicht. "
          "Er soll sich warm anziehen, der Wind kommt auf der Höhe von vorn.", back("Ich sag's ihm.")),
        N("p9_post", "Bis Ellbach. Von da läuft's allein. Briefe sind wie Fahrgäste: Die meisten wissen, wohin sie wollen.",
          back("Danke, Osric.")),
    ]
    menu = [C("[Die Liste] Bei der Quendel, im Herbst – hast du nachts ein Licht gesehen?", "p9_witness",
              [LIST, "!light:e_quendel:witnessed"]),
            C("Nimmst du den alten Sieber mit, wenn er will?", "p9_cart", [ending("away"), "!sieber_gone"]),
            C("Wer liest eigentlich die Post für die Toten?", "p9_post_who", ["flag:p9_intro"]),
            C("[Brief] Nimmst du den mit in die Stadt? (1 Münze)", "p9_post", ["letter_for:town", "has_item:coin:1"],
              ["letter_post:carter"]),
            C("[Brief] Nimmst du meine Antwort mit? (1 Münze)", "p9_post", ["!letter_for:town", "has_item:letter_reply:1",
                                                                           "has_item:coin:1"], ["letter_post:carter"]),
            C("[Bitte] Das hier ist für die große Bitte.", "hill_handed", ["large_ready:carter", "!hill_ready:carter"],
              ["large_turn_in:carter"])]
    patch(path("carter"), P, nodes, {"menu": menu}, {"p8_intro": "p9_intro"}, insert_before='next = &"goodbye')


def carter_village():
    nodes = [
        N("p9_witness", "Bei der Quendel brannte Licht, oben, um eins. Ich komm da nachts vorbei, aus Ellbach. Ich hab gedacht, "
          "die kann nicht schlafen. Ich halte nie an. Diesmal hätte ich vielleicht sollen.",
          back("Du hättest nichts ändern können."), [], "", ["witness:e_quendel"]),
        N("p9_post", "Bis Ellbach. Von da läuft's allein.", back("Danke, Osric.")),
    ]
    menu = [C("[Die Liste] Bei der Quendel, im Herbst – hast du nachts ein Licht gesehen?", "p9_witness",
              [LIST, "!light:e_quendel:witnessed"]),
            C("[Brief] Nimmst du den mit in die Stadt? (1 Münze)", "p9_post", ["letter_for:town", "has_item:coin:1"],
              ["letter_post:carter"])]
    patch(path("carter_village"), P, nodes, {"menu": menu}, {}, insert_before='text = "Mach\'s gut, Osric."')


# --- Veit (beggar.tres) ----------------------------------------------------------------------------------------

def beggar():
    nodes = [
        N("p9_gone", "Der alte Sieber ist fort. Ich hab ihm nachgewinkt. Er hat nicht zurückgewinkt. Das macht man so, wenn "
          "man nicht wiederkommt. Oder wenn man schlecht sieht. Bei ihm weiß ich's nicht.",
          back("…"), ["sieber_gone", "!flag:p9_veit_gone"], "grell", ["set_flag:p9_veit_gone"]),
        N("p9_witness", "Bei den Siebers. Oben beim Alten. Ich sitz nachts am Brunnen, ich seh die Fenster. Keiner hat es "
          "angezündet. Es war einfach da, und um fünf war es weg. In der Nacht nach dem ersten Frost. Da war's kalt.",
          [C("Bei Johann Sieber?", "p9_witness_who"), C("Danke, Veit.", "menu")], [], "", ["witness:e_open"]),
        N("p9_witness_who", "Beim Alten. Die Jungen schlafen unten, die haben ein Kind, das schreit. Oben schläft nur er. Er hat "
          "es nicht angezündet. Der zündet nichts an, der hat nicht mal eine Pfeife.", back("Ich geh hin.")),
        N("p9_case", "Der mit dem Koffer war schon mal da. Vor einem Jahr. Bei Lorenz. Lorenz hat ihn vom Hügel gejagt, mit der "
          "Schaufel. Ich hab gelacht. Ich lach selten. Darum weiß ich es noch.",
          back("Danke, Veit."), ["!robber_fate:let_go"], "p9_case_lambert", ["set_flag:q_case_known"]),
        N("p9_case_lambert", "Der mit dem Koffer? Lambert lässt grüßen. Er sagt, der war's. Der hat ihn bezahlt, für jedes frische "
          "Grab einen Taler. Und vor einem Jahr war er schon bei Lorenz. Lorenz hat ihn mit der Schaufel vom Hügel gejagt.",
          back("Danke, Veit."), [], "", ["set_flag:q_case_known"]),
        N("p9_lambert", "Für Lambert? Ich geh da sowieso vorbei. Er wohnt jetzt hinter der Ziegelei, bei den Hunden. Die Hunde "
          "mögen ihn. Das ist mehr, als man von den Leuten sagen kann.", back("Danke, Veit.")),
    ]
    menu = [C("[Die Liste] Du siehst nachts die Fenster. Hat im Nebelung irgendwo ein Licht gebrannt?", "p9_witness",
              [LIST, "!light:e_open:witnessed"]),
            C("Der Herr mit dem Koffer am Tor – kennst du ihn?", "p9_case", ["quest_step:q_case:k3", "!flag:q_case_known"]),
            C("[Brief] Der ist für Lambert Grell.", "p9_lambert", ["letter_for:robber"], ["letter_deliver:robber"])]
    patch(path("beggar"), P, nodes, {"menu": menu}, {"first": "p9_gone"}, insert_before='text = "(Gehen)"')


# --- Johann Sieber (kin_sieber.tres at Grete's grave, kin_sieber_v.tres on the bench) -------------------------

def johann_nodes(where):
    """The Phase-9 part of Johann's two dialogues (H4 mark, H6 the three ways, the endings, letters read aloud)."""
    to_grete = "(Zum Grab.) " if where == "grave" else ""
    nodes = [
        N("p9_away_wait", to_grete + "Morgen geh ich. Grete wartet, die wartet gern. Pass auf, dass keiner auf ihr Grab tritt. "
          "Und wenn einer fragt: Ich bin nicht fort. Ich bin nur nicht da.",
          back("Ich pass auf."), [ending("away"), "!sieber_gone"], "p9_silent"),
        N("p9_silent", "Du hast nichts gesagt. Das ist auch eine Antwort. Grete hat auch oft nichts gesagt, und ich hab's "
          "immer verstanden. Fast immer.", back("…"), [ending("silent"), "!flag:p9_johann_silent"], "p9_public",
          ["set_flag:p9_johann_silent"]),
        N("p9_public", "Da steht einer mit einer Laterne vor meiner Tür. Jede Nacht. Er hustet. Ich hab ihm eine Decke gegeben. "
          "Für mich hat noch nie einer Wache gestanden. Jetzt weiß ich nicht, ob ich mich freuen soll.",
          back("…"), [ending("public"), "!flag:p9_johann_public"], "p9_marked", ["set_flag:p9_johann_public"]),
        N("p9_marked", to_grete + "So, Grete. Er ist wieder da. Er will was. Ich seh's ihm an.", back("…"),
          ["sieber_marked"], "greet" if where == "grave" else "p9_bench"),
        N("p9_mark", "Das Licht? Ich hab's gesehen. Ich hab gedacht, Grete. Dann hab ich gedacht: Nein, die hat nie Licht "
          "gemacht, die hat im Dunkeln gestrickt. … (Er öffnet das Hemd ein Stück.) Da. Juckt nicht. Grete hatte so was nicht. "
          "Grete hatte nur Rücken.",
          [C("Die Hagedorn hatte das auch.", "p9_mark_count"), C("Danke, Johann.", "menu")], [], "", ["mark_seen"]),
        N("p9_mark_count", "Die Hagedorn hatte es auch. Und der Ott. Man redet nicht darüber, man zählt. Ich bin einundsiebzig. "
          "Ich kann zählen.", back("…")),
        N("p9_h6", "Ich weiß. Ich zähl auch. Ich bin nur langsamer als du. Also. Was soll ich machen, Totengräber? "
          "Du kennst dich aus mit dem, was danach kommt.",
          [C("Geh fort, Johann. Über den Hügel. Wie Lorenz.", "p9_away", ["letter_posted"]),
           C("Geh fort, Johann. Über den Hügel. Wie Lorenz.", "p9_away_no", ["!letter_posted"]),
           C("Bleib. Ich mach dir das Grab neben Grete.", "p9_stay", act=["quest_choose:%s:h6:stay" % MAIN]),
           C("Wir gehen zum Fenner. Das Dorf soll es wissen.", "p9_public_yes", act=["quest_choose:%s:h6:public" % MAIN]),
           C("Ich weiß es noch nicht.", "menu")]),
        N("p9_away", "Fort? Ich war nie fort. Ich war einmal in Ellbach, da hat es geregnet. … Was ist das? Den hat einer an "
          "unsere Tür gesteckt, sagt Anna. Ohne Namen.",
          [C("(Nicken.) Er ist für dich, Johann. Geh.", "p9_away_yes", act=["quest_choose:%s:h6:away" % MAIN]),
           C("Ich weiß es auch nicht.", "menu")]),
        N("p9_away_yes", "Ich kann nicht lesen. Aber ich kenn die Form. So einen hatte die Ida auch. Die ist gegangen. Na gut. "
          "Dann geh ich ein Stück. Grete wird schimpfen. Die schimpft gern, wenn ich weg bin. Dann hat sie was zu tun.",
          back("Ich pass auf ihr Grab auf.")),
        N("p9_away_no", "Fort? Ich war nie fort. Ich war einmal in Ellbach, da hat es geregnet. Nein, Totengräber. Du sagst das "
          "so. Einem Menschen glaub ich das nicht. Einem Brief vielleicht. Die Ida hatte einen.", back("…")),
        N("p9_stay", "Neben Grete. Oder so nah, wie du kannst. Sie mag es nicht, wenn man drängelt. Und setz dich mal abends zu "
          "mir auf die Bank. Ich red nicht viel. Du auch nicht. Das passt.", back("Ich komme.")),
        N("p9_public_yes", "Zum Fenner? Der schreibt alles auf. Dann steht wenigstens was über mich in einem Buch. Grete stand "
          "nur im Kirchenbuch. Zweimal. Einmal mit mir, einmal ohne.", back("…")),
        N("p9_letter", "Lies. Langsam. Ich hör nicht mehr so schnell, wie die Leute schreiben. … So. Jetzt weiß ich es. Leg ihn "
          "zu Grete, wenn du gehst. Sie hat Briefe immer aufgehoben, auch die vom Amt.", back("Mach ich.")),
        N("p9_stranger", "Der Herr aus der Stadt war da. Er sagt, er nimmt mich mit zu einem Arzt in der Stadt. Kostet nichts, "
          "sagt er. Mit dem? Der riecht nach Keller.", back("…")),
    ]
    menu = [
        C("[Die Liste] Das Licht bei euch oben, im Nebelung …", "p9_mark", ["clue_known:c_q_sieber", "!sieber_marked"]),
        C("[Die Liste] Es geht um das Licht, Johann.", "p9_h6", ["quest_step:%s:h6" % MAIN]),
        # §2.2.3 H5 „oder H6 direkt anfangen": telling nobody is the choice confide_none, then H6.
        C("[Die Liste] Es geht um das Licht, Johann. (Keinem sonst davon erzählen)", "p9_h6", ["quest_step:%s:h5" % MAIN],
          ["quest_choose:%s:h5:confide_none" % MAIN]),
        C("[Brief] Soll ich ihn Ihnen vorlesen?", "p9_letter", ["letter_for:speaker"], ["letter_read_aloud"]),
        C("Der Herr mit dem Koffer – was wollte er?", "p9_stranger", ["stranger_here", "quest_step:%s:h6" % MAIN]),
    ]
    return nodes, menu


def kin_sieber():
    nodes, menu = johann_nodes("grave")
    patch(path("kin_sieber"), P, nodes, {"menu": menu}, {"first": "p9_away_wait"}, insert_before='text = "Ich lass Sie allein."')


def kin_sieber_v():
    nodes, menu = johann_nodes("bench")
    menu.insert(0, C("[Abend] Ich setz mich zu Ihnen.", "p9_evening", ["order:oq_johann_evening:accepted", "time_between:1080:1200"],
                     ["meet:v_sieber_bench"]))
    nodes = [
        N("start", "(Johann sitzt auf der Bank vor dem Haus, den Stock zwischen den Knien.) Setz dich. Wenn du willst. "
          "Ich hab Zeit. Das ist das Einzige, was ich hab.", back("…"), ["!flag:p9_met_kin_sieber_v"], "p9_away_wait",
          ["set_flag:p9_met_kin_sieber_v"]),
        N("p9_bench", "(Johann rückt ein Stück zur Seite.) Die Bank hat Grete ausgesucht. Weil man von hier den Brunnen sieht "
          "und keiner einen sieht. Das hat sie gemocht.", back("…")),
        N("menu", "(Johann wartet. Er hat es nicht eilig.)", menu + [C("Ich lass Sie sitzen.", "")]),
        N("p9_evening", "Setz dich. Nicht so nah, ich bin kein Ofen. … Grete hat hier gesessen, jeden Abend, bis es zu kalt "
          "war. Dann hat sie drinnen am Fenster gesessen und so getan, als säße sie hier. Das war ihre Art.",
          [C("(Sitzen bleiben)", "")], ["!flag:p9_johann_evening_1"], "p9_evening_last", ["set_flag:p9_johann_evening_1"]),
        N("p9_evening_last", "Weißt du, was das Schlimme ist? Ich hab es nicht eilig. Und es hat es auch nicht eilig. Wir warten "
          "beide. … Morgen kommt der Quast, sagt Anna. Er kommt immer, wenn es so weit ist. Der weiß das auch.",
          [C("(Sitzen bleiben, bis es dunkel ist)", "")]),
    ] + nodes
    write_new(path("kin_sieber_v"), "kin_sieber_v", "Johann Sieber", "start", nodes)


# --- Anna Sieber behind the door (sieber_door.tres) -----------------------------------------------------------

def sieber_door():
    def door(thanks="(Gehen)"):
        return [C(thanks, ""), C("[Auftrag] Ein Bündel von Liesel.", "bundle", ["order_ready:oq_liesel_bundle"],
                                 ["order_turn_in:oq_liesel_bundle"])]
    nodes = [
        N("start", "(Hinter der Tür, ohne aufzumachen.) Vater ist fort. Er hat sein Bündel selber gepackt, zweimal, weil er beim "
          "ersten Mal Gretes Bild vergessen hat. Danke. Glaub ich. Ich weiß nicht, ob man dafür danke sagt.",
          back("(Gehen)", ""), ["sieber_gone"], "dead"),
        N("dead", "(Hinter der Tür.) Er ist heute Nacht gegangen. Liesel ist bei ihm. Sie singt nicht, sie wäscht nur. Komm später, "
          "Totengräber. Osric bringt ihn dir. Er hat gesagt, du sollst dich nicht beeilen.",
          back("(Gehen)", ""), ["flag:sieber_dead"], "public"),
        N("public", "(Hinter der Tür.) Der Wächter steht schon vor der Tür. Jetzt weiß es das ganze Dorf. Die Leute gehen auf der "
          "anderen Seite vorbei. Klopf nicht so laut, Vater schläft. Er schläft jetzt viel.",
          door(), [ending("public")], "stay"),
        N("stay", "(Hinter der Tür.) Du hast Vater was versprochen, sagt er. Er sagt nicht, was. Er pfeift wieder. Das hat er "
          "seit Grete nicht getan. Falsch, aber er pfeift.", door(), [ending("stay")], "light"),
        N("light", "(Hinter der Tür.) Wer ist da? … Der vom Hügel. Ein Licht? Bei Vater oben brannte es, im Nebelung. Er sagt, "
          "er war's nicht. Er lügt nie, der Alte. Er ist zu langsam zum Lügen. Er sitzt nachmittags auf der Bank. Oder bei Grete.",
          door("Danke, Anna."), [LIST], "plain", ["add_clue:c_q_sieber"]),
        N("plain", "(Hinter der Tür.) Wer ist da? … Ach, der vom Hügel. Bei uns ist keiner tot. Geh weiter, Totengräber, das "
          "bringt Unglück. Nichts für ungut.", door()),
        N("bundle", "(Die Tür geht einen Spalt auf. Eine Hand nimmt das Bündel.) Leinen. Für später. Ich weiß. Ich näh es nicht. "
          "Liesel näht es, wenn es so weit ist. Sie sagt, sie hat die besseren Stiche.", back("(Gehen)", "")),
    ]
    write_new(path("sieber_door"), "sieber_door", "Anna Sieber", "start", nodes)


# --- Cornelius Brenneisen (stranger.tres) ----------------------------------------------------------------------

QUESTIONS = [
    "Wie tief graben Sie im Frost, Herr Totengräber? Ich frage für ein Buch. Ein sehr trockenes Buch.",
    "Wer kommt zuerst, wenn einer stirbt? Der Pfarrer, der Wundarzt oder die Frau, die wäscht? In der Stadt ist es der Wirt. "
    "Er will wissen, wer die Rechnung zahlt.",
    "Haben Sie je einen gesehen, der drei Wochen vorher wusste, dass er geht?",
    "Wie schwer ist ein Mann nach drei Tagen im November? Ungefähr genügt. Ich runde selbst.",
    "Schreiben Sie auf, wann einer kommt, oder nur, wann er geht?",
    "Brennt bei Ihnen im Dorf nachts manchmal ein Licht, wo keiner wach ist?",
]


def stranger():
    nodes = [
        N("start", "(Ein Herr in einem Stadtrock lüftet den Zylinder.) Brenneisen. Aus der Stadt. Ich störe nicht lange. Ich frage "
          "nur. Fragen kostet nichts, Antworten zahle ich. … Ich warte hier. Ich bin nicht eingeladen.",
          back("Was wollen Sie wissen?"), ["!flag:p9_stranger_met"], "leaving", ["set_flag:p9_stranger_met"]),
        N("leaving", "Morgen fahre ich zurück, Herr Totengräber. Die Stadt erwartet mich. Sie erwartet immer jemanden. Bevor ich "
          "gehe: Was nehme ich mit?",
          [C("Nichts. Ich zeige Sie bei Fenner an.", "k5_fenner", act=["stranger_resolve:fenner"]),
           C("Reden wir über ein Geschäft.", "k5_deal_kladde", act=["stranger_resolve:deal"]),
           C("An der Westmauer kauft nachts eine Frau alles, was über der Erde liegt.", "k5_ilse", act=["stranger_resolve:ilse"]),
           C("Darüber reden wir noch.", "menu")],
          ["quest_step:q_case:k5"], "greet"),
        N("greet", "Herr Totengräber. (Er tippt an den Zylinder.) Ich warte hier. Ich bin nicht eingeladen, und ich habe "
          "die richtigen Schuhe nicht.", back("…")),
        N("menu", "(Brenneisen schreibt etwas in ein kleines Buch und wartet höflich, bis du fertig bist.)", [
            C("[Frage] Was wollen Sie heute wissen?", "q1", ["!flag_today:p9_stranger_asked", "!flag:p9_sq_1"]),
            C("[Frage] Was wollen Sie heute wissen?", "q2", ["!flag_today:p9_stranger_asked", "flag:p9_sq_1", "!flag:p9_sq_2"]),
            C("[Frage] Was wollen Sie heute wissen?", "q3", ["!flag_today:p9_stranger_asked", "flag:p9_sq_2", "!flag:p9_sq_3"]),
            C("[Frage] Was wollen Sie heute wissen?", "q4", ["!flag_today:p9_stranger_asked", "flag:p9_sq_3", "!flag:p9_sq_4"]),
            C("[Frage] Was wollen Sie heute wissen?", "q5", ["!flag_today:p9_stranger_asked", "flag:p9_sq_4", "!flag:p9_sq_5"]),
            C("[Frage] Was wollen Sie heute wissen?", "q6", ["!flag_today:p9_stranger_asked", "flag:p9_sq_5", "!flag:p9_sq_6"]),
            C("[Handel] Was wollen Sie eigentlich kaufen?", "offers", ["quest_done:q_case:k1"]),
            C("Sie haben Lambert Grell bezahlt.", "k3", ["quest_step:q_case:k3", "flag:q_case_known"]),
            C("Sie haben Lambert Grell bezahlt.", "k3", ["quest_step:q_case:k3", "clue_known:c_n_robber", "!flag:q_case_known"]),
            C("[Auftrag] Ihr Koffer. Rosine wollte ihn nicht anfassen.", "case_back", ["order_ready:oq_case_return"],
              ["order_turn_in:oq_case_return"]),
            C("Und die Toten selbst? Kaufen Sie die auch?", "no_corpses", ["quest_done:q_case:k1", "!flag:p9_stranger_corpses"],
              ["set_flag:p9_stranger_corpses"]),
            C("(Gehen)", ""),
        ]),
        N("offers", "Eine Handvoll. Von einem, der noch keine Woche liegt. Für die Wissenschaft. Sie würden staunen, was die "
          "Erde weiß. Und eine Abschrift Ihres Registers, wenn Sie eine hätten. Namen und Tage. Mehr nicht.",
          [C("Zeigen Sie mir, was Sie zahlen.", "", act=["stranger_offers"]), C("Nein.", "menu")]),
        N("no_corpses", "Einen ganzen? Gott bewahre, Herr Totengräber. Ich bin Kommissionär, kein Fuhrmann. Was in der Erde liegt, "
          "bleibt in der Erde. Ich nehme nur, was man mir gibt. Und ich frage nicht danach. Das ist meine ganze Moral. Sie ist "
          "klein, aber sie passt in den Koffer.", back("Dann ist ja gut.")),
        N("k3", "(Er klappt das Buch zu.) Ich habe den Mann für Nachrichten bezahlt, nicht für Leiber. Er hat es falsch verstanden. "
          "Leute vom Land verstehen Geld immer wörtlich. Ihr Vorgänger übrigens auch. Er hatte eine Schaufel und wenig Geduld.",
          [C("Und jetzt?", "bribe")], [], "", ["add_clue:c_q_case_lorenz"]),
        N("bribe", "Jetzt? Fünfzehn Münzen. Passend. Für Ihr Schweigen – nicht meinetwegen, verstehen Sie. Die Wissenschaft "
          "steht nicht gern in der Zeitung.",
          [C("(Die Münzen nehmen.)", "bribe_yes", act=["stranger_bribe:yes"]),
           C("Behalten Sie Ihr Geld.", "bribe_no", act=["stranger_bribe:no"])]),
        N("bribe_yes", "Passend. Ich zahle immer passend. (Er legt die Münzen einzeln auf den Torpfosten, wie Spielsteine.)",
          back("…")),
        N("bribe_no", "Wie Sie wollen. Die Stadt vergisst nicht, wer ihr Geld nicht nimmt. Sie wundert sich nur. Lange.",
          back("Soll sie.")),
        N("case_back", "Mein Koffer. Ich hätte ihn nie vergessen dürfen. Ich vergesse sonst nichts, das ist mein Beruf. "
          "(Er prüft das Schloss mit dem Daumen, ohne hinzusehen.) Für den Weg, Herr Totengräber. Passend.", back("…")),
        N("k5_fenner", "Ich gehe. Aber die Stadt bleibt, Herr Totengräber. Die Stadt bleibt immer. (Er tippt an den Zylinder.) "
          "Grüßen Sie den Schultheiß. Er schreibt so schön.", back("…", "")),
        N("k5_deal_kladde", "Vernünftig. Die Liste brauchen Sie nicht mehr. Sie wissen ja jetzt, was sie bedeutet. Ich nicht. "
          "Vierzig.", [C("Zeigen Sie mir Ihr Angebot.", "", act=["stranger_offers"])], ["quest_ended:%s" % MAIN], "k5_deal"),
        N("k5_deal", "Vernünftig. Sie sind ein Mann vom Handwerk. Zeigen Sie mir, was Sie haben, und ich zeige Ihnen, was es "
          "wert ist. In der Stadt.", [C("Zeigen Sie mir Ihr Angebot.", "", act=["stranger_offers"])]),
        N("k5_ilse", "Über der Erde? Wie bescheiden. Ich sehe sie mir an. Heute Nacht. Man lernt nie aus, Herr Totengräber, "
          "auch nicht in meinem Alter.", back("…", "")),
    ]
    for i, q in enumerate(QUESTIONS, start=1):
        flag = "p9_sq_%d" % i
        acts = ["set_flag:%s" % flag, "set_flag_day:p9_stranger_asked"]
        nodes.append(N("q%d" % i, q, [
            C("(Offen antworten.)", "a_frank", act=["stranger_answer:frank"] + acts),
            C("(Ausweichen.) Das kommt darauf an.", "a_evade", act=["stranger_answer:evade"] + acts),
            C("Die Toten haben ein Recht auf Ruhe. Die Fragen auch.", "a_refuse", act=["stranger_answer:refuse"] + acts),
        ]))
    nodes += [
        N("a_frank", "Danke. Genau so. (Er schreibt, dann legt er eine Münze auf den Torpfosten.) Für die Auskunft. Passend.",
          back("…")),
        N("a_evade", "Natürlich. Verzeihen Sie. In der Stadt fragt man zu viel, und hier oben zu wenig. Irgendwo dazwischen "
          "liegt die Wahrheit. Vermutlich unter einem Stein.", back("…")),
        N("a_refuse", "(Er lächelt, als hätte er genau das hören wollen.) Ein schöner Satz. Darf ich ihn aufschreiben? Ich zahle "
          "nicht dafür. Sätze bezahle ich nie.", back("…")),
    ]
    write_new(path("stranger"), "stranger", "Cornelius Brenneisen", "start", nodes)


# --- the villagers ---------------------------------------------------------------------------------------------

def washer():
    wm, wn = witness("e_dorn", "washer",
                     "Bei uns brannte ein Licht in der Kammer. Kaspar hat gesagt, das war ich. Ich hab gesagt, das war er. Drei Wochen "
                     "später ist er ins Moor gegangen und nicht wiedergekommen. Wir haben uns nie geeinigt, wer es war.",
                     "Und dann, leiser: Ich hab es ausgemacht, am Morgen. Es war nicht heiß. Ein Licht, das nicht heiß ist, "
                     "Totengräber. Das hab ich keinem gesagt. Dir jetzt.",
                     label="[Die Liste] Bei Ihnen, Liesel, im Julmond vor einem Jahr – brannte da ein Licht?")
    # §2.2.4: with underlined washer the line looks at you.
    wn.insert(0, N("p9_witness_underlined", "Bei uns brannte ein Licht in der Kammer. Kaspar hat gesagt, das war ich. Ich hab "
                   "gesagt, das war er. Drei Wochen später ist er ins Moor gegangen und nicht wiedergekommen. Wir haben uns nie "
                   "geeinigt, wer es war. (Sie sieht dich an, als wüsste sie, was auf der anderen Seite der Seite steht.)",
                   back("Danke."), ["underlined:washer", "!rel_tier:washer:friend"], "p9_witness", ["witness:e_dorn"]))
    for n in wn:
        if n.id == "p9_witness_friend":
            n.fb = "p9_witness_underlined"
    cm, cn = confide("washer", "Ich wasche ihn, wenn es so weit ist. Vorher nicht. Vorher ist er noch Johann.",
                     "(Sie fragt nicht, woher du es weißt.)")
    nodes = wn + cn + named_publicly(
        "washer", "Sie haben es mir vorher gesagt. Das rechne ich Ihnen an. Fenner hat meinen Namen trotzdem aufgeschrieben. "
        "Neben die Nacht. Ich wasche trotzdem.",
        "Fenner hat meinen Namen aufgeschrieben, Totengräber. Neben die Nacht, in der der Alte gestorben ist. Als hätte ich "
        "das Licht gebracht. Ich bring nur das Wasser.", "p9_sent_away") + [
        remark("p9_sent_away", "Lorenz hat sie auch fortgeschickt. Mit Briefen ohne Namen. Nicht alle sind angekommen. Ich hoffe, "
               "deiner kommt an. Ich hoffe es wirklich.", [ending("away"), "sieber_gone"], "p9_liesel_away", "p9_bundle_done"),
        remark("p9_bundle_done", "Das Leinen ist bei Anna. Gut. Wenn es so weit ist, muss sie nicht nähen. Das soll sie nicht "
               "müssen, nicht für den eigenen Vater.", ["order:oq_liesel_bundle:completed"], "p9_liesel_bundle", "p8_hill"),
        N("p9_bundle", "Bring das zu Anna Sieber. Leinen. Für später. Sie weiß schon. Sag Johann nicht, was drin ist. Oder sag es "
          "ihm. Er wird lachen. Er lacht über so was.",
          [C("Ich bring es hin.", "p9_bundle_yes", act=["order_accept:oq_liesel_bundle"]), C("Später.", "menu")]),
        N("p9_bundle_yes", "Klopf zweimal. Anna macht nicht auf, wenn einer nur einmal klopft. Das ist der Tod, sagt sie.",
          back("Zweimal.")),
        N("p9_aschau", "An L. Aschau. (Sie hält den Brief eine Weile, ohne ihn zu öffnen.) Ich steck ihn ins Gesangbuch. Da "
          "schlägt keiner nach außer mir. Und Gott, aber der liest nicht mit. Danke, Totengräber.",
          back("…"), [], "", ["quest_choose:q_letters:l5:liesel"]),
    ]
    menu = wm + cm + [
        C("[Auftrag] Was soll ich zu den Siebers bringen?", "p9_bundle", ["order_offerable:oq_liesel_bundle",
                                                                          "sieber_marked", "!sieber_gone"]),
        C("[Brief] Der hier ist an Lorenz. Gehört er Ihnen?", "p9_aschau", ["quest_step:q_letters:l5"]),
    ]
    patch(path("v_washer"), P, nodes, {"menu": menu}, {}, start="p9_public_confidant")


def priest():
    cm, cn = confide("priest", "Ein Licht, das keiner anzündet. Das steht in keinem Buch, das ich habe. Und ich habe viele "
                     "Bücher. Ich gehe zu ihm, wenn es so weit ist. Früher als sonst, wenn Sie wollen. Er wird schimpfen, dass "
                     "ich ihn störe. Gut.")
    lm, ln = letter_menu("[Brief] Das lag in der Tasche eines Toten. Es ist an Sie.",
                         "Drei Gulden aus dem Opferstock, 1829. Zurückgelegt, mit Zins. (Er liest es zweimal.) Der Zins war zu "
                         "hoch. Ich verbuche ihn als Spende. Und den Mann als ehrlich. Später als die meisten, aber ehrlich.",
                         reply="Er wollte es nur gesagt haben.")
    nodes = cn + ln + named_publicly(
        "priest", "Sie haben es mir vorher gesagt. Das rechne ich Ihnen an. Vor Fenner haben Sie mich trotzdem gestellt. "
        "Ich war trotzdem da. Ich bin immer da.",
        "Sie haben mich vor Fenner gestellt, Totengräber. Als stünde ich unter Verdacht, weil ich komme, wenn einer stirbt. "
        "Ich war trotzdem da. Ich bin immer da. Das ist mein Amt, nicht mein Verbrechen.", "p9_stay") + [
        remark("p9_stay", "Ich war gestern Abend bei ihm. Früher als sonst. Er hat geschimpft, dass ich ihn störe, und dann hat er "
               "mir Grete beschrieben, eine Stunde lang. Ich glaube, er wollte, dass es noch einer weiß.",
               [ending("stay"), "confided:priest"], "p9_lenz_stay", "start"),
        N("p9_kladde", "Lorenz' Kladde? Sie lag im Archiv. Sie haben sie liegen lassen. Ich nicht. (Er gibt sie dir.) Die "
          "Rückseite habe ich nicht gelesen. Das heißt: Ich habe sie gelesen und nicht verstanden. Das ist bei Lorenz dasselbe.",
          back("Danke, Herr Pfarrer."), [], "", ["give_item:lorenz_ledger_2:1", "set_flag:p9_lenz_kladde"]),
        N("p9_seal_public", "Wer ein Licht sieht, meldet es dem Schultheiß. (Er faltet das Blatt.) Er meint es gut. Das ist das "
          "Gefährliche an Fenner. Ich hänge es aus. Neben die Taufen.", back("…"), [ending("public")], "p9_seal"),
        N("p9_seal", "Die Ordnung der Gemeinde für den Advent. Mit Siegel. Fenner versiegelt sogar den Advent. Danke, "
          "Totengräber. Sie hätten es nicht gelesen, nehme ich an. Ich frage nicht. Ich sehe ohnehin schlecht.", back("…")),
        N("p9_candles", "Vier. Schön gezogen. Ich zünde die erste an, wenn Sie wieder hereinkommen. Die anderen drei warten. "
          "Wie wir alle.", back("Vergelt's Gott, Herr Pfarrer.")),
    ]
    menu = cm + lm + [
        C("[Die Liste] Ich finde Lorenz' Kladde nicht.", "p9_kladde", ["quest_step:%s:h1" % MAIN, "!has_item:lorenz_ledger_2:1",
                                                                       "!flag:p9_lenz_kladde"]),
        C("[Auftrag] Eine Bekanntmachung vom Schultheiß.", "p9_seal_public", ["order_ready:oq_fenner_seal"],
          ["order_turn_in:oq_fenner_seal"]),
        C("[Bitte] Die Altarkerzen für St. Gallus.", "p9_candles", ["large_ready:priest"], ["large_turn_in:priest"]),
    ]
    patch(path("v_priest"), P, nodes, {"menu": menu}, {}, start="p9_public_confidant")


def surgeon():
    cm, cn = confide("surgeon", "Drei Wochen. Ich habe es gezählt, bei den stillen Herzen. Ich hätte es aufschreiben sollen. "
                     "Es gibt einen Mann aus der Stadt, der dafür zahlen würde. Brenneisen heißt er. Geben Sie ihm nichts. "
                     "Ich habe ihm zu viel gegeben.")
    for n in cn:
        if n.id == "p9_confide_yes":
            n.act = ["set_flag:q_case_known"]
    nodes = cn + named_publicly(
        "surgeon", "Sie haben es mir vorher gesagt. Das rechne ich Ihnen an. Der Wächter hat mich trotzdem notiert. "
        "Quast, Wundarzt, zehn nach elf. Als wäre ich das Licht.",
        "Fenner hat mich notieren lassen. Quast, Wundarzt, zehn nach elf. Ich komme seit dreißig Jahren um zehn nach elf, "
        "Totengräber. Jetzt bin ich verdächtig, weil ich pünktlich bin.", "p9_case_gone") + [
        remark("p9_case_gone", "Sie haben mir meinen einzigen Käufer genommen. Vielleicht war das gut. Ich weiß es nicht. Ich "
               "weiß es wirklich nicht, und das ist für einen Wundarzt ein seltener Zustand.",
               ["stranger_ending:fenner"], "p9_quast_case", "start"),
        N("p9_drops", "Für die Schmerzen. Zehn Tropfen, nicht mehr, auch wenn er mehr will. Er wird nicht mehr wollen. Er ist "
          "keiner, der mehr will.", back("Danke, Quast."), [], "", ["set_flag:p9_quast_drops"]),
    ]
    menu = cm + [
        C("Johann Sieber hat Schmerzen. Haben Sie etwas für ihn?", "p9_drops", [ending("stay"), "confided:surgeon",
                                                                               "!flag:p9_quast_drops", "!flag:sieber_dead"]),
    ]
    patch(path("v_surgeon"), P, nodes, {"menu": menu}, {}, start="p9_public_confidant")


def innkeeper():
    wm, wn = witness("e_wernstein", "innkeeper",
                     "Die Ida hat bei mir ausgeschenkt, bis sie wegwollte. Sie kam eines Morgens und sagte, in ihrer Kammer hätte "
                     "die ganze Nacht ein Licht gebrannt, und sie hätte keins angezündet. Am nächsten Tag lag ein Brief unter "
                     "ihrer Tür. Da hat sie gepackt.",
                     "Ich hab ihr das Fahrgeld gegeben. Aus der Kasse. Wackernagel weiß es bis heute nicht. Sie ist trotzdem "
                     "nicht weit gekommen. Das hab ich ihr nicht gegeben, das Weitkommen.",
                     label="[Die Liste] Die Ida Wernstein – hat sie mal von einem Licht erzählt?")
    lm, ln = letter_menu("[Brief] Das lag in der Tasche eines Fuhrknechts. Es ist an dich.",
                         "Zwei Bier. Der Hund. (Sie lacht. Dann nicht mehr.) Er hat immer gesagt, er zahlt, wenn er wiederkommt. "
                         "Jetzt ist er wiedergekommen, und ich muss ihm die zwei Bier schenken. Ich häng den Zettel hinter den "
                         "Schanktisch. Da hängen die, die noch zahlen.", reply="Er hat an dich gedacht.")
    nodes = wn + ln + [
        N("p9_case", "Der Herr aus der Stadt hat seinen Koffer stehen lassen. Unterm Tisch, wo er schreibt. Bring ihn rauf, "
          "er wartet am Tor. Ich fass das Ding nicht an. Es riecht nach Branntwein, und nicht nach dem guten.",
          [C("Gib her.", "p9_case_yes", act=["order_accept:oq_case_return", "give_item:stranger_case:1"]),
           C("Nicht jetzt.", "menu")]),
        N("p9_case_yes", "Da. Schwerer, als er aussieht. Wie die meisten Herren aus der Stadt. Und schau nicht hinein. Oder schau "
          "hinein und erzähl's mir nicht.", back("…")),
    ]
    menu = wm + lm + [C("[Auftrag] Was ist mit dem Koffer?", "p9_case", ["order:oq_case_return:offered"])]
    patch(path("v_innkeeper"), P, nodes, {"menu": menu}, {})


def grocer():
    wm, wn = witness("e_hagedorn", "grocer",
                     "Ich seh vom Laden aus zur Hagedorn hinüber. Da brannte es, und die Alte war gesund wie ein Pferd. Ich hab "
                     "mir nichts gedacht. Man denkt sich bei Licht nichts. Das ist ja das Schlimme.",
                     "Ich hab am nächsten Morgen nachgerechnet, wie viel Öl so eine Nacht kostet. Sie hatte keins gekauft. "
                     "Nicht bei mir. Und woanders kauft hier keiner.",
                     label="[Die Liste] Bei der Hagedorn, im Herbst – hast du ein Licht gesehen?")
    lm, ln = letter_menu("[Brief] Das lag in der Tasche einer Toten. Es ist an Sie.",
                         "Holunderwein wie bei Mutter. Beeren nach dem ersten Frost, Honig statt Zucker. (Sie liest es zweimal.) "
                         "Sie hat es nie aufgeschrieben, solange sie lebte. Den nächsten Krug gebe ich Ihnen zum halben Preis. "
                         "Einmal. Ich schreibe es auf, damit ich es nicht vergesse und Sie nicht zweimal kommen.",
                         reply="Gern, Theres.")
    nodes = wn + ln + [
        N("p9_s", "Bei mir? Im Laden brennt nachts kein Licht. Licht kostet. Und wenn doch, dann zünde ich es an, und dann "
          "schreibe ich es auf. Mit S fängt hier im Dorf mehr an, als man denkt, Totengräber. Fragen Sie den Bettler. Der sieht die "
          "Fenster.", back("Danke."), [], "", ["set_flag:p9_theres_s"]),
    ]
    menu = wm + lm + [C("[Die Liste] Ein „S.“ – wer im Dorf könnte das sein?", "p9_s", ["quest_step:%s:h4" % MAIN,
                                                                                      "!flag:p9_theres_s"])]
    patch(path("v_grocer"), P, nodes, {"menu": menu}, {})


def mayor():
    nodes = [
        N("p9_row4", "Totengräber, die Gemeinde hat wieder getagt. Eine vierte Reihe am Lindenacker, die letzte, am Südrand. Vier "
          "Stellen. Eine halte ich zurück. Für den Fall. Ein Stumpf ist da und eine Brombeere, die kennen Sie schon.",
          [C("Danke, Herr Schultheiß.", "menu")], ["p9_open", "!flag:linden_row4_granted"], "p9_public_book",
          ["set_flag:linden_row4_granted", "notify:Die Gemeinde gibt dir die vierte Reihe. Die letzte, sagt Fenner.", "talked:mayor"]),
        N("p9_public_book", "Ein Licht, das keiner anzündet. Das schreibe ich auf. Was man aufschreibt, ist kein Gespenst mehr, "
          "sondern eine Akte. Der Nachtwächter steht ab heute Nacht vor den Siebers. Jede Nacht, bis … bis es vorbei ist.",
          back("…"), [ending("public"), "!flag:p9_fenner_public"], "p9_public_watch", ["set_flag:p9_fenner_public"]),
        N("p9_public_watch", "Der Wächter hat niemanden gesehen, der nicht hingehört. Quast, der Pfarrer, die Dorn. Er hat auch "
          "nicht geschlafen, sagt er. Ich habe es eingetragen. Das Buch hat jetzt einen Eintrag mehr, und Hollerbrück einen "
          "Mann weniger.", back("…"), [ending("public"), "flag:sieber_dead", "!flag:p9_fenner_watch"], "p9_sent_away",
          ["set_flag:p9_fenner_watch"]),
        remark("p9_sent_away", "Leute fortschicken ist nicht Ihr Amt, Totengräber. Es ist auch nicht meins. Ich trage es trotzdem "
               "nicht ein. Der Sieber ist verzogen. Unbekannt wohin. So steht es im Buch.",
               [ending("away"), "sieber_gone"], "p9_fenner_away", "p9_case_gone"),
        remark("p9_case_gone", "Der Herr aus der Stadt ist über die Brücke. Er hat sich nicht umgedreht. Ich habe es "
               "protokolliert, mit Uhrzeit. Der Nachtwächter sagt, er hat dabei gepfiffen. Das habe ich nicht protokolliert.",
               ["stranger_ending:fenner"], "p9_fenner_case", "p8_row3"),
        N("p9_s", "Bei mir? Bei mir brennt nachts kein Licht, Totengräber. Die Gemeinde spart. Ich schlafe im Dunkeln, das ist "
          "billiger und amtlich nicht verboten. Mit S – Schultheiß, meinen Sie? Das ist ein Amt, kein Name.",
          back("Verzeihung."), [], "", ["set_flag:p9_fenner_s"]),
        N("p9_seal", "Eine Bekanntmachung der Gemeinde für den Pfarrer. Versiegelt. Sie bleibt versiegelt. Ich sehe es, wenn "
          "einer am Siegel war. Ich sehe es immer.",
          [C("Ich bring sie hin.", "p9_seal_yes", act=["order_accept:oq_fenner_seal"]), C("Später.", "menu")]),
        N("p9_seal_yes", "Danke. Amtlich. Und Totengräber – das Siegel ist ein Siegel, kein Vorschlag.", back("Verstanden.")),
        N("p9_case", "(Er öffnet den Koffer mit zwei Fingern.) Instrumente. Gläser. Ein Brief vom Quast. Und eine Liste mit "
          "Namen aus meiner Gemeinde. Das ist kein Gespenst, das ist eine Akte. Der Nachtwächter bringt ihn über die Brücke. "
          "Heute noch.", back("…"), [], "", ["stranger_resolve:fenner"]),
    ]
    menu = [
        C("[Die Liste] Ein Licht im Nebelung, ein „S.“ – bei Ihnen?", "p9_s", ["quest_step:%s:h4" % MAIN, "!flag:p9_fenner_s"]),
        C("[Auftrag] Was soll ich dem Pfarrer bringen?", "p9_seal", ["order_offerable:oq_fenner_seal"]),
        C("Dieser Koffer gehört dem Herrn aus der Stadt. Sehen Sie hinein.", "p9_case", ["has_item:stranger_case:1",
                                                                                        "!quest:q_case:ended"]),
    ]
    patch(path("v_mayor"), P, nodes, {"menu": menu}, {}, start="p9_row4")


def smith():
    lm, ln = letter_menu("[Brief] Das lag in der Tasche eines Lehrlings. Es ist an Sie.",
                         "Die Zange. Im Graben bei der Mühle. Der Junge. (Er faltet den Zettel klein, sehr klein.) Er hat sich "
                         "geschämt. Für eine Zange. Hier, nimm die Beschläge. Er hätte sie dir auch gegeben, wenn er gekonnt hätte.",
                         reply="Danke, Esch.")
    nodes = ln + [
        N("p9_s", "Licht? In der Schmiede brennt immer Licht. Die Esse geht nie ganz aus. Wenn bei mir einer was anzündet, dann "
          "ich. Und ich weiß es. Frag woanders, Totengräber. Frag einen, der nachts nicht schläft.",
          back("Danke."), [], "", ["set_flag:p9_esch_s"]),
    ]
    menu = lm + [C("[Die Liste] Ein Licht im Nebelung, ein „S.“ – bei dir, in der Schmiede?", "p9_s",
                   ["quest_step:%s:h4" % MAIN, "!flag:p9_esch_s"])]
    patch(path("v_smith"), P, nodes, {"menu": menu}, {})


# --- the kin at their graves (kin_ott, kin_kehr, kin_brandt) ---------------------------------------------------

KIN_LETTER = ("[Brief] Das hatte er bei sich. Es ist für Sie.",
              "Von ihm? Er hat nie geschrieben. Nicht einmal, als er in Ellbach war. (Liest es zweimal, dann ein drittes Mal, "
              "ganz langsam.) Danke. Das behalt ich. Das ist mehr, als im Schrank hängt.")


def kin_ott():
    wm, wn = witness("e_ott", "kin_ott",
                     "Drei Wochen vorher brannte schon mal eins. In Vaters Kammer. Da war er noch gesund. Er hat gesagt, er war's "
                     "nicht. Wir haben gelacht. Ich lach da nicht mehr.",
                     label="[Die Liste] Drei Wochen bevor Ihr Vater starb – brannte da ein Licht?")
    lm, ln = letter_menu(*KIN_LETTER)
    nodes = wn + ln + [
        N("p9_brother", "Mein Bruder steht beim Militär. Er weiß nicht, dass Vater tot ist. Ich hab's aufgeschrieben. Gib es der "
          "Post, wenn sie kommt. Hanne oder Osric, egal. Peter liest nicht gern, aber das liest er.",
          [C("Ich bring ihn zur Post. Das Postgeld zahl ich.", "p9_brother_paid", act=["order_accept:oq_gesa_brother"]),
           C("Hast du eine Münze fürs Postgeld?", "p9_brother_straw", act=["order_accept:oq_gesa_brother",
                                                                          "give_item:straw_bouquet:1", "set_flag:q_gesa_straw"]),
           C("Später.", "menu")]),
        N("p9_brother_paid", "Danke. Ich kann's dir nicht zurückgeben. Ich kann dir nur sagen, dass ich's weiß.", back("…")),
        N("p9_brother_straw", "Ich hab keine Münze. Ich hab Strohblumen. Die halten länger als frische. Leg sie wem aufs Grab, "
          "zu dem keiner kommt.", back("Danke, Gesa.")),
        N("p9_post", "Von Peter. An Vater. Er weiß es nicht. (Sie liest, und ihr Mund liest mit.) Die Kuh hat gekalbt, Peter. "
          "Im Nebelung. Vater hat es nicht mehr gesehen. … Komm mit ans Grab, Totengräber. Ich les es ihm vor. Er soll's hören.",
          back("Ich komme mit.")),
    ]
    menu = wm + lm + [
        C("[Auftrag] Du hast einen Brief für deinen Bruder?", "p9_brother", ["order:oq_gesa_brother:offered"]),
        C("[Post] Ein Brief für Ihren Vater. Von Peter.", "p9_post", ["post_for:kin_ott"], ["letter_deliver:kin_ott"]),
    ]
    patch(path("kin_ott"), P, nodes, {"menu": menu}, {}, insert_before='text = "Ich lass Sie allein."')


def kin_plain(kin_id):
    lm, ln = letter_menu(*KIN_LETTER)
    patch(path(kin_id), P, ln, {"menu": lm}, {}, insert_before='text = "Ich lass Sie allein."')


# --- Hanne (peddler.tres), Ilse (trader.tres) -----------------------------------------------------------------

def peddler():
    pm, pn = post_menu("peddler", "Ein Brief? Kommt in die Kiepe, zwischen die Kerzen. Die Stadt ist drei Tage weit, für Briefe "
                       "zwei. Briefe sind schneller als ich, sie halten nicht an.")
    nodes = pn + [
        N("p9_away", "Den alten Sieber? Ich nehm ihn bis zur Straße. Weiter tragen ihn seine Beine, sagt er. Ich glaub's ihm. "
          "Die haben ihn einundsiebzig Jahre getragen, die schaffen noch ein Stück.",
          back("Danke, Hanne."), [ending("away"), "!sieber_gone", "!flag:p9_hanne_away"], "first", ["set_flag:p9_hanne_away"]),
        N("p9_aschau", "Ein Brief für einen Aschau. Totengräber zu Hollerbrück. Das bist du nicht, aber du bist der Einzige hier "
          "oben. Das Siegel mag ich nicht. Anker und Schlange. Nimm ihn schnell, er macht die Kerzen kalt.",
          back("Ich nehm ihn."), ["quest_step:q_letters:l5", "!flag:p9_hanne_aschau"], "p9_away", ["set_flag:p9_hanne_aschau"]),
    ]
    patch(path("peddler"), P, nodes, {"menu": pm}, {}, start="p9_aschau", insert_before='text = "Bis in sechs Tagen."')


def trader():
    nodes = [
        N("p9_case_ilse", "Er ist in die Stadt zurück. Er kommt nicht wieder. Frag nicht, was ich ihm verkauft habe. Ich sag nur "
          "so viel: Es lag über der Erde. Und jetzt liegt es in seinem Koffer und denkt nach.",
          back("…"), ["stranger_ending:ilse", "!flag:p9_ilse_case"], "gift_retry", ["set_flag:p9_ilse_case"]),
        N("p9_brenneisen", "Einer, der unter der Erde kauft und über der Erde zahlt. Brille an der Kette, Schuhe für Teppiche. "
          "Schick ihn zu mir, wenn du ihn loswerden willst. Ich weiß, was er sucht. Er nicht.", back("Ich denk drüber nach.")),
        N("p9_lights", "Lichter. Ja. Lorenz hat sie gezählt. Ich hab ihm gesagt, er soll aufhören zu zählen und anfangen zu gehen. "
          "Er hat beides gemacht. In der falschen Reihenfolge.", back("…")),
    ]
    menu = [C("Kennst du einen Brenneisen?", "p9_brenneisen", ["p9_open", "flag:p9_stranger_met"]),
            C("[Die Liste] Lichter, Ilse. Lorenz hat Lichter gezählt.", "p9_lights", [LIST])]
    patch(path("trader"), P, nodes, {"menu": menu}, {"first_meet": "p9_case_ilse"}, insert_before='next = &"goodbye"')


def main():
    carter()
    carter_village()
    beggar()
    kin_sieber()
    kin_sieber_v()
    sieber_door()
    stranger()
    washer()
    priest()
    surgeon()
    innkeeper()
    grocer()
    mayor()
    smith()
    kin_ott()
    kin_plain("kin_kehr")
    kin_plain("kin_brandt")
    peddler()
    trader()


if __name__ == "__main__":
    main()
