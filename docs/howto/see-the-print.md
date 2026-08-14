## See the print (Wave 6.3)

Color-by-thickness and overhang paint help you verify a part before slicing:

- Thickness paint: flags faces thinner than the current min wall (default 1.2 mm).
- Overhang paint: flags faces steeper than the overhang angle (default 45°) and not touching the bed.
- Bed ghost: shows a translucent 220×220 mm build plate in Form mode.

How to use:

1. Switch to Form mode (View → Mode → Form).
2. Click Analyze to compute print checks. The digest still shows min wall, overhang area, and bed fit.
3. Toggle Thickness and/or Overhang to see paint in the viewport. Paint reuses the section/zebra shader path.
4. Toggle Bed to show the translucent bed outline on the ground plane.

Notes:

- Thresholds come from Print Setup (min_wall and overhang_deg). 3MF already carries `sx:min_wall=1.2`.
- Analyze and Orient both refresh the paint data; toggles only affect the viewport.
- Support generation is left to the slicer (future wave). This feature is strictly a way of seeing.
