# KI-Signale im Deutschen

A catalogue of German wording and sentence patterns that make a client document read as machine-written or translated from English.
The explanations are in English and the examples in German.
Read it in passes 2 and 3 for German text, and whenever a lint hit needs a second opinion.
It extends [german.md](german.md), which keeps the register, the calibration table and the locale rules.
[ai-tells.md](ai-tells.md) has the English originals and the reasoning behind each pattern, and its section 7 (extra questions for the sentence diagnosis) applies to German text unchanged.

Detox is an English-only skill, so the German patterns here are our own transfers of its English ones.
They have not been checked by a German-language editor, and the examples are illustrative, with invented names and figures.
The lint rule that finds each pattern is named in brackets where one exists.

## Contents

- 1. Vocabulary
- 2. Phrases
- 3. Satzanfänge und Satzenden
- 4. Patterns with before and after
- 5. Plain-word substitutions
- 6. Worked examples

## 1. Vocabulary

The words already listed in section 4 of german.md stay there.
This table adds words that file does not have.
[inflated-claim-de, watch-de]

| Word | Why it reads as a tell | Use instead |
| --- | --- | --- |
| Meilenstein, Wendepunkt | Asserts importance without a consequence | the date, the decision or the effect |
| Weckruf, Paukenschlag | Newsroom drama in a business document | the finding, stated plainly |
| wegweisend, revolutionär | Asserts a size of change that the evidence has to show | the measured change |
| ausgeklügelt, hochentwickelt | Claims quality and states none | what is complex, or cut |
| umfassend | Asserts completeness | what it covers: "deckt alle 14 Quellsysteme ab" |
| sogenannt | Introduces an invented label | say what the thing is |

"Meilenstein" is the right word in a project plan with dates.
Flag it in running text, and leave it in a milestone table.

## 2. Phrases

### Einleitende Floskeln

Delete these and start with the content.
[stock-de, signpost-de]

- "Ohne weitere Umschweife", "wie wir alle wissen"
- "Es ist wichtig zu beachten, dass", "es sei darauf hingewiesen"
- "In der heutigen Zeit", "in der heutigen Welt"
- "Hier ist der Punkt", "und das ist gut so"

### Leere Absicherungen und Rahmungen

[empty-transition-de, opener-de]

- "Um ehrlich zu sein", "ehrlich gesagt"
- "Wenn es um ... geht"
- "Die Realität ist", "die Wahrheit ist", "Fakt ist"
- "Vor diesem Hintergrund", "darauf aufbauend", "mit diesem Wissen", "einen Schritt weiter"

### Verwaltungs- und Füllwendungen

[bureaucratic-de]

- "zum jetzigen Zeitpunkt", "zu diesem Zeitpunkt"
- "aufgrund der Tatsache, dass", "im Falle, dass"
- "eine große Anzahl von", "eine Vielzahl von"
- "in der Lage sein", "in unmittelbarer Nähe von"

## 3. Satzanfänge und Satzenden

[opener-de, closer-de]

| Muster | Vorher | Nachher |
| --- | --- | --- |
| Nun, | "Nun, die Migration lief planmäßig." | "Die Migration lief planmäßig." |
| Also, | "Also, die Schätzung ist grob." | "Die Schätzung ist grob." |
| Tja, | "Tja, die Daten stützen das nicht." | "Die Daten stützen das nicht." |
| Im Grunde, | "Im Grunde wird die Tabelle jede Nacht neu aufgebaut." | "Die Tabelle wird jede Nacht neu aufgebaut." |
| Ehrlich gesagt, | "Ehrlich gesagt war die Stichprobe klein." | "Die Stichprobe umfasste 30 Läufe." |
| ..., oder? | "Das ist die bessere Option, oder?" | "Das ist die bessere Option." |
| ..., nicht wahr? | "Der Plan ist realistisch, nicht wahr?" | "Der Plan ist realistisch." |

"Also" am Satzanfang ist richtig, wenn es eine Folgerung einleitet: "Also verschieben wir den Start."

## 4. Patterns with before and after

### Grundlegende Veränderung

[fundamental-de]

| Vorher | Nachher |
| --- | --- |
| "Das verändert grundlegend, wie Analysten arbeiten." | "Analysten fragen eine zertifizierte Tabelle ab und gleichen keine drei Exporte mehr von Hand ab." |
| "Das ist ein grundlegender Wandel in der Planung." | "Die Planung wechselt von einem Jahres- zu einem Quartalszyklus." |

### Aufgeblähte Behauptungen

[inflated-claim-de, banned-de]

| Vorher | Nachher |
| --- | --- |
| "Ein bahnbrechendes Assessment und ein Meilenstein für den Kunden." | "Das Assessment deckt 14 Quellsysteme ab und lieferte seine Roadmap am 02.11.2026." |
| "Ein Paukenschlag bei den Ergebnissen." | "Aufbewahrte Vorversionen machen 41,2 % des physischen Volumens aus." |

### Leere Übergänge

[empty-transition-de]

| Vorher | Nachher |
| --- | --- |
| "Vor diesem Hintergrund wenden wir uns den Kosten zu." | "Die Rechenkosten sind der größte Posten." |
| "Darauf aufbauend folgt als Nächstes der Semantic Layer." | "Als Nächstes folgt der Semantic Layer." |
| "Die Realität ist, dass die meisten Teams keine Plattformgruppe besetzen können." | "Die meisten Teams können keine Plattformgruppe besetzen." |
| "Wenn es um Sicherheit geht, ist das Werkzeug schwach." | "Das Werkzeug hat kein Audit-Log." |

### Reflexartige Dreierlisten

Die Dichte von Aufzählungen nach dem Muster "a, b und c" steht in der Lint-Ausgabe.
Die Markierung ist vorläufig, weil noch kein Kundendokument ausgemessen wurde.

| Vorher | Nachher |
| --- | --- |
| "Das Programm bringt Tempo, Qualität und Einsparungen." | "Das Programm senkt die nächtliche Laufzeit von sechs auf zwei Stunden." |
| "Vertrauen entsteht durch Genauigkeit, Transparenz und Verlässlichkeit." | "Vertrauen setzt Zahlen voraus, die zur Quelle passen, und wir zeigen den Abgleich." |

Eine echte Dreierliste bleibt: ein Umfang mit drei Lieferobjekten, drei benannte Systeme.
Prüfen Sie, ob ein Punkt wegfallen oder ein vierter hinzukommen könnte, ohne dass etwas fehlt.

### Aufzählung bedeutungsähnlicher Adjektive

[synonym-list-de]

| Vorher | Nachher |
| --- | --- |
| "eine umfassende, innovative und nachhaltige Plattform" | "eine Plattform, die 14 Monate ohne ungeplanten Ausfall lief" |
| "ein ganzheitlicher, zukunftssicherer und leistungsstarker Ansatz" | "ein Ansatz, der alle fünf Schichten abdeckt und 300 Anfragen pro Sekunde bedient" |

### Zirkuläre Definitionen und Substantivketten

| Vorher | Nachher |
| --- | --- |
| "Das System ermöglicht es Nutzern, seine Funktionen zu nutzen." | "Analysten können jeden Bericht als CSV exportieren." |
| "die Bereitstellungsprozessoptimierungsmaßnahme" | "die Maßnahme, die den Bereitstellungsprozess verbessert" |

### Fragmente zur Betonung

[fragment-run, short-paragraph, punchline]

| Vorher | Nachher |
| --- | --- |
| "Kosten sanken. Qualität stieg. Jedes Mal. Ohne Ausnahme." | "Die Kosten sanken in allen sechs Quartalen, die Qualität stieg in fünf." |
| "Eine Plattform. Ein Team. Eine Wahrheit." | "Ein Team betreibt die Plattform und verantwortet ihre Kennzahlendefinitionen." |

### Erfundene Bezeichnungen

[scare-label-de]

| Vorher | Nachher |
| --- | --- |
| "die sogenannte „flache Lastkurve“" | "eine flache Lastkurve, also Rechenlast, die gleichmäßig über den Tag verteilt ist" |
| "unsere „Nordstern“-Kennzahl" | "die Kennzahl, nach der wir ordnen: pünktlich gelieferte Bestellungen" |

### Pfeile im Fließtext

[arrow]

| Vorher | Nachher |
| --- | --- |
| "Laden -> Transformieren -> Veröffentlichen." | "Die Daten werden geladen, transformiert und dann veröffentlicht." |
| "Altsystem → Zielzustand" | "vom Altsystem zum Zielzustand" |

In einer Abbildungsbeschriftung, einer Zuordnungstabelle und im Code ist ein Pfeil in Ordnung.

### Vorspiel, falsche Reaktion und gespielte Wärme

| Vorher | Nachher |
| --- | --- |
| "Ich war ehrlich überrascht, dass die Aufbewahrung auf 30 Tage steht." | "Die Aufbewahrung steht auf 30 Tage." |
| "Wir freuen uns sehr, die Ergebnisse des Assessments zu teilen." | "Die Ergebnisse des Assessments folgen." |

### Korrekturen und Fehlermeldungen

Zuerst nennen, was der Leser erhalten hat, dann die Ursache.
Eine vermutete Ursache bleibt von der geprüften Korrektur getrennt.

| Vorher | Nachher |
| --- | --- |
| "Aufgrund eines Problems in der Tabellenformel wurde im Diagramm möglicherweise ein falscher Wert angezeigt." | "Das Diagramm auf Seite 12 nennt den Umsatz 2025 mit 4,2 Mio. EUR. Der geprüfte Abschluss weist 2,4 Mio. EUR aus. Korrigieren Sie das Diagramm und die beiden Sätze, die darauf verweisen. Die Tabellenformel braucht eine eigene Prüfung, bevor wir eine Ursache nennen." |

## 5. Plain-word substitutions

[bureaucratic-de]

| Wenn der Entwurf sagt | Schreiben Sie |
| --- | --- |
| zum jetzigen Zeitpunkt, zu diesem Zeitpunkt | jetzt, oder ein Datum |
| aufgrund der Tatsache, dass | weil |
| im Falle, dass | wenn |
| eine große Anzahl von, eine Vielzahl von | viele, oder die Zahl |
| in der Lage sein zu | können |
| in unmittelbarer Nähe von | neben, bei |

"Umsetzung" und "Methodik" gehören nicht auf diese Liste.
In einem Beratungsdokument sind beide oft das genaue Wort: Eine Umsetzung ist ein Leistungsbestandteil und eine Methodik ein definiertes Vorgehen.

## 6. Worked examples

**Allgemeiner Text.**
Vorher: "In der heutigen schnelllebigen Datenlandschaft ist es entscheidend, die Vielschichtigkeit von Plattformentscheidungen zu verstehen. Lassen Sie uns eintauchen, wie diese robusten Lösungen Teams helfen, modernste Technologie zu nutzen."
Nachher: "Eine Plattformentscheidung hängt von zwei Dingen ab: den Lasten, die sie tragen muss, und den Fähigkeiten des Teams. Dieser Abschnitt bewertet jede Option nach beiden."

**Befund.**
Vorher: "Die Sitzung des Lenkungskreises war eine umfassende und transformative Diskussion, die zentrale Fragen der Lieferung auf sinnvolle Weise grundlegend adressierte."
Nachher: "Der Lenkungskreis hat den überarbeiteten Plan am 09.10.2026 genehmigt und den Go-live von März auf Mai verschoben."

**Kapitelanfang.**
Vorher: "Im reichen Gewebe der Unternehmensdaten gibt es nur wenige so spannende Geschichten wie die, die sich nun entfaltet. Das ist nicht nur eine Migration, sondern eine Reise ins Herz dessen, was Daten ausmacht."
Nachher: "Example Retail verlagert zwischen Januar und Juni 530 nächtliche Aufgaben von einem Orchestrator auf einen anderen."

**Analyse.**
Vorher: "Künftig müssen Stakeholder innovative Ansätze nutzen, um in der herausfordernden Landschaft der digitalen Transformation im Datenökosystem zu navigieren."
Nachher: "Teams, die ihre Rechenkosten senken wollen, müssen aufhören, jede Tabelle jede Nacht neu aufzubauen. Die meisten haben noch nicht damit begonnen."
