Status-Bericht: EGYM App "Low-Mem" ProjektDas Ziel, die App auf leistungsschwache Geräte wie die Instinct 2 und Forerunner 55 zu portieren, ist zu 90% erreicht. Die Architektur wurde erfolgreich von einem monolithischen Design auf ein hybrides System umgestellt.🛠 Geänderte Kern-KomponentenDateiStatusFunktion / Änderungmonkey.jungleStabilSteuert die Gabelung: :low_mem (Instinct/FR55) vs. :high_res. Isoliert den resources-instinct Pfad.EGYMViewLowMem.mcOptimiertKomplett manuelles Rendering ohne XML. Nutzt State-basiertes Stacking und das Instinct-Sub-Window (Bezel) für Reps.EGYMInstinctText.mcZentralisiertAlle UI-Texte für Low-Mem sind hier hartkodiert auf Englisch hinterlegt (spart Heap-Speicher).EGYMSafeStore.mcAbgesichertUmgestellt auf Application.getApp().getProperty() mit defensiven Null-Checks.EGYMApp.mcStabilRegelt den Flow und instanziiert für :low_mem nur noch die schlanke View-Variante.

Status-Quo Zusammenfassung (Der "Checkpunkt")
Wir haben die App durch eine beispiellose Optimierungsschlacht auf die Instinct 2 und FR55 gebracht:

Speicher & Performance: Die Instinct-Version wurde von 273 KB auf ca. 57 KB PRG-Größe reduziert. Der OOM-Endgegner beim Booten und im Workout-Start ist besiegt.

UI/UX (Low-Mem):

Universal Low-Mem View: Ein rein englisches, ressourcenfreies Layout ohne XML-Abhängigkeiten.

Instinct-Special: Nutzung des runden Sub-Windows für die Reps, um Platz im Hauptdisplay zu schaffen.

Dynamik: Umstellung von "Static Grid" auf ein hybrides Modell, das das Instinct-Loch physisch meidet und auf der FR55 zentriert stapelt.

Architektur: Saubere Trennung über Annotationen (:low_mem vs. :high_res) und ein robuster, defensiver EGYMSafeStore.

Offene Baustelle: Der Individual-Modus-Crash. Wir wissen, dass der pushView-Overhead den RAM sprengt. Die Lösung ("Atomic Switch" via switchToView) ist bereits konzipiert.
