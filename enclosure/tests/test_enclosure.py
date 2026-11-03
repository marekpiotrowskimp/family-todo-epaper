"""Kontrakt obudowy e-paper (spec „obudowa-epaper”, podstawka: „podstawka-obudowy”, wymiary: „wymiary-z-pomiarow”, luz panelu: „luz-panelu-2mm”).

Wymaga OpenSCAD (`openscad` w PATH). Uruchom: python3 -m unittest discover -s enclosure/tests

Układ współrzędnych urządzenia (moduły body(), cover(), fit_test() w epaper_frame.scad):
X w prawo i Y w górę patrząc od przodu na ekran, Z do tyłu (przednia płaszczyzna = 0).

Układ świata podstawki (moduły stand(), device_on_stand()): X w prawo, Y w górę (stół: Y = 0),
Z do tyłu. Urządzenie stoi w podstawce odchylone o 15°: punkt urządzenia (x, y, z) trafia do
translate([0, SEAT_H, 0]) rotate([TILT_DEG, 0, 0]), czyli przednia dolna krawędź leży na (Y = SEAT_H, Z = 0).
"""

import math
import os
import re
import subprocess
import tempfile
import unittest

ENCLOSURE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SCAD = os.path.join(ENCLOSURE, "epaper_frame.scad")

# --- Wartości z kontraktu (nie z modelu) ---------------------------------------------------
PANEL_W, PANEL_H, PANEL_T = 90.0, 77.0, 1.2          # DEPG0420BNS19AF, zmierzone suwmiarką
ACTIVE_W, ACTIVE_H = 84.8, 63.6                      # karta katalogowa
ACTIVE_LEFT, ACTIVE_TOP = 2.0, 4.4                   # zmierzone: lewa 2,0; dół 9,0 (taśma FPC) => góra 4,4
ACTIVE_BOTTOM = PANEL_H - ACTIVE_H - ACTIVE_TOP      # 9.0
PLAY = 1.4                                           # luz dopasowań podstawki i kabla (suma obu stron)
PANEL_PLAY = 2.0                                     # luz panelu: 1 mm na stronę (0,7 mm połamało panel przy wciskaniu)
TOL = PANEL_PLAY / 2                                 # 1.0 na stronę: panel w kieszeni
WINDOW_MARGIN = TOL + 0.3                            # 1.3: panel dosunięty do ścianki nadal pokazuje cały ekran
WALL = 2.5
FRONT_T = 2.0
PLUG_FROM_PANEL_FRONT = 17.7                         # zmierzone: front panelu -> obudowa włożonej wtyczki USB-C
INNER_CLEAR = PLUG_FROM_PANEL_FRONT - PANEL_T        # 16.5: pokrywa dociska wtyczkę na styk
COVER_T = 2.5
LEDGE = 1.25                                         # cieńsza krawędź tylna (miejsce na pokrywę)
COVER_TOL = 0.3                                      # pokrywa klejona: luz 0,6 mm, żeby leżała na półce ~0,95 mm
W = PANEL_W + 2 * TOL + 2 * WALL                     # 97.0
H = PANEL_H + 2 * TOL + 2 * WALL                     # 84.0
D = FRONT_T + PANEL_T + INNER_CLEAR + COVER_T        # 22.2
COVER_W = W - 2 * LEDGE - 2 * COVER_TOL              # 93.9
COVER_H = H - 2 * LEDGE - 2 * COVER_TOL              # 80.9
TILT_DEG = 15.0
CABLE = 4.0                                          # kabel USB 4 × 4 mm, wtyczka włożona na stałe
NOTCH_W = CABLE + PLAY                               # 5.4 wzdłuż Y
NOTCH_D = COVER_T + CABLE + PLAY                     # 7.9 wzdłuż Z od tyłu; otwarte przed pokrywą: 5.4
NOTCH_CENTER_Y = WALL + NOTCH_W / 2                  # 5.2: przy samym dnie prawej ścianki
FIT_TEST_H = FRONT_T + PANEL_T + 1.0                 # 4.2

# Podstawka (kołyska): siedzisko pochylone 15°, warga z przodu, oparcie z tyłu.
SEAT_H = 10.0          # wysokość siedziska pod przednią dolną krawędzią urządzenia
LIP_H = 6.0            # warga ponad siedziskiem przy froncie
LIP_T = 3.0
STAND_TOL = PLAY / 2   # 0.7: luz przed frontem i za pokrywą (razem 1,4 mm)
BACKREST_H = 30.0      # długość oparcia wzdłuż tylnej ściany urządzenia, od dołu
BACKREST_T = 4.0
BASE_T = 3.0
BASE_FRONT_Z = -(STAND_TOL + LIP_T)                  # -3.7
BASE_BACK_Z = 55.0

# Panel w kieszeni: lewy dolny róg panelu w układzie urządzenia.
PANEL_X0 = WALL + TOL
PANEL_Y0 = WALL + TOL
ACTIVE_X0 = PANEL_X0 + ACTIVE_LEFT
ACTIVE_Y0 = PANEL_Y0 + ACTIVE_BOTTOM                 # dół obszaru aktywnego (nad paskiem FPC)


def run_openscad(args):
    return subprocess.run(["openscad", *args], capture_output=True, text=True)


def echo_params():
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "params.echo")
        run_openscad(["-o", out, "-D", 'part="body"', SCAD])
        text = open(out, encoding="utf-8").read() if os.path.exists(out) else ""
    return {m.group(1): float(m.group(2)) for m in re.finditer(r"PARAM_(\w+) = (-?[\d.e+-]+)", text)}


def stl_bbox(path):
    xs, ys, zs = [], [], []
    with open(path, encoding="utf-8", errors="ignore") as f:
        for line in f:
            parts = line.split()
            if len(parts) == 4 and parts[0] == "vertex":
                xs.append(float(parts[1]))
                ys.append(float(parts[2]))
                zs.append(float(parts[3]))
    if not xs:
        return None
    return (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))


def export_bbox(part):
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, f"{part}.stl")
        run_openscad(["-o", out, "-D", f'part="{part}"', SCAD])
        return stl_bbox(out) if os.path.exists(out) else None


class ProbeError(AssertionError):
    pass


def intersects(first, second):
    """True, gdy dwie bryły OpenSCAD mają część wspólną; False, gdy przecięcie jest puste.

    Błąd OpenSCAD (składnia, brak modułu) to ProbeError, a nie „pusto”: sprawdzenia
    „tu ma być otwór” nie mogą przechodzić tylko dlatego, że model się nie zbudował.
    """
    with tempfile.TemporaryDirectory() as tmp:
        probe = os.path.join(tmp, "probe.scad")
        out = os.path.join(tmp, "probe.stl")
        with open(probe, "w", encoding="utf-8") as f:
            f.write(f"use <{SCAD}>\nintersection() {{ {first} {second} }}\n")
        result = run_openscad(["-o", out, probe])
        if result.returncode == 0 and os.path.exists(out) and os.path.getsize(out) > 0:
            return True
        if "Current top level object is empty" in result.stderr:
            return False
        raise ProbeError(f"OpenSCAD nie zbudował sondy: {result.stderr[-400:]}")


def box(x, y, z, dx, dy, dz):
    return f"translate([{x}, {y}, {z}]) cube([{dx}, {dy}, {dz}]);"


def on_stand(geometry):
    """Geometria podana w układzie urządzenia, ustawiona tak jak urządzenie w podstawce."""
    return f"translate([0, {SEAT_H}, 0]) rotate([{TILT_DEG}, 0, 0]) {{ {geometry} }}"


def is_solid(module, x, y, z, dx, dy, dz):
    """True, gdy moduł ma materiał w prostopadłościanie [x, x+dx] × [y, y+dy] × [z, z+dz]."""
    return intersects(f"{module}();", box(x, y, z, dx, dy, dz))


class PrintProfileTests(unittest.TestCase):
    """Parametry druku przejęte z ../xiao/air_condition_receiver/enclosure (ender3_config.ini + G-code)."""

    def setUp(self):
        path = os.path.join(ENCLOSURE, "ender3_config.ini")
        self.assertTrue(os.path.exists(path), "brak enclosure/ender3_config.ini")
        self.ini = {}
        for line in open(path, encoding="utf-8"):
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                self.ini[key.strip()] = value.strip()

    def test_profile_matches_reference_ender3_pla_settings(self):
        expected = {
            "nozzle_diameter": "0.4", "layer_height": "0.2", "first_layer_height": "0.2",
            "perimeters": "3", "top_solid_layers": "4", "bottom_solid_layers": "4",
            "fill_density": "20%", "fill_pattern": "gyroid",
            "first_layer_temperature": "215", "temperature": "210",
            "first_layer_bed_temperature": "60", "bed_temperature": "60",
            "support_material": "0", "brim_width": "5",
            "retract_length": "5", "retract_speed": "45",
            # bez Z-hopu: nierówne ścianki (pojedyncza śruba Z z luzem); wartości z oficjalnego profilu Creality
            "retract_lift": "0", "retract_layer_change": "1", "wipe": "1",
            "first_layer_speed": "20", "perimeter_speed": "40", "external_perimeter_speed": "25",
            "bridge_speed": "25", "elefant_foot_compensation": "0.1",
            "machine_limits_usage": "emit_to_gcode", "default_acceleration": "500",
        }
        for key, value in expected.items():
            self.assertEqual(self.ini.get(key), value, key)


class ParameterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p = echo_params()

    def test_model_reports_contract_dimensions(self):
        expected = {
            "panel_w": PANEL_W, "panel_h": PANEL_H, "panel_t": PANEL_T,
            "active_w": ACTIVE_W, "active_h": ACTIVE_H, "active_left": ACTIVE_LEFT, "active_top": ACTIVE_TOP,
            "window_margin": WINDOW_MARGIN, "tol": TOL, "wall": WALL, "front_t": FRONT_T,
            "inner_clear": INNER_CLEAR, "cover_t": COVER_T, "ledge": LEDGE,
            "width": W, "height": H, "depth": D, "cover_w": COVER_W, "cover_h": COVER_H,
            "tilt_deg": TILT_DEG, "seat_h": SEAT_H, "lip_h": LIP_H, "lip_t": LIP_T, "stand_tol": STAND_TOL,
            "backrest_h": BACKREST_H, "backrest_t": BACKREST_T, "base_t": BASE_T,
            "base_front_z": BASE_FRONT_Z, "base_back_z": BASE_BACK_Z,
            "cover_tol": COVER_TOL, "notch_w": NOTCH_W, "notch_d": NOTCH_D, "notch_center_y": NOTCH_CENTER_Y,
            "usb_plug_top": INNER_CLEAR, "panel_play": PANEL_PLAY,
        }
        for key, value in expected.items():
            self.assertIn(key, self.p, f"PARAM_{key} nie jest wypisywany przez echo")
            self.assertAlmostEqual(self.p[key], value, places=2, msg=key)

    def test_window_shows_active_area_and_lips_hold_panel(self):
        p = self.p
        self.assertIn("window_w", p)
        self.assertAlmostEqual(p["window_w"], ACTIVE_W + 2 * WINDOW_MARGIN, places=2)
        self.assertAlmostEqual(p["window_h"], ACTIVE_H + 2 * WINDOW_MARGIN, places=2)
        lips = {
            "lewa": ACTIVE_LEFT - WINDOW_MARGIN,
            "prawa": PANEL_W - ACTIVE_W - ACTIVE_LEFT - WINDOW_MARGIN,
            "górna": ACTIVE_TOP - WINDOW_MARGIN,
            "dolna": ACTIVE_BOTTOM - WINDOW_MARGIN,
        }
        for side, lip in lips.items():
            self.assertGreaterEqual(lip, 0.7 - 1e-6, f"krawędź {side} trzyma panel na mniej niż 0,7 mm")
        # panel klejony nie przejdzie przez okno: w każdej osi jest od niego szerszy o >= 2,5 mm
        self.assertGreaterEqual(p["panel_w"] - p["window_w"], 2.5)
        self.assertGreaterEqual(p["panel_h"] - p["window_h"], 2.5)
        # panel dosunięty do ścianki kieszeni nadal pokazuje cały ekran z zapasem >= 0,3 mm
        self.assertGreaterEqual(p["window_margin"] - p["tol"], 0.3 - 1e-6)

    def test_cover_holds_usb_plug_snugly(self):
        p = self.p
        self.assertIn("usb_plug_top", p)
        # wtyczka USB-C (17,7 mm od frontu panelu) dotyka pokrywy: zero luzu, elektronika nie lata
        self.assertAlmostEqual(p["inner_clear"], p["usb_plug_top"], places=2)
        self.assertAlmostEqual(p["panel_t"] + p["inner_clear"], PLUG_FROM_PANEL_FRONT, places=2)
        self.assertGreaterEqual(p["inner_clear"], p["stack_top"] + 2.0)

    def test_every_fit_has_1_4_mm_play(self):
        p = self.p
        for key in ("width", "height", "panel_w", "panel_h", "stand_tol", "notch_w", "notch_d", "cover_w", "cover_tol"):
            self.assertIn(key, p)
        plays = {
            "urządzenie w podstawce (przód-tył)": 2 * p["stand_tol"],
            "kabel 4 mm w wycięciu (Y)": p["notch_w"] - CABLE,
            "kabel 4 mm w wycięciu (Z, przed pokrywą)": p["notch_d"] - p["cover_t"] - CABLE,
        }
        for name, play in plays.items():
            self.assertAlmostEqual(play, PLAY, places=2, msg=name)
        # panel: 2 mm w każdej osi (1 mm na stronę) na nieregularne ścianki wydruku
        self.assertAlmostEqual(p["width"] - 2 * p["wall"] - p["panel_w"], PANEL_PLAY, places=2, msg="panel (X)")
        self.assertAlmostEqual(p["height"] - 2 * p["wall"] - p["panel_h"], PANEL_PLAY, places=2, msg="panel (Y)")
        # wyjątek uzgodniony z użytkownikiem: pokrywa klejona, luz 0,6 mm, półka pod nią >= 0,9 mm
        self.assertAlmostEqual(p["width"] - 2 * p["ledge"] - p["cover_w"], 0.6, places=2)
        self.assertGreaterEqual(p["wall"] - p["ledge"] - p["cover_tol"], 0.9)

    def test_device_center_of_mass_is_well_inside_stand_footprint(self):
        # Środek bryły urządzenia (y = H/2, z = D/2) po przechyleniu o 15° w układzie świata.
        t = math.radians(TILT_DEG)
        com_z = (H / 2) * math.sin(t) + (D / 2) * math.cos(t)
        self.assertIn("base_front_z", self.p)
        self.assertGreaterEqual(com_z - self.p["base_front_z"], 10.0, "za mały zapas z przodu")
        self.assertGreaterEqual(self.p["base_back_z"] - com_z, 10.0, "za mały zapas z tyłu")

    def test_parts_fit_ender3_bed(self):
        self.assertIn("width", self.p)
        # stół 220 mm minus brim 5 mm i skirt 3 mm z każdej strony
        self.assertLessEqual(max(self.p["width"], self.p["height"]), 220 - 2 * 5 - 2 * 3)


class ExportTests(unittest.TestCase):
    def test_body_print_orientation_bbox(self):
        bbox = export_bbox("body")
        self.assertIsNotNone(bbox)
        for got, want in zip(bbox, (W, H, D)):
            self.assertAlmostEqual(got, want, places=1)

    def test_cover_print_orientation_bbox(self):
        bbox = export_bbox("cover")
        self.assertIsNotNone(bbox)
        for got, want in zip(bbox, (COVER_W, COVER_H, COVER_T)):
            self.assertAlmostEqual(got, want, places=1)

    def test_stand_print_orientation_bbox(self):
        bbox = export_bbox("stand")
        self.assertIsNotNone(bbox)
        self.assertAlmostEqual(bbox[0], W, places=1)
        self.assertAlmostEqual(bbox[1], BASE_BACK_Z - BASE_FRONT_Z, places=1)  # podstawa na stole
        self.assertLess(bbox[2], 40.0)

    def test_fit_test_print_orientation_bbox(self):
        bbox = export_bbox("fit")
        self.assertIsNotNone(bbox)
        for got, want in zip(bbox, (W, H, FIT_TEST_H)):
            self.assertAlmostEqual(got, want, places=1)

    def test_committed_stl_and_gcode_match_model_and_profile(self):
        for name, dims in (("case_body", (W, H, D)), ("case_cover", (COVER_W, COVER_H, COVER_T)),
                           ("fit_test", (W, H, FIT_TEST_H)), ("stand", (W, BASE_BACK_Z - BASE_FRONT_Z, None))):
            stl = os.path.join(ENCLOSURE, f"{name}.stl")
            self.assertTrue(os.path.exists(stl), f"brak {name}.stl")
            for got, want in zip(stl_bbox(stl), dims):
                if want is not None:
                    self.assertAlmostEqual(got, want, places=1, msg=name)
            gcode = os.path.join(ENCLOSURE, f"{name}.gcode")
            self.assertTrue(os.path.exists(gcode), f"brak {name}.gcode")
            text = open(gcode, encoding="utf-8", errors="ignore").read()
            for setting in ("; layer_height = 0.2", "; perimeters = 3", "; fill_pattern = gyroid",
                            "; support_material = 0", "; first_layer_temperature = 215", "; nozzle_diameter = 0.4",
                            "; brim_width = 5", "; retract_lift = 0\n", "; wipe = 1\n",
                            "; external_perimeter_speed = 25\n", "; elefant_foot_compensation = 0.1\n",
                            "\nM201 X500 Y500"):
                self.assertIn(setting, text, f"{name}.gcode: {setting}")


class BodyGeometryTests(unittest.TestCase):
    """Sondy w układzie urządzenia: czy w danym miejscu jest materiał, czy otwór."""

    def test_window_is_open_over_whole_active_area(self):
        cx, cy = ACTIVE_X0 + ACTIVE_W / 2, ACTIVE_Y0 + ACTIVE_H / 2
        self.assertFalse(is_solid("body", cx - 1, cy - 1, 0.2, 2, 2, FRONT_T - 0.4), "środek ekranu zasłonięty")
        for x in (ACTIVE_X0 + 0.3, ACTIVE_X0 + ACTIVE_W - 0.5):
            for y in (ACTIVE_Y0 + 0.3, ACTIVE_Y0 + ACTIVE_H - 0.5):
                self.assertFalse(is_solid("body", x, y, 0.2, 0.2, 0.2, FRONT_T - 0.4),
                                 f"róg obszaru aktywnego ({x:.1f}, {y:.1f}) zasłonięty")

    def test_window_edges_are_one_margin_outside_active_area(self):
        cx, cy = ACTIVE_X0 + ACTIVE_W / 2, ACTIVE_Y0 + ACTIVE_H / 2
        z, t = 0.2, FRONT_T - 0.4
        edges = {  # (otwór tuż wewnątrz krawędzi okna, ramka tuż za nią)
            "dolna": (box(cx, ACTIVE_Y0 - WINDOW_MARGIN + 0.15, z, 1, 0.1, t),
                      box(cx, ACTIVE_Y0 - WINDOW_MARGIN - 0.25, z, 1, 0.1, t)),
            "górna": (box(cx, ACTIVE_Y0 + ACTIVE_H + WINDOW_MARGIN - 0.25, z, 1, 0.1, t),
                      box(cx, ACTIVE_Y0 + ACTIVE_H + WINDOW_MARGIN + 0.15, z, 1, 0.1, t)),
            "lewa": (box(ACTIVE_X0 - WINDOW_MARGIN + 0.15, cy, z, 0.1, 1, t),
                     box(ACTIVE_X0 - WINDOW_MARGIN - 0.25, cy, z, 0.1, 1, t)),
            "prawa": (box(ACTIVE_X0 + ACTIVE_W + WINDOW_MARGIN - 0.25, cy, z, 0.1, 1, t),
                      box(ACTIVE_X0 + ACTIVE_W + WINDOW_MARGIN + 0.15, cy, z, 0.1, 1, t)),
        }
        for side, (inside, outside) in edges.items():
            self.assertFalse(intersects("body();", inside), f"krawędź okna {side}: za wąsko względem ekranu")
            self.assertTrue(intersects("body();", outside), f"krawędź okna {side}: za szeroko względem ekranu")

    def test_cover_inner_face_sits_on_measured_usb_plug(self):
        z_plug = FRONT_T + PLUG_FROM_PANEL_FRONT                  # 19.7 od frontu korpusu
        self.assertFalse(intersects("body(); cover();", box(WALL + 1, WALL + 1, z_plug - 0.15, 10, 10, 0.1)),
                         "pokrywa sięga przed wtyczkę USB-C (wtyczka się nie zmieści)")
        self.assertTrue(is_solid("cover", WALL + 1, WALL + 1, z_plug + 0.05, 10, 10, 0.1),
                        "pokrywa nie dociska wtyczki USB-C (elektronika lata)")

    def test_bezel_lips_cover_panel_edges(self):
        cy = ACTIVE_Y0 + ACTIVE_H / 2
        cx = ACTIVE_X0 + ACTIVE_W / 2
        lips = {
            "lewa": (PANEL_X0 + 0.3, cy, 1.0, 1.0),
            "prawa": (PANEL_X0 + PANEL_W - 1.3, cy, 1.0, 1.0),
            "górna": (cx, PANEL_Y0 + PANEL_H - 1.3, 1.0, 1.0),
            "dolna": (cx, PANEL_Y0 + 2.0, 1.0, 4.0),  # pasek FPC zasłonięty
        }
        for side, (x, y, dx, dy) in lips.items():
            self.assertTrue(is_solid("body", x, y, 0.2, dx, dy, FRONT_T - 0.4), f"brak ramki: {side}")

    def test_panel_pocket_fits_panel_with_tolerance(self):
        z = FRONT_T + 0.1
        self.assertFalse(is_solid("body", WALL + 0.05, H / 2, z, 0.2, 2, PANEL_T - 0.2), "kieszeń za wąska z lewej")
        self.assertFalse(is_solid("body", W - WALL - 0.25, H / 2, z, 0.2, 2, PANEL_T - 0.2), "kieszeń za wąska z prawej")
        self.assertFalse(is_solid("body", W / 2, WALL + 0.05, z, 2, 0.2, PANEL_T - 0.2), "kieszeń za niska")
        self.assertTrue(is_solid("body", WALL - 0.6, H / 2, z, 0.4, 2, PANEL_T - 0.2), "ścianka przy kieszeni")

    def test_panel_fits_pocket_with_1mm_on_each_side(self):
        z, t = FRONT_T + 0.05, PANEL_T - 0.1
        # panel powiększony o 0,95 mm z każdej strony mieści się w kieszeni...
        grown = box(WALL + 0.05, WALL + 0.05, z, PANEL_W + 2 * TOL - 0.1, PANEL_H + 2 * TOL - 0.1, t)
        self.assertFalse(intersects("body();", grown), "panel nie ma 1 mm luzu z każdej strony")
        # ...ale kieszeń nie jest większa niż panel + 1,1 mm z każdej strony
        for name, probe in {
            "lewa": box(PANEL_X0 - TOL - 0.1, H / 2, z, 0.05, 2, t),
            "prawa": box(PANEL_X0 + PANEL_W + TOL + 0.05, H / 2, z, 0.05, 2, t),
            "dolna": box(W / 2, PANEL_Y0 - TOL - 0.1, z, 2, 0.05, t),
            "górna": box(W / 2, PANEL_Y0 + PANEL_H + TOL + 0.05, z, 2, 0.05, t),
        }.items():
            self.assertTrue(intersects("body();", probe), f"ścianka {name}: luz większy niż 1,1 mm")

    def test_whole_screen_visible_when_panel_pushed_to_any_wall(self):
        for dx in (-TOL, 0, TOL):
            for dy in (-TOL, 0, TOL):
                screen = box(ACTIVE_X0 + dx - 0.25, ACTIVE_Y0 + dy - 0.25, 0.2, ACTIVE_W + 0.5, ACTIVE_H + 0.5, FRONT_T - 0.4)
                self.assertFalse(intersects("body();", screen),
                                 f"panel przesunięty o ({dx:+.1f}, {dy:+.1f}) mm: ramka zasłania ekran")

    def test_cavity_behind_panel_is_empty(self):
        z0 = FRONT_T + PANEL_T + 0.5
        self.assertFalse(is_solid("body", WALL + 1, WALL + 1, z0, W - 2 * WALL - 2, H - 2 * WALL - 2, INNER_CLEAR - 1))

    def test_cable_notch_in_right_wall_seen_from_front(self):
        y = NOTCH_CENTER_Y - 2
        z = D - NOTCH_D + 1
        self.assertFalse(is_solid("body", W - WALL - 0.5, y, z, WALL + 1, 4, NOTCH_D - 2), "brak wycięcia na kabel z prawej")
        self.assertTrue(is_solid("body", -0.5, y, z, WALL + 1, 4, NOTCH_D - 2), "lewa ścianka ma być pełna")

    def test_cable_notch_fits_4mm_cable_at_bottom_of_right_wall(self):
        x, dx = W - WALL - 0.5, WALL + 1
        y0, z0 = WALL, D - NOTCH_D                                  # dół i przód wycięcia
        cable = box(x, y0 + PLAY / 2, z0 + PLAY / 2, dx, CABLE, CABLE)
        self.assertFalse(intersects("body();", cable), "kabel 4 × 4 mm nie przechodzi przez ściankę")
        opening = box(W - WALL - 0.5, WALL + 0.05, D - NOTCH_D + 0.05, WALL + 1, NOTCH_W - 0.1, NOTCH_D - COVER_T - 0.1)
        self.assertFalse(intersects("cover();", opening), "pokrywa wchodzi w otwór wycięcia")
        self.assertTrue(is_solid("cover", W - LEDGE - COVER_TOL - 0.3, WALL + 1, D - COVER_T + 0.05, 0.2, 2, 0.2),
                        "kontrola: pokrywa zamyka wnętrze tuż za otworem")
        self.assertFalse(is_solid("body", x, WALL + 0.05, z0 + 1, dx, 0.2, 2), "wycięcie nie zaczyna się przy dnie")
        self.assertTrue(is_solid("body", x, WALL - 0.4, z0 + 1, dx, 0.2, 2), "kontrola: dolna ścianka pełna")
        self.assertTrue(is_solid("body", x, y0 + NOTCH_W + 0.2, z0 + 1, dx, 0.3, 2), "wycięcie wyższe niż 5,4 mm")
        self.assertTrue(is_solid("body", x, y0 + 1, z0 - 0.5, dx, 2, 0.3), "wycięcie głębsze niż 7,9 mm od tyłu")

    def test_rear_rim_has_recess_for_cover(self):
        y = H / 3
        self.assertTrue(is_solid("body", 0.2, y, D - COVER_T + 0.5, 0.6, 2, COVER_T - 1), "cienka krawędź zewnętrzna")
        self.assertFalse(is_solid("body", LEDGE + 0.1, y, D - COVER_T + 0.5, WALL - LEDGE - 0.2, 2, COVER_T - 1),
                         "wnęka na pokrywę")
        self.assertTrue(is_solid("body", LEDGE + 0.1, y, D - COVER_T - 2, WALL - LEDGE - 0.2, 2, 1.5),
                        "półka pod pokrywą")


class CoverGeometryTests(unittest.TestCase):
    def test_cover_plate_sits_in_recess(self):
        self.assertTrue(is_solid("cover", W / 2 - 1, H / 2 - 1, D - COVER_T + 0.5, 2, 2, COVER_T - 1))
        self.assertFalse(is_solid("cover", 0, H / 2, D - COVER_T + 0.5, LEDGE + COVER_TOL - 0.1, 2, COVER_T - 1),
                         "pokrywa ma mieć luz w obrysie wnęki")

    def test_cover_is_flat_without_stand_fins(self):
        self.assertTrue(is_solid("cover", W / 2 - 1, H / 2 - 1, D - COVER_T + 0.5, 2, 2, COVER_T - 1))  # kontrola
        self.assertFalse(is_solid("cover", -1, -1, D + 0.01, W + 2, H + 2, 60), "za pokrywą nie może nic wystawać")


class StandGeometryTests(unittest.TestCase):
    """Podstawka w układzie świata; urządzenie = body() + cover() ustawione przez device_on_stand()."""

    def test_device_rests_on_seat_without_interference(self):
        self.assertFalse(intersects("stand();", "device_on_stand();"), "urządzenie przenika podstawkę")
        self.assertTrue(intersects("stand();", "translate([0, -0.5, 0]) device_on_stand();"),
                        "urządzenie nie leży na siedzisku (0,5 mm niżej powinno już dotykać)")

    def test_lip_and_backrest_hold_device_with_tolerance(self):
        # Przesunięcie wzdłuż osi Z urządzenia (prostopadle do frontu): spód ślizga się równolegle
        # do siedziska, więc styk oznacza wargę (do przodu) albo oparcie (do tyłu), a nie siedzisko.
        t = math.radians(TILT_DEG)

        def moved(d):
            return f"translate([0, {-d * math.sin(t)}, {d * math.cos(t)}]) device_on_stand();"

        self.assertFalse(intersects("stand();", "device_on_stand();"), "kontrola: w pozycji wyjściowej bez przenikania")
        for d in (-(STAND_TOL - 0.1), STAND_TOL - 0.1):
            self.assertFalse(intersects("stand();", moved(d)), f"luz w podstawce mniejszy niż {abs(d):.1f} mm")
        self.assertTrue(intersects("stand();", moved(-(STAND_TOL + 0.3))), "brak wargi przed frontem")
        self.assertTrue(intersects("stand();", moved(STAND_TOL + 0.3)), "brak oparcia za pokrywą")

    def test_device_leans_back_fifteen_degrees(self):
        # Punkt w górnej ściance ramki (urządzenie: x = W/2, y = H - 1.5, z = 1) po przechyleniu.
        t = math.radians(TILT_DEG)
        y = (H - 1.5) * math.cos(t) - 1.0 * math.sin(t) + SEAT_H
        z = (H - 1.5) * math.sin(t) + 1.0 * math.cos(t)
        self.assertTrue(intersects("device_on_stand();", box(W / 2 - 0.2, y - 0.2, z - 0.2, 0.4, 0.4, 0.4)),
                        "górna krawędź nie jest tam, gdzie wypada przy 15°")
        self.assertFalse(intersects("device_on_stand();", box(W / 2 - 0.2, H - 1.5 + SEAT_H - 0.2, 0.8, 0.4, 0.4, 0.4)),
                         "urządzenie stoi pionowo zamiast odchylone")

    def test_nothing_goes_below_the_table(self):
        below = box(-50, -20, -50, W + 100, 19.99, 200)  # do Y = -0.01: styk ścian z blatem nie jest przenikaniem
        self.assertTrue(intersects("stand();", box(-1, 0, BASE_FRONT_Z - 1, W + 2, 1, 5)), "kontrola: podstawa na stole")
        self.assertFalse(intersects("stand();", below), "podstawka pod blatem")
        self.assertFalse(intersects("device_on_stand();", below), "urządzenie pod blatem")

    def test_stand_does_not_cover_window(self):
        window_x0 = PANEL_X0 + ACTIVE_LEFT - WINDOW_MARGIN
        window_y0 = PANEL_Y0 + ACTIVE_BOTTOM - WINDOW_MARGIN
        in_front_of_window = on_stand(box(window_x0, window_y0, -40, ACTIVE_W + 2 * WINDOW_MARGIN,
                                          ACTIVE_H + 2 * WINDOW_MARGIN, 40))
        self.assertTrue(intersects("stand();", on_stand(box(window_x0, 0, -40, ACTIVE_W, window_y0, 40))),
                        "kontrola: warga zasłania dolny pasek ramki")
        self.assertFalse(intersects("stand();", in_front_of_window), "podstawka zasłania okno ekranu")

    def test_stand_leaves_cable_notch_free(self):
        # do tylnej płaszczyzny urządzenia: za nią stoi oparcie, ale kabel biegnie przed pokrywą
        notch = on_stand(box(W - WALL - 1, NOTCH_CENTER_Y - NOTCH_W / 2, D - NOTCH_D, WALL + 40, NOTCH_W, NOTCH_D))
        self.assertFalse(intersects("stand();", notch), "podstawka blokuje wyjście kabla")

    def test_cable_drops_to_table_beside_stand(self):
        # kabel wychodzi prostopadle w prawo i opada na blat obok podstawki: nic go nie ciągnie do przodu ani do tyłu
        beside = box(W + 0.01, 0, BASE_FRONT_Z - 10, 40, 40, BASE_BACK_Z - BASE_FRONT_Z + 20)
        self.assertTrue(intersects("stand();", box(W - 4, 0, 0, 3, 5, 10)), "kontrola: podstawka przy prawym boku")
        self.assertFalse(intersects("stand();", beside), "podstawka wystaje w bok pod wyjście kabla")
        self.assertFalse(intersects("device_on_stand();", beside), "urządzenie wystaje w bok")


class FitTestGeometryTests(unittest.TestCase):
    def test_fit_test_has_same_window_and_pocket(self):
        cx, cy = ACTIVE_X0 + ACTIVE_W / 2, ACTIVE_Y0 + ACTIVE_H / 2
        self.assertFalse(is_solid("fit_test", cx - 1, cy - 1, 0.2, 2, 2, FRONT_T - 0.4))
        self.assertTrue(is_solid("fit_test", cx, PANEL_Y0 + 2.0, 0.2, 1, 4, FRONT_T - 0.4))
        self.assertFalse(is_solid("fit_test", WALL + 0.05, H / 2, FRONT_T + 0.1, 0.2, 2, PANEL_T - 0.2))


if __name__ == "__main__":
    unittest.main()
