# German reference

How German client documents at MULTIPLAI should read, and how to get a draft there.
The explanations are in English and the examples in German.
No German exemplar document was supplied, so the exemplars in section 8 carry the patterns of the English exemplars over into German and are illustrative.
Replace them with lines from a German deliverable the team rates when one is available.

## Contents

- 1. Register by genre
- 2. Calibrating claims
- 3. Patterns with before and after
- 4. Vocabulary
- 5. Locale and mechanics
- 6. English interference in German
- 7. Contract language
- 8. What good looks like

## 1. Register by genre

| Genre | Actor | Verbs | Qualifiers | Lists | Notes |
| --- | --- | --- | --- | --- | --- |
| Vertrag oder Leistungsbeschreibung | The defined parties: "MULTIPLAI", "der Auftraggeber", "die Parteien" | Present tense for services ("MULTIPLAI prüft"), "verpflichtet sich" or "hat ... zu" for obligations | None on commitments | Closed, parallel, verb-first or noun-first throughout | Restating a clause can be deliberate, so leave it and flag it |
| Angebot | "wir" and the client by name, the reader as "Sie" | Present tense with a date for commitments ("Wir liefern bis 09.10.2026") | Only on assumptions and dependencies | Closed for scope and deliverables | Order each section as client need, then what we do, then proof |
| Assessment oder Bericht | "wir" or "das Assessment", one of the two throughout | Perfekt or Präteritum for what was measured, present for what holds | On hypotheses and on evidence gaps, said once | Parallel | Every finding carries its evidence and a cross-reference |
| Management Summary | "wir" | Present and imperative | As in the body, never fewer | Short, ranked | Answer in the first two sentences, plainer words than the body |
| E-Mail | "ich" or "wir", the reader as "Sie" | Imperative or a direct request with a date | Minimal | Rarely | Recommendation or request in the first two lines |
| Folientext | Implicit | Titles are full assertions of at most about 15 words | As in the source | Bullets prove the title | Every bullet supports its title |

Use "Sie" in every client document unless the user writes "du" to that client.
Capitalise "Sie", "Ihr" and "Ihnen" in the polite form.
Write MULTIPLAI in capitals.
Humour, exclamation marks and decorative images stay out of client documents.

## 2. Calibrating claims

The test for every sentence is what the evidence supports.

| Kind | Overstated | Softened | Calibrated |
| --- | --- | --- | --- |
| Zusage | "MULTIPLAI garantiert eine nahtlose Migration." | "MULTIPLAI könnte die Migration gegebenenfalls unterstützen." | "MULTIPLAI liefert den Migrationsplan bis zum 09.10.2026." |
| Befund | "Die Plattform ist grundlegend kaputt." | "Es scheint gewisse Zuverlässigkeitsprobleme zu geben." | "Drei von 30 nächtlichen Läufen endeten nach weniger als zehn Minuten und meldeten Erfolg." |
| Hypothese | "Die Läufe überspringen ihre Sensoren." | "Es könnte eventuell möglicherweise sein, dass Sensoren übersprungen werden." | "Eine übersprungene Sensorkette würde das erklären. Das ist eine Hypothese, und wir empfehlen, sie zuerst zu prüfen." |
| Empfehlung | "Der Kunde muss Airflow sofort ersetzen." | "Man sollte vielleicht über Alternativen nachdenken." | "Behalten Sie Airflow für die Orchestrierung und verlagern Sie die Transformationen während des Data-Vault-Aufbaus in ein Framework." |
| Evidenzlücke | "Die Kosten werden korrekt zugeordnet." | "Die Kosten werden eventuell nicht vollständig zugeordnet." | "Kosten auf Ressourcenebene lagen dem Assessment nicht vor, daher lassen sich Ausgaben keinem Dataset zuordnen." |

German drafts hedge through the Konjunktiv II and through stacked particles.
"Wir würden empfehlen" becomes "Wir empfehlen".
"könnte eventuell" keeps at most one of the two.

The Konjunktiv I is the right tool for a stakeholder statement, because it marks the claim as reported and keeps it apart from what was observed: "Das Team gibt an, der Maintainer sei nicht mehr aktiv. Das Datum des letzten Commits konnten wir nicht bestätigen."

## 3. Patterns with before and after

### Words

| Pattern | Before | After |
| --- | --- | --- |
| Füllwort | "Das ist eigentlich durchaus ein wichtiger Punkt." | "Zwei Staging-Tabellen blockieren 96 nachgelagerte Objekte." |
| Copula avoidance | "Die Data-Vault-Schicht stellt das Herzstück der Architektur dar." | "Die Data-Vault-Schicht ist der Kern der Architektur." |
| Nominalstil | "Die Durchführung der Bewertung erfolgt durch MULTIPLAI." | "MULTIPLAI bewertet die Optionen." |
| Funktionsverbgefüge | "Die Lösung kommt zum Einsatz." | "Das Team setzt die Lösung ein." |
| Funktionsverbgefüge | "Wir bringen die Migration zur Umsetzung." | "Wir setzen die Migration um." |
| Buzzword | "ein ganzheitlicher, zukunftssicherer Ansatz mit echtem Mehrwert" | the measurable property: "ein Ansatz, der alle fünf Schichten abdeckt" |
| Vage Größe | "erhebliche Einsparungen" | "eine Einsparung von 35 bis 70 % auf den betroffenen Datasets" |
| Amtsdeutsch | "Im Rahmen der Analyse wurden hinsichtlich der Kosten folgende Punkte festgestellt" | "Bei der Analyse der Kosten haben wir festgestellt" |
| Thematik, Problematik | "die Thematik der Kostenzuordnung" | "die Kostenzuordnung" |

### Sentences

| Pattern | Before | After |
| --- | --- | --- |
| Kontrastfigur ohne echte Alternative | "Die größte Chance ist nicht eine Plattformmigration, sondern der Wechsel zu inkrementellen Updates." | "Die größte Chance ist der Wechsel von nächtlichen Voll-Rebuilds zu inkrementellen Updates. Er braucht weder eine neue Plattform noch ein neues Werkzeug." |
| "nicht nur ..., sondern auch" | "Es geht nicht nur um Technologie, sondern auch um Menschen." | "Die Einführung braucht neue Rollen: einen Owner für Semantik-Standards und einen für die Agenten-Runtime." |
| Doppelpunkt-Pointe | "Das Ergebnis: Chaos." | "Dadurch stehen hinter zwölf Kacheln namens AOV elf verschiedene Definitionen." |
| Pointe am Absatzende | "Das Problem ist die Lieferkette, nicht das Konzept." | "Der Ansatz ist richtig. Das Risiko liegt im Bezug der Binärdatei: Sie wird beim Build ohne Prüfsumme heruntergeladen." |
| Ankündigung | "An dieser Stelle sei ein Punkt besonders hervorgehoben." | Delete it and start with the point. |
| Kommentierender Nachsatz | "Die Kosten sanken um 21 %, was die Wirksamkeit der Maßnahme unterstreicht." | "Die Kosten sanken um 21 %." |
| Unpersönliche Bewertung | "Es wird empfohlen, die Aufbewahrung zu verkürzen." | "Wir empfehlen, die Aufbewahrung auf 48 Stunden zu verkürzen." |
| Passiv ohne Akteur | "Die Entscheidung wurde getroffen, die Bridge-Tabellen zu verschieben." | "Das BI-Team hat die Bridge-Tabellen verschoben." |
| Schachtelsatz | "Die Tabellen, die, da die Quelle, die nachts geladen wird, oft verspätet ist, nicht rechtzeitig fertig werden, blockieren den Lauf." | "Die Quelle wird nachts geladen und ist oft verspätet. Deshalb werden die Tabellen nicht rechtzeitig fertig und blockieren den Lauf." |
| Weite Satzklammer | "Wir werden die Ergebnisse nach Abschluss der dritten Phase und der Abstimmung mit dem Lenkungskreis im Rahmen einer Präsentation vorstellen." | "Nach der dritten Phase stimmen wir die Ergebnisse mit dem Lenkungskreis ab und stellen sie vor." |

### Verben und Subjekte

The lint cannot find these, because the sentences contain no listed word.
The diagnosis step in the skill looks for them sentence by sentence.

| Pattern | Before | After |
| --- | --- | --- |
| Menschliches Verb bei einer Sache | "Jede Box trägt den Wortlaut der Folie, und ihr Panel benennt die vorgeschlagene Technologie." | "Jede Box übernimmt den Wortlaut der Folie, und ihr Feld zeigt die vorgeschlagene Technologie." |
| Menschliches Verb, Akteur verfügbar | "Jedes Werkzeug erhält zwei Bewertungen von 1 bis 5 für das Merkmal, das die Fähigkeit trägt." | "Wir bewerten jedes Werkzeug zweimal auf einer Skala von 1 bis 5, und zwar für das Merkmal, das die Fähigkeit bereitstellt." |
| Layout statt Aussage | "Vier Spalten, acht nummerierte Zonen, entnommen der Zielfolie vom 14.09.2026." | "Das Schaubild hat vier Spalten und acht nummerierte Zonen aus der Zielfolie vom 14.09.2026." |
| Leseregel in geliehenen Verben | "Fett markiert ein Werkzeug, das mehr als eine Zone oder Aufgabe abdeckt." | "Ein fett gesetztes Werkzeug unterstützt mehr als eine Zone oder Aufgabe." |
| Position beschrieben | "Optionen mit gleichen Bewertungen stehen nebeneinander, und Cloud Run taucht unter Zone 2 und Zone 4 auf, weil es beide bedient." | "Optionen mit gleichen Bewertungen stehen nebeneinander. Cloud Run steht unter Zone 2 und Zone 4, weil es beide unterstützt." |

Verbs to check when the subject is a thing, a part of the document or a feature: trägt, hält, nennt oder benennt (for a box or a panel), nimmt auf, erhält, sitzt, liegt in, deckt ab, bedient, adressiert, bildet ab, greift, taucht auf, steht für, spricht an, kommt vor, entnommen.
They are `check` candidates and not errors.
"Cloud Run betreibt Anwendungen" and "der Server speichert Läufe" describe what the system does and stay.
"Eine Box trägt Wortlaut" and "ein Panel benennt eine Technologie" do not.

Replacements, in order of preference:

1. The person as subject, where the source supports one: "wir bewerten", "das Team prüft".
2. A literal verb that keeps the thing as the subject: ist, hat, zeigt, listet, wiederholt, enthält, nutzt, unterstützt, stellt bereit.
3. A sentence about the fact instead of the structure, when the sentence only describes the layout.

A sentence that opens a section or caption without a verb ("Vier Spalten, acht Zonen.") becomes a full sentence.
A fragment is fine in a list item, a table cell and a slide title.

Do not move the subject to a person without checking the source: a slide that names a technology and a team that names it are different statements.

### Paragraphs

- A one-sentence paragraph used for emphasis joins the paragraph it belongs to, or becomes its first sentence.
- A closing sentence that is shorter and punchier than the rest of its paragraph usually goes.
- A paragraph that only announces what follows ("Im Folgenden wird ... dargestellt") goes when the heading already says it.
- A closing paragraph that restates the whole document goes, except in a Management Summary or a closing section the template requires.

### "statt" and its relatives

German drafts translated from English, or written by a model, overuse "statt", "anstatt" and "nicht ..., sondern".
Keep them where the alternative is one the reader would otherwise assume ("Festpreis statt Aufwandsabrechnung").
Elsewhere, state the claim alone.

## 4. Vocabulary

### Banned, with replacements

| Word or phrase | Use instead |
| --- | --- |
| integraler Bestandteil | Teil, oder the dependency: "Die Migration hängt davon ab" |
| vielfältige Möglichkeiten | the possibilities by name |
| in der heutigen Zeit, in der heutigen Welt | delete |
| auf das nächste Level, auf ein neues Level | the measurable change |
| revolutionieren, bahnbrechend, Quantensprung, Paradigmenwechsel, Game-Changer | the measurable advantage, or nothing |
| nahtlos | ohne manuelle Schritte, ohne Ausfallzeit |
| ganzheitlich | durchgängig, über alle fünf Schichten, or the actual scope |
| Mehrwert, Synergien | the specific saving, benefit or shared component |
| zielführend | sinnvoll, geeignet, or the reason |
| spannend | delete, or say why it matters to the reader |
| essenziell, tiefgreifend, transformativ | the consequence |
| Leuchtturm, Reise, Transformationsreise | Pilot, Programm, or the phases by name |
| eintauchen, beleuchten, unterstreichen | untersuchen, darstellen, zeigen, or cut |
| abholen (Menschen) | einbinden, informieren |
| zeitnah | bis zum 30.11.2026, or a date; in a contract keep it and flag it |
| proaktiv | frühzeitig, or the action |
| Kernstück, Herzstück, Schlüsselrolle | Kern, or the dependency |
| fungiert als, stellt ... dar | ist |

### Watch words

Keep these only in their precise sense: robust (Statistik), innovativ, umfassend, maßgeblich, entscheidend, nachhaltig (ESG or "dauerhaft"), Landschaft (legitimate in "Systemlandschaft"), Ökosystem, State of the Art, Best Practice, optimal (only with a target function), dient als.

### Floskeln and Amtsdeutsch

| Phrase | Use instead |
| --- | --- |
| Es ist wichtig zu beachten, dass; Es sei darauf hingewiesen, dass | delete |
| Zusammenfassend lässt sich sagen | delete, or "Insgesamt" once in a summary |
| Wie bereits erwähnt | delete, or a cross-reference: "siehe Abschnitt 4.1" |
| im Rahmen von | bei, während, als Teil von |
| hinsichtlich, bezüglich, in Bezug auf | zu, für, bei, or restructure |
| seitens des Kunden | der Kunde, as subject |
| mittels, zwecks | mit, für, um ... zu |
| vorgenannt, obige, o. g. | dieser, the name |
| Fakt ist | delete |
| eigentlich, ziemlich, irgendwie, durchaus, tatsächlich, wirklich, absolut, definitiv, letztendlich, quasi, sozusagen | delete |

## 5. Locale and mechanics

**Dates and times.**
DD.MM.YYYY in running text and tables: 31.07.2026.
Ranges: "01.09.2026 bis 30.11.2026", or "2019-2024" for years with a hyphen.
24-hour clock with a colon: "07:00 Uhr".

**Numbers.**
Thousands with a point and decimals with a comma: 1.250 and 43,7.
Spell out null to neun in running text, but use digits with units, in tables, in ranges and in names such as Phase 1.
Round consistently within a table and between a table and the text that cites it.

**Percentages and currency.**
A space between number and symbol: "25 %", and a non-breaking space where the format allows it.
Currency after the amount: "24.450 EUR" or "24.450 €", one form per document.
Drop the old ",-" ending.

**Punctuation.**
No Gedankenstrich, in any length, despite Duden convention: use a comma, a colon, brackets or a full stop.
The hyphen stays for compounds ("SAP-Migration", "Data-Vault-Schicht") and for the Ergänzungsstrich ("Daten- und KI-Plattform").
No comma before "und" or "oder" in a simple enumeration.
Set the optional comma before an extended infinitive, because it helps the reader.
German quotation marks: „...“ and ‚...‘.
No exclamation marks in client documents.

**Compounds with English terms.**
Couple them with hyphens: "Data-Vault-Schicht", "Semantic-Layer-Integration", "Looker-Migration".
A space inside the compound ("Data Vault Schicht") is wrong.
Choose one grammatical gender for each English term and keep it ("der Semantic Layer", "die Pipeline", "das Dashboard").

**Abbreviations.**
"z. B.", "d. h.", "u. a." with a space, or written out in running text, one choice per document.

**Gendered language.**
Keep the author's or the client's form and make it consistent.
Do not introduce a gender form the draft does not use, and report a mix of forms (Doppelpunkt, Sternchen, Paarform, generisches Maskulinum).

**Headings.**
No all-caps headings unless the template prescribes them, and no full stop at the end.
Check heading numbering for gaps such as 8.9 followed by 8.11.

## 6. English interference in German

| Interference | Before | After |
| --- | --- | --- |
| Sinn machen | "Das macht Sinn." | "Das ist sinnvoll." or "Das ergibt Sinn." |
| in + year | "in 2026" | "2026" or "im Jahr 2026" |
| einmal mehr | "Das zeigt einmal mehr" | "Das zeigt erneut" |
| adressieren | "ein Problem adressieren" | "ein Problem angehen, lösen, behandeln" |
| realisieren (bemerken) | "Wir haben realisiert, dass" | "Wir haben bemerkt, dass" |
| basierend auf | "basierend auf den Daten" | "auf Grundlage der Daten" |
| am Ende des Tages | "Am Ende des Tages zählt" | "Letztlich zählt", or delete |
| nicht wirklich | "nicht wirklich belastbar" | "nicht belastbar" or "nur eingeschränkt belastbar" |
| Ich denke | "Ich denke, dass" | "Ich meine, dass" or "Wir empfehlen" |
| Denglisch verbs | "committen, challengen, supporten, launchen" | "zusagen, hinterfragen, unterstützen, einführen" |
| Decision making | "eine Entscheidung machen" | "eine Entscheidung treffen" or "entscheiden" |

Established technical terms stay in English when the client uses them: Data Vault, Semantic Layer, Pipeline, Deployment, Explore, Dashboard.
Use the client's term consistently and decline it as German grammar requires.

## 7. Contract language

A Leistungsbeschreibung mixes a description of services with obligations, and the verbs show which is which.

- "MULTIPLAI prüft", "MULTIPLAI liefert": present tense describes the services.
- "verpflichtet sich", "hat ... zu", "muss": an obligation on a named party.
- "ist berechtigt", "kann": discretion.
- "gilt als abgenommen": a legal fiction, as in deemed acceptance after five business days.
- "soll" is weaker than "muss" in German legal usage and can read as a target, not a duty.
Flag an obligation written with "soll" for the author.

Some words have a defined legal meaning and must never be "simplified".
"Unverzüglich" means "ohne schuldhaftes Zögern" under § 121 BGB and is not the same as "sofort".
"Angemessen", "wesentlich" and "zeitnah" are negotiated vagueness: flag them, do not sharpen them.

What the copyedit does in a contract:

- It fixes typos, inconsistent defined terms, number formats that do not match, and arithmetic that does not reconcile (reported, never silently corrected).
- It flags an obligation without a named party, an ambiguous capacity figure and a clause restated several times.
- It checks every price table: module prices, discount, total and invoice schedule must reconcile.

## 8. What good looks like

These lines carry the patterns of the English exemplars into German.
They are illustrative, not quotations.

**Antwort zuerst.**
"Ziel dieses Projekts ist die Entscheidungsgrundlage für die künftige KI- und ML-Plattform des Kunden: eine priorisierte Anforderungsliste, eine geprüfte Plattformentscheidung mit Zielarchitektur und ein Zielbetriebsmodell, das festlegt, wer die Plattform verantwortet, aufbaut und betreibt."

**Konkrete Ausgangslage.**
"Das Experiment-Tracking läuft über lokale MLflow-Instanzen. Es gibt keine Model Registry, keine Promotion-Pipeline und kein Modell-Monitoring."

**Geschlossener Umfang mit Verweis.**
"Diese Leistungsbeschreibung umfasst ausschließlich Beratungsleistungen. Installation, Konfiguration und Deployment sind nicht Teil des Umfangs. Umsetzung und Rollout können gesondert beauftragt werden."

**Begründung vor den Tätigkeiten.**
"Bevor über Architektur und Technologie entschieden wird, strukturiert MULTIPLAI die Ausgangslage und erstellt eine priorisierte Anforderungsliste. So richtet sich die Bewertung nach dem Bedarf des Kunden und nicht nach Herstellerargumenten."
Then three verb-first bullets: erfassen, strukturieren, priorisieren.

**Ehrliche Größenangabe.**
"Das Modul ist bewusst schlank und schnell angelegt, weil der Zeitplan des Kunden es verlangt."

**Status getrennt von Empfehlung.**
"Keiner der Punkte in dieser Tabelle ist eine Empfehlung dieses Berichts."

**Evidenz nach Art gekennzeichnet.**
"Aussagen aus Interviews und beobachtete Daten halten wir in diesem Bericht bewusst getrennt."
"Wir führen dies als zu prüfende Beobachtung und nicht als gesicherten Befund."

**Fair gegenüber dem Team.**
"Das ist keine Kritik an der Entwicklungsarbeit. Das System funktioniert, und mehrere Designentscheidungen waren zum damaligen Zeitpunkt gut begründet."

**Methode und Grenzen benannt.**
"Der Vergleich der Abrechnungsmodelle ist belastbar. Für die absolute Einsparung fehlen die Abrechnungsdaten."
