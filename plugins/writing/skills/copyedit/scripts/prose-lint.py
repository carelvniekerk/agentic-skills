#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Deterministic prose lint for client deliverables in English and German.

Two modes:

    prose-lint.py FILE [--lang auto|en|de] [--limit N] [--json]
    prose-lint.py --compare ORIGINAL EDITED [--lang auto|en|de] [--json]

The first lists rule hits with line and column, plus rhythm and density
statistics. Every hit is a candidate for the editor to judge, never a verdict:
the rules are regular expressions and know nothing about context.

The second checks that an edit kept the tokens that carry meaning: numbers,
negations, modal verbs, hedges, quotations and capitalised terms. It reports
the differences and leaves the judgement to the editor.

The script uses only the standard library. It declares Python 3.14 to match the
repository's ruff target, and it also runs under python3 3.10 or later when uv
cannot fetch 3.14.
"""

import argparse
import json
import re
import statistics
import sys
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path

FIX = "fix"
CHECK = "check"
EN = "en"
DE = "de"
BOTH = "en de"

DEFAULT_LIMIT = 10
SNIPPET_RADIUS = 45
LONG_SENTENCE = {EN: 35, DE: 30}
RHYTHM_BAND = (8, 20)
UNIFORM_SHARE = 0.7
UNIFORM_SD = 6.0
PUNCHLINE_MAX_WORDS = 7
PUNCHLINE_MIN_SENTENCES = 3
SHORT_PARAGRAPH_WORDS = 12
NOMINAL_PER_SENTENCE = 3
RATHER_THAN_PER_1000 = 1.0
TITLE_CASE_RATIO = 0.5
TITLE_CASE_MIN = 2
MIN_TERM_LENGTH = 12
PER_THOUSAND = 1000


@dataclass(frozen=True)
class Rule:
    """A regular-expression rule with its severity and the languages it covers."""

    rule_id: str
    level: str
    langs: str
    pattern: re.Pattern[str]
    note: str
    guard: re.Pattern[str] | None = None


@dataclass
class Hit:
    """One match of a rule, located by line and column (both 1-based)."""

    rule_id: str
    level: str
    note: str
    line: int
    col: int
    text: str


def _rule(  # noqa: PLR0913
    rule_id: str,
    level: str,
    langs: str,
    regex: str,
    note: str,
    *,
    flags: int = re.IGNORECASE,
    guard: str | None = None,
) -> Rule:
    return Rule(
        rule_id,
        level,
        langs,
        re.compile(regex, flags),
        note,
        re.compile(guard, re.IGNORECASE) if guard else None,
    )


CS = 0  # case-sensitive flag value for readability in the table below

RULES: tuple[Rule, ...] = (
    # Punctuation and symbols, both languages.
    _rule(
        "dash",
        FIX,
        BOTH,
        r"[\u2013\u2014]",
        "Em or en dash: use a comma, colon, brackets or a full stop",
    ),
    _rule(
        "spaced-hyphen",
        FIX,
        BOTH,
        r"(?<=[^\s|-]) - (?=[^\s|-])",
        "Spaced hyphen used as a dash",
    ),
    _rule(
        "double-hyphen",
        CHECK,
        BOTH,
        r"(?<![-|])--(?![-|])",
        "Double hyphen outside LaTeX reads as a dash",
    ),
    _rule(
        "semicolon",
        CHECK,
        BOTH,
        r";",
        "Semicolon in client prose: split the sentence or use a colon",
    ),
    _rule(
        "exclamation",
        FIX,
        BOTH,
        r"(?<=[^\s!])!(?=\s|$)",
        "Exclamation mark in a client document",
    ),
    _rule(
        "emoji",
        FIX,
        BOTH,
        r"[\U0001F300-\U0001FAFF\u2600-\u27BF\u2B50]",
        "Emoji or pictograph",
    ),
    _rule(
        "brand",
        FIX,
        BOTH,
        r"\b(?!MULTIPLAI\b)[Mm][Uu][Ll][Tt][Ii][Pp][Ll][Aa][Ii]\b(?!\.\w)",
        "Write MULTIPLAI in capitals",
        flags=CS,
    ),
    _rule(
        "space-punct",
        CHECK,
        BOTH,
        r" [,;](?! )|,(?=[A-Za-zÄÖÜäöü])",
        "Space before or missing after a comma",
    ),
    _rule(
        "repeated-word",
        CHECK,
        BOTH,
        r"\b(\w+)\s+\1\b",
        "Repeated word",
        guard=r"\b(?:that that|had had|die die|der der|das das)\b",
    ),
    # English vocabulary.
    _rule(
        "banned-en",
        FIX,
        EN,
        r"\b(?:delv\w*|leverag\w*|harness\w*|unlock\w*|seamless\w*|holistic\w*|"
        r"pivotal|crucial\w*"
        r"|underscor\w*|foster\w*|showcas\w*|testament|landscapes?|realms?|tapestr\w*|"
        r"journey\w*"
        r"|empower\w*|deep[- ]dives?|game[- ]chang\w*|elevat\w*|boasts?|synerg\w*|"
        r"paradigm\w*"
        r"|transformative|cutting[- ]edge|state[- ]of[- ]the[- ]art|"
        r"best[- ]in[- ]class|world[- ]class"
        r"|future[- ]proof\w*|vibrant|meticulous\w*|intricate\w*|multifaceted|quietly|"
        r"ecosystems?"
        r"|navigat\w*|streamlin\w*|tackl\w*)\b",
        "Banned or inflated vocabulary: use the plain word or the specific fact",
    ),
    _rule(
        "watch-en",
        CHECK,
        EN,
        r"\b(?:robust\w*|steady|dependable|notably|moreover|furthermore|additionally|"
        r"actionable"
        r"|insights?|evolving|comprehensive|significant(?:ly)?|overarching|drive[sn]?|"
        r"key(?= [a-z]))\b",
        "Watch word: keep only in its precise or technical sense",
    ),
    _rule(
        "intensifier-en",
        CHECK,
        EN,
        r"\b(?:genuinely|truly|really|actually|very|extremely|incredibly|highly|"
        r"deeply|absolutely"
        r"|definitely|clearly|obviously|simply|the single (?:most|largest|biggest)|"
        r"by far)\b",
        "Intensifier: cut it or replace it with the evidence",
    ),
    _rule(
        "filler-en",
        CHECK,
        EN,
        r"\b(?:it'?s worth (?:noting|mentioning|emphasi[sz]ing)|it is worth|"
        r"it'?s important to"
        r"|it is important to|it should be noted|needless to say|"
        r"it goes without saying|that said"
        r"|at its core|at the end of the day|in today'?s|in order to|with regard to|"
        r"with respect to"
        r"|in terms of|the fact that|a (?:wide )?(?:range|variety|number) of|"
        r"in the context of"
        r"|the aforementioned|in the event that|as such|going forward|"
        r"moving forward)\b",
        "Filler or bureaucratic phrase",
    ),
    _rule(
        "stock-en",
        FIX,
        EN,
        r"\b(?:in conclusion|in summary|to summari[sz]e|to sum up|i hope this helps|"
        r"let me know if"
        r"|great question|you'?re absolutely right|feel free to|we are (?:excited|"
        r"delighted|thrilled))\b",
        "Stock opener or closer",
    ),
    _rule(
        "signpost-en",
        CHECK,
        EN,
        r"\b(?:deserves (?:emphasis|attention|mention)|worth (?:emphasi[sz]ing|"
        r"highlighting)"
        r"|one (?:point|thing) (?:deserves|is worth)|(?:two|three|"
        r"a few) things to (?:flag|note|consider)"
        r"|let'?s|let us|as (?:mentioned|discussed|noted|outlined|described) (?:above|"
        r"earlier|previously|before)"
        r"|(?:this|the following) (?:section|chapter)s? (?:will )?(?:discuss|describe|"
        r"explore|outline)s?)\b",
        "Signpost or meta-commentary: open with the content instead",
    ),
    _rule(
        "copula-en",
        CHECK,
        EN,
        r"\b(?:serv(?:e|es|ed|ing)|stand(?:s|ing)?|stood|act(?:s|ed|ing)?|"
        r"function(?:s|ed|ing)?) as"
        r" (?:a|an|the)\b|\brepresents? (?:a|an|the)\b",
        "Copula avoidance: 'is' usually does the job",
    ),
    _rule(
        "antithesis-en",
        CHECK,
        EN,
        r"\bnot (?:just|only|merely|simply)\b"
        r"|\b(?:is|are|was|were)(?: not|n't)\b[^.;:\n]{1,60}?[,.;] (?:it|they|"
        r"this)(?:'s| is| are)\b"
        r"|\b(?:is|are) not\b[^.,;\n]{1,60}\bbut\b",
        "Antithesis framing: keep it only where the contrast is the point, such as a "
        "scope boundary",
    ),
    _rule(
        "rather-than",
        CHECK,
        EN,
        r"\brather than\b",
        "'rather than': fine once, a tic in bulk (see the density line)",
    ),
    _rule(
        "colon-reveal",
        CHECK,
        BOTH,
        r"(?:^|[.!?]\s)[A-ZÄÖÜ][^.:!?\n]{10,}:\s+"
        r"[^\s.:!?\n][^.:!?\n]{0,30}\.(?:\s|$)",
        "Colon-then-reveal",
        flags=CS,
    ),
    _rule(
        "ing-tail-en",
        CHECK,
        EN,
        r",\s+(?:highlighting|underscoring|emphasi[sz]ing|reflecting|showcasing|"
        r"signall?ing"
        r"|demonstrating|illustrating|ensuring|marking|contributing to|paving the way|"
        r"setting the stage"
        r"|fostering|making (?:it|this)|enabling)\b",
        "Trailing -ing clause that comments on the previous point",
    ),
    _rule(
        "vague-authority-en",
        FIX,
        EN,
        r"\b(?:studies (?:show|suggest|have shown)|research (?:shows|suggests|"
        r"has shown)"
        r"|experts (?:agree|argue|say|believe)|it is (?:widely|generally|"
        r"commonly) (?:accepted|known|believed|agreed)"
        r"|industry (?:reports|observers)|observers (?:note|say)|many (?:believe|"
        r"argue))\b",
        "Vague authority: name the source or cut the claim",
    ),
    _rule(
        "impersonal-en",
        CHECK,
        EN,
        r"\bit is (?:recommended|suggested|believed|expected|assumed|proposed|advised|"
        r"felt|thought)\b",
        "Impersonal evaluation: say who recommends or expects it",
    ),
    _rule(
        "nominal-en",
        CHECK,
        EN,
        r"\b(?:perform|conduct|carry out|undertake|make|effect|provide|achieve)(?:s|"
        r"ed|ing)?"
        r"\s+(?:an?|the)\s+(?:\w+\s)?\w+(?:tion|ment|ance|ence|sis|al)\s+of\b",
        "Nominalisation: use the verb",
    ),
    _rule(
        "hedge-stack",
        CHECK,
        BOTH,
        r"\b(?:could|might|may) (?:potentially|possibly|perhaps)\b|\b(?:potentially|"
        r"possibly) (?:could|might|may)\b"
        r"|\bit (?:seems|appears) (?:that|likely|possible)\b|\bsomewhat\b|"
        r"\barguably\b|\bto some extent\b"
        r"|\bkönnte[n]? (?:eventuell|möglicherweise|unter Umständen)\b|"
        r"\bwürden? (?:empfehlen|vorschlagen|sagen|meinen)\b",
        "Stacked or reflexive hedge: calibrate to the evidence instead",
    ),
    _rule(
        "question",
        CHECK,
        BOTH,
        r"[^\s?][^?\n]{8,}\?(?=\s|$)",
        "Question in client prose: is it one the reader asked?",
    ),
    _rule(
        "open-list",
        CHECK,
        BOTH,
        r"\betc\b\.?|\band so (?:on|forth)\b|\busw\b\.?|\bu\. ?ä\.|\bund so weiter\b",
        "Open list: in a scope or deliverables list, close it or use 'including'",
    ),
    _rule(
        "oxford-comma",
        CHECK,
        EN,
        r"\b\w+, [\w-]+(?: [\w-]+)?, (?:and|or) \w+",
        "Serial comma: keep only where the sentence is ambiguous without it",
    ),
    _rule(
        "spelling-us",
        CHECK,
        EN,
        r"\b(?!(?:size|seize|prize|capsize|maize)\w*\b)\w{3,}(?:iz|yz)(?:e|es|ed|ing|"
        r"ation|ations|er|ers)\b"
        r"|\b(?:colou?r(?<!colour)\w*|behavior\w*|favor\w*|honor\w*|labor\w*|"
        r"neighbor\w*|center(?:s|ed)?"
        r"|fiber|theater|catalog(?:s|ed)?|dialog|analog|model(?:ing|ed)|label(?:ing|"
        r"ed)|cancel(?:ing|ed)"
        r"|travel(?:ing|ed)|signal(?:ing|ed)|fuel(?:ing|ed)|defense|offense|gray|"
        r"artifacts?|percent"
        r"|toward|judgment|acknowledgment|fulfill|enroll|aging|program(?:s|med)?)\b",
        "US spelling: use the British form (-ise, -our, -re, -ll-, artefact, "
        "programme outside software)",
    ),
    _rule(
        "germanism-en",
        CHECK,
        EN,
        r"\beventual(?:ly)?\b|\bsensible\b|\bin the frame of\b|\bmanagement summary\b|"
        r"\bsince \d+ (?:days|weeks|months|years)\b",
        "Possible German false friend or calque",
    ),
    _rule(
        "germanism-en-cs",
        CHECK,
        EN,
        r"\bE-Mail\b|\bMai \d|\b(?:Januar|Februar|März|Juni|Juli|Oktober|Dezember)\b",
        "German spelling or month name in English text",
        flags=CS,
    ),
    _rule(
        "date-en",
        CHECK,
        EN,
        r"\b\d{1,2}(?:st|nd|rd|th)?\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|"
        r"Dec)[a-z]*\.?,?\s+\d{4}\b"
        r"|\b(?:January|February|March|April|May|June|July|August|September|October|"
        r"November|December)"
        r"\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}\b|\b\d{1,2}\.\d{1,2}\.\d{2,4}\b|"
        r"\b\d{1,2}/\d{1,2}/\d{2,4}\b",
        "Date not in YYYY-MM-DD",
    ),
    _rule(
        "time-12h",
        CHECK,
        EN,
        r"\b\d{1,2}(?::\d{2})?\s?(?:am|pm|a\.m\.|p\.m\.)(?=\W|$)",
        "12-hour clock: use 24-hour",
    ),
    _rule(
        "number-de-in-en",
        CHECK,
        EN,
        r"(?<![\w.,])\d{1,3}(?:\.\d{3})+(?![\w.,]*\d)|(?<![\w.,])\d+,(?:\d{1,2}|"
        r"\d{4,})(?![\d,])",
        "German number format in English text (1.250 or 43,7)",
        guard=r"(?:section|sections|table|figure|chapter|version|v)\s*$",
    ),
    # German vocabulary and grammar.
    _rule(
        "banned-de",
        FIX,
        DE,
        r"\bintegrale[nmrs]? Bestandteil\w*|\bvielfältige[nmrs]? Möglichkeiten\b|"
        r"\bin der heutigen (?:Zeit|Welt)\b"
        r"|\bauf (?:das nächste|ein neues) Level\b|\brevolutionier\w*|"
        r"\bbahnbrechend\w*|\bnahtlos\w*"
        r"|\bganzheitlich\w*|\bMehrwert\w*|\bSynergie\w*|\bzielführend\w*|"
        r"\bspannend\w*|\bessen[zt]iell\w*"
        r"|\btiefgreifend\w*|\btransformativ\w*|\bParadigmenwechsel\b|"
        r"\bQuantensprung\b|\bGame-?Changer\b"
        r"|\bLeuchtturm\w*|\b(?:Transformations)?[Rr]eise\b|\beintauchen\b|"
        r"\bbeleucht\w*|\bunterstreich\w*"
        r"|\babholen\b|\bThematik\b|\bProblematik\b|\bzeitnah\w*|\bproaktiv\w*|"
        r"\bKernstück\b|\bHerzstück\b"
        r"|\bSchlüssel(?:rolle|faktor|element)\w*|\bfungier\w* als\b",
        "Floskel, Buzzword oder KI-typische Wendung",
    ),
    _rule(
        "watch-de",
        CHECK,
        DE,
        r"\b(?:robust\w*|innovativ\w*|umfassend\w*|maßgeblich\w*|entscheidend\w*|"
        r"nachhaltig\w*|Landschaft"
        r"|Ökosystem\w*|State of the Art|Best Practices?|optimal\w*"
        r"|dien(?:t|en) als)\b"
        r"|\bstell(?:t|en) [^.\n]{1,60}? dar\b",
        "Wort prüfen: nur im präzisen oder fachlichen Sinn",
    ),
    _rule(
        "filler-de",
        CHECK,
        DE,
        r"\b(?:eigentlich|ziemlich|irgendwie|ein bisschen|durchaus|tatsächlich|"
        r"wirklich|absolut|definitiv"
        r"|grundsätzlich|letztendlich|letztlich|im Endeffekt|quasi|sozusagen|"
        r"natürlich|selbstverständlich"
        r"|gewissermaßen|im Grunde)\b",
        "Füllwort oder Verstärker",
    ),
    _rule(
        "stock-de",
        FIX,
        DE,
        r"\bEs ist (?:wichtig|erwähnenswert|bemerkenswert) zu\b|"
        r"\bEs sei (?:darauf hingewiesen|angemerkt|erwähnt)\b"
        r"|\bEs ist zu beachten\b|\bZusammenfassend lässt sich\b|"
        r"\bAbschließend lässt sich\b"
        r"|\bLast but not least\b|\bAn dieser Stelle sei\b|\bWie bereits erwähnt\b|"
        r"\bIch hoffe, (?:das|dies) hilft\b"
        r"|\bLassen Sie uns\b|\bFakt ist\b|\bKurz gesagt\b",
        "Floskel am Anfang oder Ende",
    ),
    _rule(
        "signpost-de",
        CHECK,
        DE,
        r"\b(?:Im Folgenden|Im nächsten (?:Abschnitt|Kapitel)|In diesem (?:Abschnitt|"
        r"Kapitel) (?:wird|werden)"
        r"|Darüber hinaus|Des Weiteren|Ferner)\b",
        "Ankündigung oder Verbindungsfloskel: mit dem Inhalt beginnen",
    ),
    _rule(
        "bureaucratic-de",
        CHECK,
        DE,
        r"\b(?:im Rahmen (?:von|des|der|dieses|dieser)|im Hinblick auf|hinsichtlich|"
        r"bezüglich|in Bezug auf"
        r"|seitens|mittels|vonseiten|zwecks|diesbezüglich|vorgenannt\w*|"
        r"obige[nmrs]?)\b|\bo\. ?g\.",
        "Amtsdeutsch: einfacher formulieren",
    ),
    _rule(
        "nominal-de",
        CHECK,
        DE,
        r"\bzur (?:Durchführung|Anwendung|Umsetzung|Verfügung|Entscheidung|Sprache|"
        r"Kenntnis)"
        r" (?:zu )?(?:bringen|kommen|gelangen|stellen|nehmen)\b|\bin (?:Betracht|"
        r"Erwägung|Anspruch) (?:ziehen|nehmen|genommen|gezogen)\b"
        r"|\bBerücksichtigung finden\b|\bzum Einsatz (?:kommen|kommt|bringen)\b"
        r"|\b(?:erfolgt|erfolgen|erfolgte|erfolgten) (?:die|der|eine|durch|im|in)\b"
        r"|\beine (?:Analyse|Bewertung|Prüfung|Optimierung|Anpassung) (?:durchführen|"
        r"vornehmen)\b"
        r"|\b(?:Durchführung|Erstellung|Implementierung|Bereitstellung) (?:der|des|"
        r"von)\b",
        "Nominalstil oder Funktionsverbgefüge: das Verb verwenden",
    ),
    _rule(
        "antithesis-de",
        CHECK,
        DE,
        r"\bnicht nur\b[^.\n]{0,80}?\bsondern\b|\bnicht\b[^.,;\n]{1,50},\s*sondern\b|"
        r"\b(?:statt|anstatt|anstelle)\b",
        "Kontrastfigur: nur behalten, wenn der Gegensatz die Aussage ist",
    ),
    _rule(
        "impersonal-de",
        CHECK,
        DE,
        r"\bEs (?:wird|werden) (?:empfohlen|vorgeschlagen|angenommen|erwartet|"
        r"davon ausgegangen)\b"
        r"|\bEs empfiehlt sich\b|\bEs ist (?:geplant|vorgesehen|davon auszugehen)\b|"
        r"\bMan (?:sollte|könnte|kann|muss)\b",
        "Unpersönliche Bewertung: sagen, wer empfiehlt oder erwartet",
    ),
    _rule(
        "hedge-de",
        CHECK,
        DE,
        r"\b(?:eventuell|möglicherweise|unter Umständen|gegebenenfalls)\b|\bggf\.",
        "Absicherung: an die Beweislage anpassen",
    ),
    _rule(
        "anglicism-de",
        CHECK,
        DE,
        r"\b(?:macht|machen|machte) (?:\w+ )?(?:keinen |wenig |viel )?Sinn\b|"
        r"\bSinn machen\b|\bin (?:19|20)\d{2}\b"
        r"|\beinmal mehr\b|\badressier\w*|\bam Ende des Tages\b|\bnicht wirklich\b|"
        r"\bbasierend auf\b"
        r"|\bcommitt\w*|\bchalleng\w*|\bsupporte?n\b|\bgelauncht\b|\blaunch\w*|"
        r"\beine Entscheidung machen\b"
        r"|\bIch denke,? dass\b|\brealisier\w*",
        "Anglizismus oder Lehnübersetzung",
    ),
    _rule(
        "compound-space-de",
        CHECK,
        DE,
        r"\b(?!(?:Die|Der|Das|Diese[rsmn]?|Eine[rsmn]?|Ein|Unsere[rsmn]?|Ihre[rsmn]?|"
        r"Jede[rsmn]?|Keine[rsmn]?|Alle"
        r"|Neue[rsmn]?|Welche[rsmn]?|Solche[rsmn]?|Beide|Mehrere|Viele|Einige|Im|Am|"
        r"Zum|Zur|Vom|Beim) )"
        r"[A-Z][a-z]+(?: [A-Z][a-z]+)?"
        r" (?:Schicht|Plattform|Projekt|Architektur|Strategie|Prozess|Modell|Lösung|"
        r"Integration|Pipeline"
        r"|Umgebung|Initiative|Migration|Team|Daten|Konzept|Roadmap)\b",
        "Leerzeichen im Kompositum: durchkoppeln (Data-Vault-Schicht)",
        flags=CS,
    ),
    _rule(
        "du-form",
        FIX,
        DE,
        r"\b(?:du|dir|dich|dein|deine[mnrs]?|euch|euer|eure[mnrs]?)\b",
        "Du-Form in einem Kundendokument: Sie verwenden, sofern nicht anders "
        "vereinbart",
    ),
    _rule(
        "quotes-de",
        CHECK,
        DE,
        r"\"[^\"\n]{1,80}\"|\u201d",
        "Anführungszeichen: „…“ verwenden",
    ),
    _rule(
        "enum-comma-de",
        CHECK,
        DE,
        r"\b\w+, \w+, (?:und|oder) \w+",
        "Komma vor und/oder in einer einfachen Aufzählung",
    ),
    _rule("percent-de", CHECK, DE, r"\d%", "Prozentzeichen mit Leerzeichen: 25 %"),
    _rule(
        "date-de",
        CHECK,
        DE,
        r"\b\d{4}-\d{2}-\d{2}\b|\b(?:January|February|March|May|June|July|October|"
        r"December)\b"
        r"|\b\d{1,2}\.\s?(?:Januar|Februar|März|April|Mai|Juni|Juli|August|September|"
        r"Oktober|November|Dezember)\s\d{4}\b"
        r"|\b\d{1,2}\.\d{2} Uhr\b",
        "Datum oder Uhrzeit: TT.MM.JJJJ und 07:00 Uhr",
        flags=CS,
    ),
    _rule(
        "number-en-in-de",
        CHECK,
        DE,
        r"(?<![\w.,])\d{1,3}(?:,\d{3})+(?![\d,])|(?<![\w.,§])\d+\.\d{1,2}(?![\d.])",
        "Englisches Zahlenformat im deutschen Text (1,250 oder 43.7)",
        guard=r"(?:abschnitt|abschnitte|kapitel|tabelle|abbildung|version|v|nr\."
        r"|section)"
        r"\s*$",
    ),
)

EN_STOP = re.compile(r"\b(?:the|and|of|to|is|that|with|for|are|this)\b", re.IGNORECASE)
DE_STOP = re.compile(
    r"\b(?:der|die|das|und|ist|nicht|mit|für|sind|eine?)\b",
    re.IGNORECASE,
)
WORD = re.compile(r"[A-Za-zÄÖÜäöüß][\wÄÖÜäöüß'\u2019-]*")
ABBREVIATIONS = re.compile(
    r"\b(?:e\.g|i\.e|etc|vs|cf|approx|no|Nr|ca|bzw|z\. ?B|d\. ?h|u\. ?a|s\. ?o|Abs|Dr|"
    r"Prof|Fig|Tab)\.",
)
SENTENCE_END = re.compile(r"(?<=[.!?])\s+(?=[A-ZÄÖÜ\"„“(0-9])")
MD_HEADING = re.compile(r"^\s*#{1,6}\s+(.*)$")
NUM_HEADING = re.compile(r"^\s*((?:\d{1,2}\.)+\d{0,2})\s+([A-ZÄÖÜ].{0,100})$")
TEX_HEADING = re.compile(r"\\(?:sub){0,2}section\*?\{([^}]*)\}")
LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
TABLE_ROW = re.compile(r"^\s*\|")
DOT_LEADER = re.compile(r"\.{4,}")
NOMINAL_DE = re.compile(
    r"\b[A-ZÄÖÜ]\w+(?:ung|ungen|heit|heiten|keit|keiten|tion|tionen)\b",
)
TERM = re.compile(
    r"\b(?!(?:The|A|An|This|These|That|Die|Der|Das|Ein|Eine|Diese)\b)"
    r"[A-ZÄÖÜ][\wäöüß]*(?:[ -][A-ZÄÖÜ][\wäöüß]*){0,2}\b",
)
STOPWORD_HEADING = re.compile(
    r"^(?:a|an|the|and|or|of|in|on|for|to|with|by|at|from|as|vs|per|into|via|is|are)$",
    re.IGNORECASE,
)


def detect_language(text: str) -> str:
    """Return 'de' when German function words outnumber English ones, otherwise 'en'."""
    return DE if len(DE_STOP.findall(text)) > len(EN_STOP.findall(text)) else EN


def _blank(match: re.Match[str]) -> str:
    return re.sub(r"[^\n]", " ", match.group(0))


def mask_text(text: str, suffix: str) -> str:
    """Blank out everything that is not prose, keeping line and column positions.

    Frontmatter, fenced code, HTML comments, inline code, URLs, e-mail addresses,
    link targets and, for LaTeX, comments, maths and command names are replaced
    with spaces.
    """
    text = re.sub(r"\A---\n.*?\n---\n", _blank, text, flags=re.DOTALL)
    text = re.sub(
        r"^(```|~~~).*?^\1[^\n]*$",
        _blank,
        text,
        flags=re.DOTALL | re.MULTILINE,
    )
    text = re.sub(r"<!--.*?-->", _blank, text, flags=re.DOTALL)
    text = re.sub(r"`[^`\n]*`", _blank, text)
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", _blank, text)
    text = re.sub(r"(?<=\])\([^)]*\)", _blank, text)
    text = re.sub(r"https?://\S+|\b[\w.+-]+@[\w-]+\.[\w.]+\b", _blank, text)
    if suffix == ".tex":
        text = re.sub(r"(?<!\\)%[^\n]*", _blank, text)
        text = re.sub(r"\$[^$\n]*\$", _blank, text)
        text = re.sub(
            r"\\(?:cite\w*|ref|eqref|label|url|href|"
            r"includegraphics)(?:\[[^\]]*\])?\{[^}]*\}",
            _blank,
            text,
        )
        text = re.sub(r"\\[A-Za-z]+\*?(?:\[[^\]]*\])?", _blank, text)
        text = re.sub(r"[{}]", " ", text)
    return text


@dataclass
class Document:
    """The masked text of one file with its derived structure."""

    path: Path
    lang: str
    raw_lines: list[str]
    lines: list[str]
    headings: list[tuple[int, str]]
    paragraphs: list[tuple[int, str]]


def _heading_text(raw: str, masked: str) -> str | None:
    if DOT_LEADER.search(raw):
        return None
    for pattern, line in ((MD_HEADING, masked), (TEX_HEADING, raw)):
        match = pattern.search(line)
        if match:
            return match.group(1).strip()
    match = NUM_HEADING.match(masked)
    if match and not match.group(2).rstrip().endswith((".", ":")):
        return masked.strip()
    return None


def _paragraphs(lines: list[str], heading_lines: set[int]) -> list[tuple[int, str]]:
    paragraphs: list[tuple[int, str]] = []
    start, buffer = 0, []
    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        breaks = (
            not stripped
            or number in heading_lines
            or TABLE_ROW.match(line)
            or LIST_ITEM.match(line)
        )
        if breaks and buffer:
            paragraphs.append((start, " ".join(buffer)))
            buffer = []
        if not stripped or number in heading_lines or TABLE_ROW.match(line):
            continue
        if not buffer:
            start = number
        buffer.append(LIST_ITEM.sub("", stripped))
    if buffer:
        paragraphs.append((start, " ".join(buffer)))
    return paragraphs


def load(path: Path, lang: str) -> Document:
    """Read and mask a file, then work out its language, headings and paragraphs."""
    raw = path.read_text(encoding="utf-8")
    masked = mask_text(raw, path.suffix.lower())
    raw_lines, lines = raw.splitlines(), masked.splitlines()
    headings = []
    for number, (raw_line, line) in enumerate(zip(raw_lines, lines, strict=False), 1):
        text = _heading_text(raw_line, line)
        if text:
            headings.append((number, text))
    paragraphs = _paragraphs(lines, {number for number, _ in headings})
    resolved = detect_language(masked) if lang == "auto" else lang
    return Document(path, resolved, raw_lines, lines, headings, paragraphs)


def sentences(paragraph: str) -> list[str]:
    """Split a paragraph into sentences, protecting common abbreviations."""
    protected = ABBREVIATIONS.sub(
        lambda m: m.group(0).replace(".", "\u2024"),
        paragraph,
    )
    return [
        s.replace("\u2024", ".").strip()
        for s in SENTENCE_END.split(protected)
        if s.strip()
    ]


def word_count(text: str) -> int:
    """Count words that start with a letter."""
    return len(WORD.findall(text))


def _snippet(line: str, start: int, end: int) -> str:
    left = max(0, start - SNIPPET_RADIUS)
    right = min(len(line), end + SNIPPET_RADIUS)
    prefix = "…" if left else ""
    suffix = "…" if right < len(line) else ""
    return f"{prefix}{line[left:right].strip()}{suffix}"


def apply_rules(doc: Document) -> list[Hit]:
    """Run every regular-expression rule that covers the document's language."""
    hits: list[Hit] = []
    tex = doc.path.suffix.lower() == ".tex"
    for rule in RULES:
        if doc.lang not in rule.langs.split() or (
            tex and rule.rule_id == "double-hyphen"
        ):
            continue
        for number, line in enumerate(doc.lines, 1):
            for match in rule.pattern.finditer(line):
                before = line[: match.start()]
                if rule.guard and rule.guard.search(
                    before if rule.rule_id.startswith("number") else match.group(0),
                ):
                    continue
                text = _snippet(line, match.start(), match.end())
                hits.append(
                    Hit(
                        rule.rule_id,
                        rule.level,
                        rule.note,
                        number,
                        match.start() + 1,
                        text,
                    ),
                )
    return hits


def heading_hits(doc: Document) -> list[Hit]:
    """Flag Title Case headings (English only) and gaps in heading numbering."""
    hits: list[Hit] = []
    last_child: dict[str, int] = {}
    for number, text in doc.headings:
        numbered = re.match(r"((?:\d+\.)*)(\d+)\.?\s", text)
        if numbered:
            parent, index = numbered.group(1), int(numbered.group(2))
            previous = last_child.get(parent)
            if previous is not None and index > previous + 1:
                note = f"Numbering skips from {parent}{previous} to {parent}{index}"
                hits.append(Hit("numbering", CHECK, note, number, 1, text))
            last_child[parent] = index
        if doc.lang != EN:
            continue
        words = [
            w
            for w in WORD.findall(re.sub(r"^[\d.\s]+", "", text))[1:]
            if not STOPWORD_HEADING.match(w)
        ]
        capitalised = [w for w in words if w[0].isupper() and not w.isupper()]
        if (
            len(capitalised) >= TITLE_CASE_MIN
            and len(capitalised) / max(len(words), 1) >= TITLE_CASE_RATIO
        ):
            note = "Title Case heading: sentence case, keeping proper nouns"
            hits.append(Hit("title-case", CHECK, note, number, 1, text))
    return hits


def paragraph_hits(doc: Document) -> list[Hit]:
    """Flag one-line paragraphs, punchline endings, long and nominal sentences."""
    hits: list[Hit] = []
    long_limit = LONG_SENTENCE[doc.lang]
    for number, paragraph in doc.paragraphs:
        if DOT_LEADER.search(paragraph):
            continue
        parts = sentences(paragraph)
        counts = [word_count(s) for s in parts]
        is_list_item = bool(LIST_ITEM.match(doc.lines[number - 1]))
        if (
            not is_list_item
            and len(parts) == 1
            and 0 < counts[0] <= SHORT_PARAGRAPH_WORDS
            and not parts[0].endswith(":")
        ):
            hits.append(
                Hit(
                    "short-paragraph",
                    CHECK,
                    "One-line paragraph: aphorism or drum beat?",
                    number,
                    1,
                    parts[0],
                ),
            )
        if (
            len(parts) >= PUNCHLINE_MIN_SENTENCES
            and 1 < counts[-1] <= PUNCHLINE_MAX_WORDS
        ):
            hits.append(
                Hit(
                    "punchline",
                    CHECK,
                    "Short closing sentence: manufactured punchline?",
                    number,
                    1,
                    parts[-1],
                ),
            )
        for sentence, count in zip(parts, counts, strict=True):
            if count > long_limit:
                note = f"Sentence of {count} words: split it if it needs a second read"
                hits.append(
                    Hit(
                        "long-sentence",
                        CHECK,
                        note,
                        number,
                        1,
                        _snippet(sentence, 0, 60),
                    ),
                )
            if (
                doc.lang == DE
                and len(NOMINAL_DE.findall(sentence)) >= NOMINAL_PER_SENTENCE
            ):
                note = "Drei oder mehr Substantive auf -ung, -heit, -keit, -tion"
                hits.append(
                    Hit(
                        "nominal-density-de",
                        CHECK,
                        note,
                        number,
                        1,
                        _snippet(sentence, 0, 60),
                    ),
                )
    return hits


def term_hits(doc: Document) -> list[Hit]:
    """Flag defined terms and proper nouns spelt more than one way."""
    text = "\n".join(doc.lines)
    candidates = {
        m.group(0)
        for m in TERM.finditer(text)
        if " " in m.group(0) or "-" in m.group(0) or len(m.group(0)) >= MIN_TERM_LENGTH
    }
    seen: dict[str, set[str]] = {}
    for term in candidates:
        key = re.sub(r"[\s-]", "", term).lower()
        if key in seen:
            continue
        parts = re.split(r"[\s-]+", term)
        pattern = re.compile(
            r"\b" + r"[ \t-]?".join(re.escape(p) for p in parts) + r"\b",
            re.IGNORECASE,
        )
        surfaces = {m.group(0) for m in pattern.finditer(text)}
        seen[key] = {s[0].upper() + s[1:] for s in surfaces if not s.isupper()}
    hits: list[Hit] = []
    for forms in seen.values():
        if len(forms) > 1:
            listed = " / ".join(sorted(forms))
            hits.append(
                Hit(
                    "term-variants",
                    CHECK,
                    "Same term spelt differently: pick one form",
                    0,
                    0,
                    listed,
                ),
            )
    return hits


def mixed_forms(doc: Document) -> list[Hit]:
    """Report when one document uses several forms of the same convention."""
    text = "\n".join(doc.lines)
    groups = {
        "percent": [r"\bper cent\b", r"\bpercent\b", r"%", r"\bProzent\b"],
        "currency": [r"\bEUR\b", r"€"],
        "quotes": [r"[\"]", r"[“”„]"],
        "gender-de": [
            r"\w[*:_/]innen\b",
            r"\w[a-zäöü]Innen\b",
            r"\binnen und \w+er\b",
        ],
    }
    hits: list[Hit] = []
    for name, patterns in groups.items():
        used = [p for p in patterns if re.search(p, text)]
        if len(used) > 1:
            counts = ", ".join(f"{p} x{len(re.findall(p, text))}" for p in used)
            hits.append(
                Hit("mixed-forms", CHECK, f"Mixed {name} conventions", 0, 0, counts),
            )
    return hits


def statistics_block(doc: Document, hits: list[Hit]) -> dict[str, object]:
    """Compute rhythm and density figures for the summary."""
    lengths = [word_count(s) for _, p in doc.paragraphs for s in sentences(p)]
    words = sum(word_count(line) for line in doc.lines)
    low, high = RHYTHM_BAND
    in_band = sum(low <= n <= high for n in lengths) / max(len(lengths), 1)
    sd = statistics.pstdev(lengths) if lengths else 0.0
    per_k = PER_THOUSAND / max(words, 1)
    by_rule = Counter(h.rule_id for h in hits)
    return {
        "language": doc.lang,
        "words": words,
        "sentences": len(lengths),
        "mean_sentence": round(statistics.mean(lengths), 1) if lengths else 0.0,
        "sd_sentence": round(sd, 1),
        "share_8_20": round(in_band, 2),
        "uniform_rhythm": in_band >= UNIFORM_SHARE and sd < UNIFORM_SD,
        "rather_than_per_1000": round(by_rule["rather-than"] * per_k, 2),
        "rather_than_tic": by_rule["rather-than"] * per_k > RATHER_THAN_PER_1000,
        "fix_per_1000": round(sum(h.level == FIX for h in hits) * per_k, 2),
    }


def lint(path: Path, lang: str) -> tuple[dict[str, object], list[Hit]]:
    """Run every check on one file."""
    doc = load(path, lang)
    hits = (
        apply_rules(doc)
        + heading_hits(doc)
        + paragraph_hits(doc)
        + term_hits(doc)
        + mixed_forms(doc)
    )
    hits.sort(key=lambda h: (h.level != FIX, h.rule_id, h.line, h.col))
    return statistics_block(doc, hits), hits


def render_lint(
    path: Path,
    stats: dict[str, object],
    hits: list[Hit],
    limit: int,
) -> str:
    """Format the lint result as plain text, fixes first."""
    lines = [
        f"prose-lint: {path}",
        (
            f"language {stats['language']}, {stats['words']} words, "
            f"{stats['sentences']} sentences"
        ),
        f"rhythm: mean {stats['mean_sentence']} words (sd {stats['sd_sentence']}), "
        f"{round(float(str(stats['share_8_20'])) * 100)} % of sentences in 8-20 words"
        + (" [uniform rhythm]" if stats["uniform_rhythm"] else ""),
        f"density: 'rather than' {stats['rather_than_per_1000']} per 1,000 words"
        + (" [tic]" if stats["rather_than_tic"] else "")
        + f", fix-level hits {stats['fix_per_1000']} per 1,000 words",
        "",
    ]
    by_rule: dict[str, list[Hit]] = {}
    for hit in hits:
        by_rule.setdefault(hit.rule_id, []).append(hit)
    for rule_id, group in by_rule.items():
        lines.append(f"[{group[0].level}] {rule_id} ({len(group)}): {group[0].note}")
        lines.extend(
            f"  L{h.line}:{h.col}  {h.text}" if h.line else f"  {h.text}"
            for h in group[:limit]
        )
        if len(group) > limit:
            lines.append(f"  … {len(group) - limit} more")
    if not hits:
        lines.append("No hits.")
    return "\n".join(lines)


COMPARE_SETS = {
    EN: {
        "negations": r"\b(?:not|no|never|none|nor|without|cannot)\b|n't\b",
        "modals": r"\b(?:shall|must|will|may|might|could|should|can|would)\b",
        "hedges": r"\b(?:might|could|may|possibly|perhaps|often|usually|generally"
        r"|probably|likely|potentially)\b",
    },
    DE: {
        "negations": r"\b(?:nicht|kein\w*|nie|niemals|ohne|weder)\b",
        "modals": r"\b(?:muss|müssen|soll|sollen|wird|werden|kann|können|darf|dürfen"
        r"|könnte|könnten|sollte|sollten|würde|würden)\b",
        "hedges": r"\b(?:eventuell|möglicherweise|gegebenenfalls|vermutlich"
        r"|wahrscheinlich|oft|häufig|meist|in der Regel)\b",
    },
}
NUMBER = re.compile(r"\d+(?:[.,]\d+)*")
QUOTED = re.compile(r"[\"“„«]([^\"“”„«»\n]{3,200})[\"”“»]")
MULTI_TERM = re.compile(r"\b[A-ZÄÖÜ][\w-]*(?: [A-ZÄÖÜ][\w-]*)+\b")


@dataclass
class Comparison:
    """Meaning-bearing tokens that differ between an original and an edit."""

    language: str
    words: tuple[int, int]
    counts: dict[str, tuple[int, int]]
    numbers_missing: list[str]
    numbers_added: list[str]
    quotes_changed: list[str]
    terms_missing: list[str]


def compare(original: Path, edited: Path, lang: str) -> Comparison:
    """Compare the meaning-bearing tokens of two versions of a document."""
    before = mask_text(original.read_text(encoding="utf-8"), original.suffix.lower())
    after = mask_text(edited.read_text(encoding="utf-8"), edited.suffix.lower())
    resolved = detect_language(before) if lang == "auto" else lang
    nums_before = Counter(re.sub(r"[.,]", "", n) for n in NUMBER.findall(before))
    nums_after = Counter(re.sub(r"[.,]", "", n) for n in NUMBER.findall(after))
    counts = {
        name: (
            len(re.findall(p, before, re.IGNORECASE)),
            len(re.findall(p, after, re.IGNORECASE)),
        )
        for name, p in COMPARE_SETS[resolved].items()
    }
    flat_after = " ".join(after.split())
    return Comparison(
        language=resolved,
        words=(word_count(before), word_count(after)),
        counts=counts,
        numbers_missing=sorted((nums_before - nums_after).elements()),
        numbers_added=sorted((nums_after - nums_before).elements()),
        quotes_changed=[
            q for q in QUOTED.findall(before) if " ".join(q.split()) not in flat_after
        ],
        terms_missing=sorted(
            set(MULTI_TERM.findall(before)) - set(MULTI_TERM.findall(after)),
        ),
    )


def render_compare(result: Comparison) -> str:
    """Format the comparison as plain text."""
    old_words, new_words = result.words
    lines = [
        f"prose-lint compare ({result.language}): words {old_words} -> {new_words}",
    ]
    for name, (old, new) in result.counts.items():
        flag = "" if old == new else "  [changed]"
        lines.append(f"{name}: {old} -> {new}{flag}")
    lists = {
        "numbers missing": result.numbers_missing,
        "numbers added": result.numbers_added,
        "quotes changed": result.quotes_changed,
        "terms missing": result.terms_missing,
    }
    for label, values in lists.items():
        lines.append(f"{label}: {', '.join(values) if values else 'none'}")
    lines.append(
        "Separators are ignored when matching numbers, so a format change (1.250 to "
        "1,250) is not reported. A digit from 1 to 9 that was spelt out appears as "
        "missing.",
    )
    return "\n".join(lines)


def main() -> int:
    """Parse arguments and run lint or compare mode."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "files",
        nargs="+",
        type=Path,
        help="FILE, or ORIGINAL EDITED with --compare",
    )
    parser.add_argument("--lang", choices=["auto", EN, DE], default="auto")
    parser.add_argument(
        "--limit",
        type=int,
        default=DEFAULT_LIMIT,
        help="hits shown per rule",
    )
    parser.add_argument(
        "--compare",
        action="store_true",
        help="compare ORIGINAL and EDITED",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="print JSON instead of text",
    )
    args = parser.parse_args()
    missing = [str(f) for f in args.files if not f.is_file()]
    if missing:
        parser.error(f"not a file: {', '.join(missing)}")
    if args.compare:
        if len(args.files) != 2:  # noqa: PLR2004
            parser.error("--compare takes exactly two files: ORIGINAL EDITED")
        result = compare(args.files[0], args.files[1], args.lang)
        print(
            json.dumps(asdict(result), ensure_ascii=False, indent=2)
            if args.json
            else render_compare(result),
        )
        return 0
    for index, path in enumerate(args.files):
        stats, hits = lint(path, args.lang)
        if args.json:
            print(
                json.dumps(
                    {"file": str(path), **stats, "hits": [asdict(h) for h in hits]},
                    ensure_ascii=False,
                ),
            )
            continue
        if index:
            print()
        print(render_lint(path, stats, hits, args.limit))
    return 0


if __name__ == "__main__":
    sys.exit(main())
