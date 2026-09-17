import akomaNtoso BGG

law "BGG"
chapter "3"

type recht is string
type gericht is string
type gebiet is string
type gegenstand is string
type beschwerde is int
  """ eine Beschwerde """
type akt is int
  """ ein Akt """
type person is string
type staat is string

predicate anfechtungsObjekt
  """ Beschwerde {b} fechtet Akt {a} an """
  b: beschwerde
  a: akt

predicate trifft
  """ Entscheid {a} wird von Gericht {g} getroffen """
  g: gericht
  a: akt

suppressable event beurteilt
  """ Gericht {g} beurteilt Beschwerde {b} """
  g: gericht
  b: beschwerde

event stelltAuslieferungsersuchen
  """ Staat {s} stellt ein Auslieferungsersuchen gegen Person {p} """
  s: staat
  p: person

event suchtSchutz
  """ Person {p} sucht Schutz vor Staat {s} """
  p: person
  s: staat

internal predicate zulaessig
  """ Beschwerde {b} ist bei Gericht {g} zulässig """
  g: gericht
  b: beschwerde

predicate oeffentlichesRecht
  """ Akt {a} ist ein Entscheid in Angelegenheiten des öffentlichen Rechts """
  a: akt

predicate kantonalerErlass
  """ Akt {a} ist ein kantonaler Erlass """
  a: akt

predicate betrifft
  """ Akt {a} betrifft {bet} """
  a: akt
  bet: gegenstand

predicate betrifftPerson
  """ Akt {a} betrifft Person {p} """
  a: akt
  p: person

predicate gebiet
  """ Akt {a} ist ein Entscheid auf dem Gebiet {geb} """
  a: akt
  geb: gebiet

predicate beurteilungsAnspruch
  """ {r} räumt einen Anspruch auf gerichtliche Beurteilung von Akt {a} ein """
  r: recht
  a: akt

predicate raeumtAnspruchEin
  """ {r} räumt einen Anspruch auf {g} ein """
  r: recht
  g: gegenstand

predicate bewilligung
  """ {g} ist eine Bewilligung """
  g: gegenstand

section "3"

article "82"

rule "principle"
  whenever
    beurteilt(g, b)
  oblige
    zulaessig(g, b)
  transparently enforceable suppressing condition[0]

paragraph "1"
point "a"

rule
  whenever
    anfechtungsObjekt(b, a)
    oeffentlichesRecht(a)
  constitute
    zulaessig("Bundesgericht", b)

point "b"

rule
  whenever
    anfechtungsObjekt(b, a)
    kantonalerErlass(a)
  constitute
    zulaessig("Bundesgericht", b)

point "c"

rule
  whenever
    anfechtungsObjekt(b, a)
    betrifft(a, "politische Stimmberechtigung") OR betrifft(a, "Volkswahlen") OR betrifft(a, "Volksabstimmungen")
  constitute
    zulaessig("Bundesgericht", b)

article "83"
paragraph "1"
point "a"

rule
  whenever
    gebiet(a, "auswärtige Angelegenheiten")
    NOT beurteilungsAnspruch("Völkerrecht", a)
  except
    article "82" paragraph "1"
  
point "b"

rule
  whenever
    betrifft(a, "ordentliche Einbürgerung")
  except
    article "82" paragraph "1"

point "c"
subpoint "1"

rule
  whenever
    gebiet(a, "Ausländerrecht")
    betrifft(a, "Einreise")
  except
    article "82" paragraph "1"

subpoint "2"

rule
  whenever
    gebiet(a, "Ausländerrecht")
    betrifft(a, bew)
    bewilligung(bew)
    NOT raeumtAnspruchEin("Bundesrecht", bew)
    NOT raeumtAnspruchEin("Völkerrecht", bew)
  except
    article "82" paragraph "1"

subpoint "3"

rule
  whenever
    gebiet(a, "Ausländerrecht")
    betrifft(a, "vorläufige Aufnahme")
  except
    article "82" paragraph "1"

subpoint "4"

rule
  whenever
    gebiet(a, "Ausländerrecht")
    betrifft(a, "Ausweisung (nach Art. 121 Abs. 2 BV)") OR betrifft(a, "Wegweisung")
  except
    article "82" paragraph "1"

subpoint "5"

rule
  whenever
    gebiet(a, "Ausländerrecht")
    betrifft(a, "Abweichungen von den Zulassungsvoraussetzungen")
  except
    article "82" paragraph "1"

subpoint "6"

rule
  whenever
    gebiet(a, "Ausländerrecht")
    betrifft(a, "Verlängerung der Grenzgängerbewilligung") OR betrifft(a, "Kantonswechsel") OR betrifft(a, "Stellenwechsel von Personen mit Grenzgängerbewilligung") OR betrifft(a, "Erteilung von Reisepapieren an schriftenlose AusländerInnen")
  except
    article "82" paragraph "1"

point "d"
  
subpoint "1"

rule
  whenever
    gebiet(a, "Asyl")
    ONCE trifft("Bundesverwaltungsgericht", a)
    NOT (EXISTS p. EXISTS s. betrifftPerson(a, p) AND (suchtSchutz(p, s) AND ONCE (stelltAuslieferungsersuchen(s, p))))
  except
    article "82" paragraph "1"
  
subpoint "2"

rule
  whenever
    gebiet(a, "Asyl")
    ONCE trifft("kantonale Vorinstanz", a)
    betrifft(a, bew)
    bewilligung(bew)
    NOT (raeumtAnspruchEin("Bundesrecht", bew))
    NOT (raeumtAnspruchEin("Völkerrecht", bew))
  except
    article "82" paragraph "1"

point "e"

rule
  whenever
    betrifft(a, "Verweigerung der Ermächtigung zur Strafverfolgung von Behördenmitgliedern oder von Bundespersonal")
  except
    article "82" paragraph "1"



