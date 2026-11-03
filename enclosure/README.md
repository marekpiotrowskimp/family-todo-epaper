# Enclosure: 4.2″ e-paper + XIAO ESP32-S3

A frame for a desk or shelf that sits in a separate stand tilting it 15° backwards. The USB cable exits through the right wall right at the bottom (looking from the front), sideways at a right angle, next to the stand. The model is parametric (`epaper_frame.scad`, OpenSCAD) and prints without supports.

## Files

| File | Description |
|---|---|
| `epaper_frame.scad` | Parametric source (OpenSCAD) |
| `fit_test.stl` / `.gcode` | **Test print:** just the frame with the window and the panel pocket. Print this first. |
| `case_body.stl` / `.gcode` | Body with the frame, panel pocket and cover recess |
| `case_cover.stl` / `.gcode` | Flat back cover (glued into the body recess) |
| `stand.stl` / `.gcode` | Stand: seat tilted 15°, lip at the front, backrest at the back |
| `ender3_config.ini` | PrusaSlicer profile (Ender-3 Pro + Devil Design PLA), taken from the `air_condition_receiver` enclosure and tuned (no Z-hop) |
| `tests/test_enclosure.py` | Dimension and geometry tests (`python3 -m unittest discover -s enclosure/tests`) |

## Dimensions

| | |
|---|---|
| Clearance | **panel: 2 mm** on each axis (1 mm per side, `panel_play`); **device in the stand and cable in the cut-out: 1.4 mm** (`play`); glued cover: 0.6 mm |
| Body (external) | **97.0 × 84.0 × 22.2 mm**, 2.5 mm walls, corner radius 2 |
| Cover | 93.9 × 80.9 × 2.5 mm, flat, rests on a 0.95 mm ledge |
| Stand | 97.0 × 58.7 mm base, ~33 mm high |
| Window | 87.4 × 66.2 mm, i.e. the 84.8 × 63.6 active area + 1.3 mm margin on each side (panel clearance + 0.3); visible bezel left / right / bottom / top: 4.2 / 5.4 / 11.2 / 6.6 mm |
| Panel pocket | 92.0 × 79.0 × 1.2 mm (panel 90 × 77 × 1.2 measured with a caliper + 2 mm clearance) behind a 2.0 mm bezel; the bezel overlaps the panel left / right / bottom / top: 0.7 / 1.9 / 7.7 / 3.1 mm |
| Interior | 16.5 mm from the back of the panel to the cover: panel front → shell of the inserted USB-C plug measures 17.7 mm, the cover presses the plug flush so the electronics don't rattle |
| Cable cut-out | right wall, right at the bottom (from the inner surface of the bottom wall), 5.4 mm high, 7.9 mm from the back edge; open 5.4 × 5.4 mm in front of the cover for a 4 × 4 mm cable |
| Posture | in the stand, tilted 15°: front bottom edge 10 mm above the desk, lip 6 mm above the seat (covers only the bottom strip of the bezel), backrest supports 30 mm of the back wall, 0.7 mm clearance front and back |
| Stability | the device's center of mass is ~25 mm behind the front and ~33 mm in front of the back of the stand |

The window is offset because the panel's active area is not centered. Looking from the front, the distances from the panel edges to the active area are (caliper measurements):
- **left:** 2.0 mm, so **right** 3.2 mm;
- **bottom:** 9.0 mm (where the FPC ribbon is), so **top** 4.4 mm.

The window margin (1.3 mm) is larger than the panel clearance (1 mm per side), so even when pushed against any wall the panel shows the whole screen. It is best to center it when gluing. Part of the black border drawn by the firmware is visible in the margin as an even outline.

## Print settings (Ender-3 Pro, Devil Design PLA black)

| Parameter | Value |
|---|---|
| Nozzle / layer | 0.4 mm / 0.2 mm (first 0.2) |
| Walls / top / bottom | 3 perimeters, 4 + 4 solid layers |
| Infill | 20% gyroid |
| Nozzle temperature | 215 °C first layer, 210 °C after |
| Bed | 60 °C throughout |
| Speeds | perimeters 40, external 25, bridges 25, infill 50, first layer 20, travel 150 mm/s |
| Retraction | 5 mm, 45 mm/s, **no Z lift (Z-hop)**, retract on layer change, wipe |
| Acceleration | 500 mm/s², jerk 8 (M201–M205 in the G-code) |
| Elephant foot | 0.1 mm compensation (front on the bed) |
| Cooling | 100%, off for the first 3 layers |
| Adhesion | 5 mm brim, 3 × 3 mm skirt |
| Supports | **none** |

Changes compared with the original profile (following the official Creality Ender-3 profile in PrusaSlicer) after prints with uneven walls: Z-hop disabled (the single Z lead screw has play, so lifting and lowering on every retraction could leave layers at different heights), slower external walls and bridges, wipe, constant bed temperature, accelerations in the G-code. If the walls are still uneven, the cause is mechanical: Z axis, roller eccentrics, extruder, damp filament.

## Print time and filament (PrusaSlicer 2.9.4)

| Part | Orientation on the bed | Time | Filament |
|---|---|---|---|
| `fit_test` | front on the bed | ~50 min | 2.9 m (6.9 cm³) |
| `case_body` | front on the bed, walls grow upwards | ~2 h 23 min | 8.8 m (21.3 cm³) |
| `case_cover` | plate on the bed | ~1 h 33 min | 6.1 m (14.7 cm³) |
| `stand` | base plate on the bed, backrest grows upwards (tilted 15°) | ~3 h 00 min | 10.8 m (25.9 cm³) |
| **Total (body + cover + stand)** | | **~6 h 56 min** | **25.7 m (~62 cm³)** |

## Assembly

1. **Test print.** Put the panel into `fit_test` screen-first. It should drop in freely with noticeable play, and the whole active area should be visible, with no white strip of the panel in the window. If something is off, adjust the parameters (section below) and regenerate the files.
2. **Panel.** ⚠️ **Never force the panel in.** The glass cracks under pressure and printed walls can be uneven. The panel must go in on its own. If it catches somewhere, sand down the bulge in the wall or increase `panel_play`. Insert the panel screen-first with the FPC ribbon at the bottom edge, center it in the pocket (about 1 mm gap on each side) and fix it with a drop of hot glue in the 4 corners. On the left the bezel overlaps the panel by only 0.7 mm, so without glue the panel won't be held.
3. **Board.** Place the driver board with the XIAO on the back of the panel, with the ribbon folded at the bottom edge. Plug in the USB-C cable permanently. Leave the bottom-right corner of the interior (14.3–19.7 mm behind the front of the enclosure) free for the cable. The board can be held with double-sided tape or a drop of glue; the cover presses the plug down anyway.
4. **Antenna.** Stick the U.FL antenna to the inside of the cover, away from metal parts.
5. **Cable.** Route the cable along the bottom to the bottom-right corner and lead it out through the cut-out in the right wall, sideways at a right angle. Outside it drops onto the desk next to the stand, so it doesn't pull the device forwards or backwards.
6. **Cover.** Put the flat cover into the recess and fix it with hot glue at a few points around the edge. The glue can be heated later to open the enclosure.
7. **Stand.** Put the enclosure into the stand with the screen facing forward: bottom on the seat, front behind the lip, cover resting against the backrest. The enclosure can be lifted out at any time.

## Changing parameters

The most common adjustments after the test print (`epaper_frame.scad`):

| Problem | Parameter |
|---|---|
| Stand or cut-out too loose / too tight | `play` (1.4) |
| The panel doesn't go in freely or rattles in the pocket | `panel_play` (2.0; the window grows with it), `panel_w` (90), `panel_h` (77) |
| A white strip is visible at the top or bottom of the window | `active_top` (4.4) |
| A white strip is visible at the side of the window | `active_left` (2.0) |
| The cover doesn't close or the electronics rattle | `usb_plug_from_front` (17.7) |
| The cover doesn't fit the recess | `cover_tol` (0.3) |
| The cable doesn't fit the cut-out | `cable_w` (4), `play` |
| Different tilt or height | `tilt_deg` (15), `seat_h` (10), `backrest_h` (30) |
| The stand is too light / tips over | `base_back_z` (55) |

Regenerating the print files (from the `enclosure/` directory):

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
