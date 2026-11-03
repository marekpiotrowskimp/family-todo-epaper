// =============================================================================
// RODZINNE ZADANIA - OBUDOWA E-PAPER 4,2" + XIAO ESP32-S3
// =============================================================================
// Druk: Creality Ender-3 Pro, Devil Design PLA czarny, profil ender3_config.ini.
// Wszystkie czesci drukuja sie BEZ supportow (orientacje ponizej).
// Urzadzenie stoi odchylone o 15 stopni w osobnej podstawce (stand); pokrywa jest plaska.
//
// Uklad wspolrzednych urzadzenia (moduly body(), cover(), fit_test()):
//   X w prawo i Y w gore patrzac od przodu na ekran, Z do tylu (front = 0).
//
// Eksport do druku (orientacja na stole):
//   openscad -D 'part="body"'  -o case_body.stl  epaper_frame.scad   // front na stole
//   openscad -D 'part="cover"' -o case_cover.stl epaper_frame.scad   // plyta na stole
//   openscad -D 'part="fit"'   -o fit_test.stl   epaper_frame.scad   // sama ramka do proby
//   openscad -D 'part="stand"' -o stand.stl      epaper_frame.scad   // podstawka, plyta na stole
//
// Uklad swiata podstawki (moduly stand(), device_on_stand()): X w prawo, Y w gore (blat Y = 0),
// Z do tylu. Urzadzenie = translate([0, seat_h, 0]) rotate([tilt_deg, 0, 0]) w ukladzie urzadzenia.
// Parametry wypisywane przez echo(PARAM_<nazwa> = ...) czytaja testy (tests/).
// =============================================================================

part = "both";

// Luzy dopasowan (suma obu stron). Klejona pokrywa ma wlasny `cover_tol`.
play = 1.4;            // podstawka i kabel
panel_play = 2.0;      // panel: 1 mm na strone; przy 0,7 mm nieregularne scianki wydruku polamaly panel

// === PANEL DEPG0420BNS19AF (zmierzony suwmiarka; obszar aktywny z karty katalogowej) ===
panel_w = 90.0;
panel_h = 77.0;
panel_t = 1.2;
active_w = 84.8;
active_h = 63.6;
// Polozenie obszaru aktywnego (zmierzone): lewa 2,0 mm, dol 9,0 mm (tasma FPC),
// wiec u gory 77.0 - 63.6 - 9.0 = 4.4 mm, a z prawej 90.0 - 84.8 - 2.0 = 3.2 mm.
active_left = 2.0;
active_top = 4.4;
active_bottom = panel_h - active_h - active_top;
window_margin = panel_play / 2 + 0.3;   // panel dosuniety do scianki nadal pokazuje caly ekran (+0,3 mm)

// === STOS NA TYLE PANELU (mm nad tylem panelu) ===
stack_top = 13.5;                      // wierzch XIAO na plytce sterownika (szacunek)
usb_plug_from_front = 17.7;            // zmierzone: front panelu -> oslona wlozonej wtyczki USB-C
usb_plug_top = usb_plug_from_front - panel_t;

// === KORPUS ===
tol = panel_play / 2;  // luz panelu w kieszeni, na strone
wall = 2.5;
front_t = 2.0;         // ramka przed panelem
inner_clear = usb_plug_top;   // od tylu panelu do pokrywy: pokrywa dociska wtyczke na styk
cover_t = 2.5;
ledge = 1.25;          // ciensza tylna krawedz scianki = polka pod pokrywe
cover_tol = 0.3;       // pokrywa klejona: mniejszy luz, zeby lezala na polce
r = 2;                 // zaokraglenie naroznikow

width = panel_w + 2 * tol + 2 * wall;
height = panel_h + 2 * tol + 2 * wall;
depth = front_t + panel_t + inner_clear + cover_t;

panel_x0 = wall + tol;
panel_y0 = wall + tol;
window_w = active_w + 2 * window_margin;
window_h = active_h + 2 * window_margin;
window_x0 = panel_x0 + active_left - window_margin;
window_y0 = panel_y0 + active_bottom - window_margin;

// === WYCIECIE NA KABEL USB (prawa scianka patrzac od przodu) ===
// Wtyczka wlozona na stale; przez scianke przechodzi tylko kabel 4 x 4 mm, przy samym dnie,
// prostopadle w prawo, obok podstawki.
cable_w = 4.0;
notch_w = cable_w + play;                  // wzdluz Y
notch_d = cover_t + cable_w + play;        // wzdluz Z, od tylnej krawedzi; przed pokrywa otwarte cable_w + play
notch_center_y = wall + notch_w / 2;       // dol wyciecia na wewnetrznej powierzchni dolnej scianki

// === POKRYWA (plaska, klejona we wnece) ===
cover_w = width - 2 * ledge - 2 * cover_tol;
cover_h = height - 2 * ledge - 2 * cover_tol;

// === PODSTAWKA (kolyska odchylajaca urzadzenie o 15 stopni do tylu) ===
tilt_deg = 15;
seat_h = 10.0;         // wysokosc przedniej dolnej krawedzi urzadzenia nad blatem
seat_gap = 0.05;       // siedzisko tuz pod urzadzeniem (styk scian nie jest przenikaniem)
lip_h = 6.0;           // warga ponad siedziskiem; zaslania tylko dolny pasek ramki (11,2 mm)
lip_t = 3.0;
stand_tol = play / 2;  // luz przed frontem i za pokrywa
backrest_h = 30.0;     // dlugosc oparcia wzdluz tylnej sciany urzadzenia
backrest_t = 4.0;
base_t = 3.0;
base_front_z = -(stand_tol + lip_t);
base_back_z = 55.0;    // ogon z tylu: srodek masy ~21,5 mm, zapas >= 10 mm z obu stron

fit_test_h = front_t + panel_t + 1.0;

$fn = 32;

module rounded_box(w, h, d) {
    hull() for (x = [r, w - r], y = [r, h - r]) translate([x, y, 0]) cylinder(r = r, h = d);
}

// Korpus w ukladzie urzadzenia.
module body() {
    difference() {
        rounded_box(width, height, depth);
        // okno na obszar aktywny
        translate([window_x0, window_y0, -1]) cube([window_w, window_h, front_t + 2]);
        // kieszen panelu i wnetrze na elektronike (ta sama szerokosc)
        translate([wall, wall, front_t]) cube([width - 2 * wall, height - 2 * wall, depth - cover_t - front_t + 0.01]);
        // wneka na pokrywe: tylna krawedz scianki zweza sie do `ledge`
        translate([ledge, ledge, depth - cover_t]) cube([width - 2 * ledge, height - 2 * ledge, cover_t + 1]);
        // wyciecie na kabel w prawej sciance, otwarte od tylu
        translate([width - wall - 1, notch_center_y - notch_w / 2, depth - notch_d])
            cube([wall + 2, notch_w, notch_d + 1]);
    }
}

// Plaska pokrywa w ukladzie urzadzenia (plyta lezy we wnece korpusu).
module cover() {
    translate([ledge + cover_tol, ledge + cover_tol, depth - cover_t]) cube([cover_w, cover_h, cover_t]);
}

// Szybki wydruk probny: ramka z oknem i kieszen panelu.
module fit_test() {
    intersection() {
        body();
        translate([-1, -1, 0]) cube([width + 2, height + 2, fit_test_h]);
    }
}

// Urzadzenie (korpus + pokrywa) ustawione w podstawce, uklad swiata.
module device_on_stand() {
    translate([0, seat_h, 0]) rotate([tilt_deg, 0, 0]) { body(); cover(); }
}

// Podstawka w ukladzie swiata: profil boczny (Y, Z) wyciagniety na cala szerokosc obudowy.
// Wektory urzadzenia w swiecie (Y, Z): os Y urzadzenia = (cos, sin), os Z urzadzenia = (-sin, cos).
module stand() {
    c = cos(tilt_deg);
    s = sin(tilt_deg);
    function seat_y(z) = seat_h - seat_gap - z * tan(tilt_deg);   // spod urzadzenia, obnizony o seat_gap
    // wewnetrzna dolna krawedz oparcia: tyl urzadzenia + luz, obnizona o seat_gap wzdluz osi Y urzadzenia
    back_d = depth + stand_tol;
    inner_low = [seat_h - back_d * s - seat_gap * c, back_d * c - seat_gap * s];
    inner_top = inner_low + backrest_h * [c, s];
    outer_top = inner_top + backrest_t * [-s, c];
    drop = (outer_top[0] - base_t) / c;                            // zejscie zewnetrzna sciana oparcia do plyty
    outer_low = outer_top - drop * [c, s];
    profile = [                                                    // punkty [Y, Z]
        [0, base_front_z],
        [seat_h + lip_h, base_front_z],
        [seat_h + lip_h, -stand_tol],
        [seat_y(-stand_tol), -stand_tol],
        inner_low,
        inner_top,
        outer_top,
        outer_low,
        [base_t, base_back_z],
        [0, base_back_z],
    ];
    rotate([90, 0, 90]) linear_extrude(width) polygon(profile);   // wielokat (Y, Z) wzdluz X
}

if (part == "body") body();                                         // front na stole
else if (part == "cover") translate([-(ledge + cover_tol), -(ledge + cover_tol), -(depth - cover_t)]) cover();  // plyta na stole
else if (part == "fit") fit_test();
else if (part == "stand") rotate([90, 0, 0]) stand();               // plyta na stole
else { color("DimGray") stand(); color("Gray") device_on_stand(); }

// === PARAMETRY DLA TESTOW I README ===
echo(PARAM_panel_w = panel_w);
echo(PARAM_panel_h = panel_h);
echo(PARAM_panel_t = panel_t);
echo(PARAM_active_w = active_w);
echo(PARAM_active_h = active_h);
echo(PARAM_active_left = active_left);
echo(PARAM_active_top = active_top);
echo(PARAM_window_margin = window_margin);
echo(PARAM_window_w = window_w);
echo(PARAM_window_h = window_h);
echo(PARAM_tol = tol);
echo(PARAM_panel_play = panel_play);
echo(PARAM_wall = wall);
echo(PARAM_front_t = front_t);
echo(PARAM_inner_clear = inner_clear);
echo(PARAM_cover_t = cover_t);
echo(PARAM_ledge = ledge);
echo(PARAM_width = width);
echo(PARAM_height = height);
echo(PARAM_depth = depth);
echo(PARAM_cover_w = cover_w);
echo(PARAM_cover_h = cover_h);
echo(PARAM_tilt_deg = tilt_deg);
echo(PARAM_seat_h = seat_h);
echo(PARAM_lip_h = lip_h);
echo(PARAM_lip_t = lip_t);
echo(PARAM_stand_tol = stand_tol);
echo(PARAM_backrest_h = backrest_h);
echo(PARAM_backrest_t = backrest_t);
echo(PARAM_base_t = base_t);
echo(PARAM_base_front_z = base_front_z);
echo(PARAM_base_back_z = base_back_z);
echo(PARAM_cover_tol = cover_tol);
echo(PARAM_notch_w = notch_w);
echo(PARAM_notch_d = notch_d);
echo(PARAM_notch_center_y = notch_center_y);
echo(PARAM_stack_top = stack_top);
echo(PARAM_usb_plug_top = usb_plug_top);
