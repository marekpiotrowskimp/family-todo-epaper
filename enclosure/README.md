# Obudowa: e-paper 4,2″ + XIAO ESP32-S3

Ramka na biurko lub półkę, wstawiana w osobną podstawkę, która odchyla ją o 15° do tyłu. Kabel USB wychodzi prawą ścianką przy samym dnie (patrząc od przodu), prostopadle w bok, obok podstawki. Model jest parametryczny (`epaper_frame.scad`, OpenSCAD) i drukuje się bez podpór.

## Pliki

| Plik | Opis |
|---|---|
| `epaper_frame.scad` | Źródło parametryczne (OpenSCAD) |
| `fit_test.stl` / `.gcode` | **Wydruk próbny:** sama ramka z oknem i kieszenią panelu. Drukuj najpierw. |
| `case_body.stl` / `.gcode` | Korpus z ramką, kieszenią panelu i wnęką na pokrywę |
| `case_cover.stl` / `.gcode` | Płaska tylna pokrywa (klejona we wnęce korpusu) |
| `stand.stl` / `.gcode` | Podstawka: siedzisko pochylone 15°, warga z przodu, oparcie z tyłu |
| `ender3_config.ini` | Profil PrusaSlicer (Ender-3 Pro + Devil Design PLA), przejęty z obudowy `air_condition_receiver`, poprawiony (bez Z-hopu) |
| `tests/test_enclosure.py` | Testy wymiarów i geometrii (`python3 -m unittest discover -s enclosure/tests`) |

## Wymiary

| | |
|---|---|
| Luz | **panel: 2 mm** w każdej osi (1 mm na stronę, `panel_play`); **urządzenie w podstawce i kabel w wycięciu: 1,4 mm** (`play`); klejona pokrywa: 0,6 mm |
| Korpus (zewnętrznie) | **97,0 × 84,0 × 22,2 mm**, ścianki 2,5 mm, narożniki r = 2 |
| Pokrywa | 93,9 × 80,9 × 2,5 mm, płaska, leży na półce 0,95 mm |
| Podstawka | 97,0 × 58,7 mm podstawy, ~33 mm wysokości |
| Okno | 87,4 × 66,2 mm, czyli obszar aktywny 84,8 × 63,6 + 1,3 mm zapasu z każdej strony (luz panelu + 0,3); widoczna ramka L / P / dół / góra: 4,2 / 5,4 / 11,2 / 6,6 mm |
| Kieszeń panelu | 92,0 × 79,0 × 1,2 mm (panel 90 × 77 × 1,2 zmierzony suwmiarką + luz 2) za ramką 2,0 mm; ramka zachodzi na panel L / P / dół / góra: 0,7 / 1,9 / 7,7 / 3,1 mm |
| Wnętrze | 16,5 mm od tyłu panelu do pokrywy: front panelu → osłona włożonej wtyczki USB-C to zmierzone 17,7 mm, pokrywa dociska wtyczkę na styk, więc elektronika nie lata |
| Wycięcie na kabel | prawa ścianka, przy samym dnie (od wewnętrznej powierzchni dolnej ścianki), 5,4 mm wysokości, 7,9 mm od tylnej krawędzi; przed pokrywą otwarte 5,4 × 5,4 mm na kabel 4 × 4 mm |
| Postawa | w podstawce, odchylenie 15°: przednia dolna krawędź 10 mm nad blatem, warga 6 mm ponad siedziskiem (zasłania tylko dolny pasek ramki), oparcie na 30 mm tylnej ściany, luz 0,7 mm z przodu i z tyłu |
| Stabilność | środek masy urządzenia ~25 mm za przodem i ~33 mm przed tyłem podstawy |

Okno jest przesunięte, bo obszar aktywny panelu nie leży na środku. Patrząc od przodu, odstępy krawędzi panelu od obszaru aktywnego wynoszą (zmierzone suwmiarką):
- **lewa:** 2,0 mm, więc **prawa** 3,2 mm;
- **dół:** 9,0 mm (tam jest taśma FPC), więc **góra** 4,4 mm.

Zapas okna (1,3 mm) jest większy od luzu panelu (1 mm na stronę), więc nawet dosunięty do dowolnej ścianki panel pokazuje cały ekran. Najlepiej wycentrować go przy klejeniu. Część czarnej ramki rysowanej przez firmware widać w zapasie jako równą obwódkę.

## Parametry druku (Ender-3 Pro, Devil Design PLA czarny)

| Parametr | Wartość |
|---|---|
| Dysza / warstwa | 0,4 mm / 0,2 mm (pierwsza 0,2) |
| Ścianki / góra / dół | 3 perymetry, 4 + 4 warstwy pełne |
| Wypełnienie | 20 % gyroid |
| Temperatura dyszy | 215 °C pierwsza warstwa, 210 °C dalej |
| Stół | 60 °C cały czas |
| Prędkości | perymetry 40, zewnętrzny 25, mosty 25, wypełnienie 50, pierwsza warstwa 20, przejazdy 150 mm/s |
| Retrakcja | 5 mm, 45 mm/s, **bez podnoszenia Z (Z-hop)**, retrakcja przy zmianie warstwy, wipe |
| Przyspieszenia | 500 mm/s², jerk 8 (M201–M205 w G-code) |
| Stopa słonia | kompensacja 0,1 mm (front na stole) |
| Chłodzenie | 100 %, wyłączone przez 3 pierwsze warstwy |
| Przyczepność | brim 5 mm, skirt 3 × 3 mm |
| Supporty | **brak** |

Zmiany względem pierwotnego profilu (wg oficjalnego profilu Creality Ender-3 w PrusaSlicer) po wydrukach z nierównymi ściankami: wyłączony Z-hop (pojedyncza śruba Z ma luz, podnoszenie i opuszczanie przy każdej retrakcji mogło dawać warstwy na różnej wysokości), wolniejsze ścianki zewnętrzne i mosty, wipe, stała temperatura stołu, przyspieszenia w G-code. Jeśli ścianki dalej są nierówne, przyczyna jest mechaniczna: oś Z, ekscentryki rolek, ekstruder, wilgotny filament.

## Czas druku i filament (PrusaSlicer 2.9.4)

| Część | Orientacja na stole | Czas | Filament |
|---|---|---|---|
| `fit_test` | front na stole | ~50 min | 2,9 m (6,9 cm³) |
| `case_body` | front na stole, ścianki rosną w górę | ~2 h 23 min | 8,8 m (21,3 cm³) |
| `case_cover` | płyta na stole | ~1 h 33 min | 6,1 m (14,7 cm³) |
| `stand` | płyta podstawy na stole, oparcie rośnie w górę (odchylone 15°) | ~3 h 00 min | 10,8 m (25,9 cm³) |
| **Razem (korpus + pokrywa + podstawka)** | | **~6 h 56 min** | **25,7 m (~62 cm³)** |

## Montaż

1. **Wydruk próbny.** Włóż panel w `fit_test` ekranem do ramki. Panel ma wpaść swobodnie, z wyczuwalnym luzem, a cały obszar aktywny ma być widoczny, bez białego paska panelu w oknie. Jeśli coś się nie zgadza, popraw parametry (sekcja niżej) i wygeneruj pliki ponownie.
2. **Panel.** ⚠️ **Nigdy nie wciskaj panelu.** Szkło pęka przy nacisku, a ścianki wydruku bywają nierówne. Panel musi wejść sam. Jeśli gdzieś zahacza, zeszlifuj wybrzuszenie ścianki albo zwiększ `panel_play`. Włóż panel ekranem do ramki, taśmą FPC przy dolnej krawędzi, wycentruj go w kieszeni (ok. 1 mm odstępu z każdej strony) i przyklej kroplą kleju na gorąco w 4 rogach. Ramka zachodzi na panel z lewej tylko na 0,7 mm, więc bez kleju panel nie będzie trzymany.
3. **Płytka.** Połóż płytkę sterownika z XIAO na tyle panelu, z taśmą zawiniętą przy dolnej krawędzi. Włóż na stałe kabel USB-C. Prawy dolny róg wnętrza (14,3–19,7 mm za frontem obudowy) zostaw wolny na kabel. Płytkę można przytrzymać taśmą dwustronną albo kroplą kleju; pokrywa i tak dociśnie wtyczkę.
4. **Antena.** Przyklej antenę U.FL do wewnętrznej strony pokrywy, z dala od metalowych elementów.
5. **Kabel.** Poprowadź kabel po dnie do prawego dolnego rogu i wyprowadź go wycięciem w prawej ściance, prostopadle w bok. Na zewnątrz opada na blat obok podstawki, więc nie ciągnie urządzenia ani do przodu, ani do tyłu.
6. **Pokrywa.** Włóż płaską pokrywę we wnękę i przyklej ją na gorąco w kilku punktach na obwodzie. Klej da się później rozgrzać i otworzyć obudowę.
7. **Podstawka.** Wstaw obudowę w podstawkę ekranem do przodu: spód na siedzisko, front za wargę, pokrywa opiera się o oparcie. Obudowę można w każdej chwili wyjąć do góry.

## Zmiana parametrów

Najczęstsze poprawki po wydruku próbnym (`epaper_frame.scad`):

| Problem | Parametr |
|---|---|
| Podstawka lub wycięcie za luźne / za ciasne | `play` (1,4) |
| Panel nie wchodzi swobodnie albo lata w kieszeni | `panel_play` (2,0; okno rośnie razem z nim), `panel_w` (90), `panel_h` (77) |
| W oknie widać biały pasek u góry lub u dołu | `active_top` (4,4) |
| W oknie widać biały pasek z boku | `active_left` (2,0) |
| Pokrywa nie zamyka się albo elektronika lata | `usb_plug_from_front` (17,7) |
| Pokrywa nie wchodzi we wnękę | `cover_tol` (0,3) |
| Kabel nie mieści się w wycięciu | `cable_w` (4), `play` |
| Inne odchylenie albo wysokość | `tilt_deg` (15), `seat_h` (10), `backrest_h` (30) |
| Podstawka za lekka / przewraca się | `base_back_z` (55) |

Ponowne wygenerowanie plików do druku (z katalogu `enclosure/`):

```bash
openscad -D 'part="body"'  -o case_body.stl  epaper_frame.scad
openscad -D 'part="cover"' -o case_cover.stl epaper_frame.scad
openscad -D 'part="fit"'   -o fit_test.stl   epaper_frame.scad
openscad -D 'part="stand"' -o stand.stl      epaper_frame.scad
for n in case_body case_cover fit_test stand; do
  /Applications/PrusaSlicer.app/Contents/MacOS/PrusaSlicer --export-gcode \
    --load ender3_config.ini --center 110,110 -o $n.gcode $n.stl
done
python3 -m unittest discover -s tests
```
