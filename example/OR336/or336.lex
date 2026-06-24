law "OR"

article "336" 

type partei is string 
type kuendigung is string
type persoenliche_eigenschaft is string
type taetigkeit is string
type betrieb is string
type recht is string
type arbeitsvertrag is string
type anspruch is string
type pflicht is string

observable event Kuendigen
    """Die Kuendigung {k} wird von Partei {p1} gegenüber Partei {p2} eingeleitet."""
    k : kuendigung
    p1 : partei
    p2 : partei

internal event Missbrauechlich
    """Die Kuendigung {k} ist missbraeuchlich."""
    k : kuendigung

observable event Diskriminierend
    """Der Grund der Kuendigung {k} stützt sich auf die persoenliche Eigenschaft {e} (positive Bsp: Religion, Äusserlichkeit, Alter, Geschlecht / negative Bsp: mangelnde Arbeitsleistung, Fehlverhalten, Zuspätkommen, betriebliche Umstrukturierung)."""
    k : kuendigung
    e : persoenliche_eigenschaft

observable event Zusammenhang
    """Es besteht ein Zusammenhang zwischen der persoenlichen Eigenschaft {e} (positive Bsp: Religion, Äusserlichkeit, Alter, Geschlecht / negative Bsp: mangelnde Arbeitsleistung, Fehlverhalten, Zuspätkommen, betriebliche Umstrukturierung) 
    und der beruflichen Taetigkeit {t}."""
    e : persoenliche_eigenschaft
    t : taetigkeit

observable event StoertZusammenarbeit
    """Die persoenliche Eigenschaft {e} (positive Bsp: Religion, Äusserlichkeit, Alter, Geschlecht / negative Bsp: mangelnde Arbeitsleistung, Fehlverhalten, Zuspätkommen, betriebliche Umstrukturierung) stoert die betriebliche Zusammenarbeit im {b}."""
    e : persoenliche_eigenschaft
    b : betrieb

causable event Entschaedigung
    """Partei {p1} muss Partei {p2} eine Entschaedigung zahlen."""
    p1 : partei
    p2 : partei

observable event Ausueben
    """Partei {p} uebt das Recht {r} (positive Bsp: Kündigungsrecht, Widerrufsrecht, Vorkaufsrecht, Zurückbehaltungsrecht / negative Bsp: Zahlungspflicht, Lieferung der Ware, Arbeitsleistung, Vertragsverletzung) aus."""
    p : partei
    r : recht

observable predicate Verfassungsmaessig
    """Das Recht {r} (positive Bsp: Kündigungsrecht, Widerrufsrecht, Vorkaufsrecht, Zurückbehaltungsrecht / negative Bsp: Zahlungspflicht, Lieferung der Ware, Arbeitsleistung, Vertragsverletzung) ist verfassungsmaessig."""
    r : recht

observable event PflichtVerletzung
    """Die Ausuebung des Rechts {r} (positive Bsp: Kündigungsrecht, Widerrufsrecht, Vorkaufsrecht, Zurückbehaltungsrecht / negative Bsp: Zahlungspflicht, Lieferung der Ware, Arbeitsleistung, Vertragsverletzung) verletzt die Pflicht im Arbeitsverhältnis {a}."""
    r : recht
    a : arbeitsvertrag

observable event BeabsichtigtAnspruechVereitelung
    """Durch die Kuendigung {k} wird bezweckt, die Entstehung von Anspruechen (positive Bsp: Abfindung, Bonusanspruch, betriebliche Altersvorsorge, Dienstjubiläums-Prämie / negative Bsp: Kündigungsfrist, regulärer Monatslohn, Resturlaub, Aufstiegshoffnung) der Partei {p} 
       aus dem Arbeitsverhältnis {a} zu vereiteln."""
    k : kuendigung
    p : partei
    a : arbeitsvertrag

observable event GeltendMachen
    """Partei {p} macht den Anspruch {an} (positive Bsp: Abfindung, Bonusanspruch, betriebliche Altersvorsorge, Dienstjubiläums-Prämie / negative Bsp: Kündigungsfrist, regulärer Monatslohn, Resturlaub, Aufstiegshoffnung) nach Treu und Glaube aus dem Arbeitsverhältnis {a} geltend."""
    p : partei
    an : anspruch
    a : arbeitsvertrag

observable predicate AnspruchZusammenhang
    """Das Geltendmachen des Anspruches {an} (positive Bsp: Abfindung, Bonusanspruch, betriebliche Altersvorsorge, Dienstjubiläums-Prämie / negative Bsp: Kündigungsfrist, regulärer Monatslohn, Resturlaub, Aufstiegshoffnung) ist der Grund für die Kuendigung {k}."""
    an : anspruch
    k : kuendigung

observable event Erfuellt
    """Partei {p} leistet schweizerischen obligatorischen Militaer- oder Schutzdienst 
       oder schweizerischen Zivildienst oder erfuellt eine nicht freiwillig uebernommene 
       gesetzliche Pflicht {pf}."""
    p : partei
    pf : pflicht

observable predicate PflichtZusammenhang
    """Das Erfuellen von schweizerischen obligatorischen Militaer- oder Schutzdienst 
       oder schweizerischen Zivildienst oder einer nicht freiwillig uebernommenen
       gesetzliche Pflicht {pf} ist der Grund fuer die Kuendigung {k}."""
    pf : pflicht
    k : kuendigung

paragraph "1"

point "a"

rule "diskriminierungskuendigung"
    whenever
        Kuendigen(k, p1, p2) 
        Diskriminerend(k, e)
    constitute
        Missbrauechlich(k)

rule "diskriminierungkuendigung_ausnahme_1"
    whenever
        Zusammenhang(e, t)
    except
        rule "diskriminierungskuendigung"

rule "diskriminierungkuendigung_ausnahme_2"
    whenever
        StoertZusammenarbeit(e, b)
    except
        rule "diskriminierungskuendigung"

point "b"

rule "verfassungsmaessig"
    whenever
        Kuendigen(k, p1, p2)
        Ausueben(p2, r)
        Verfassungsmaessig(r)
    constitute
        Missbrauechlich(k)

rule "verfassungsmaessig_ausnahme_1"
    whenever
        PflichtVerletzung(r, a)
    except
        rule "verfassungsmaessig"

rule "verfassungsmaessig_ausnahme_2"
    whenever
        StoertZusammenarbeit(e, b)
    except
        rule "verfassungsmaessig"

point "c" 

rule "vereitelung"
    whenever
        BeabsichtigtAnspruechVereitelung(k, p2, a)
    constitute
        Missbrauechlich(k)

point "d"

rule "ansprueche"
    whenever
        ONCE GeltendMachen(p2, an, a)
        AnspruchZusammenhang(an, k)
    constitute
        Missbrauechlich(k)

point "e"

rule "pflichterfuellung"
    whenever
        ONCE Erfuellt(p2, pf)
        PflichtZusammenhang(pf, k)
    constitute
        Missbrauechlich(k)

type anlass is string

observable predicate MitgliedArbeitnehmerverband
    """Der Arbeitnehmer {p} gehoert einem Arbeitnehmerverband an."""
    p : partei

observable event TaetigkeitAusueben
    """Der Arbeitnehmer {p} uebt die gewerkschaftliche Taetigkeit {t} aus."""
    p : partei
    t : taetigkeit

observable predicate GewaehlterVertreter
    """Der Arbeitnehmer {p} ist gewaehlter Arbeitnehmervertreter in einer betrieblichen oder in 
    einer dem Unternehmen angeschlossenen Einrichtung."""
    p : partei

observable predicate BeweisAnlass
    """Der Arbeitgeber hat einen begruendeten Anlass {al} zur Kuendigung {k} welchen er beweisen kann."""
    al : anlass 
    k : kuendigung

observable event Massenentlassung
    """Der Arbeitgeber {p} entläss in einem Betrieb {b} innerhalb von 30 Tagen eine grosse Anzahl von Mitarbeitenden."""
    p : partei
    b : betrieb

observable event KonsultiertVertreter
    """Der Arbeitnehmervertreter {p} wurde bezüglich der Massenentlassung konsultiert."""
    p : partei

observable event KonsultiertArbeitnehmer
    """Der Arbeitnehmer {p} wurde bezüglich der Massenentlassung konsultiert."""   


paragraph "2"

point "a"

rule "gewerkschaft"
    whenever
        Kuendigen(k, p1, p2)
        ONCE (
        MitgliedArbeitnehmerverband(p2) OR 
        NOT MitgliedArbeitnehmerverband(p2) OR 
        TaetigkeitAusueben(p2, t)
        )
    constitute
        Missbrauechlich(k)

point "b"

rule "vertreter"
    whenever
        Kuendigen(k, p1, p2)
        GewaehlterVertreter(p2)
        NOT BeweisAnlass(al, k)
    constitute
        Missbrauechlich(k)

point "c"

rule "konsultiert"
    whenever
        Kuendigen(k, p1, p2)
        GewaehlterVertreter(p3)
        NOT (KonsultiertVertreter(p3) OR KonsultiertArbeitnehmer(p2))
    constitute
        Missbrauechlich(k)

rule "massenentlassung"

paragraph "3"

article "336a"

paragraph "1"

rule
    whenever
        Kuendigen(k, p1, p2)
        Missbrauechlich(k)
    oblige
        Entschaedigung(p1, p2)
    transparently enforceable causing effects

paragraph "2"

paragraph "3"

article "336b"

paragraph "1"

paragraph "2"