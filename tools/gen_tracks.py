"""Generates the built-in tracks (data/tracks/*.json) from corner polygons.
Each corner (x, y, d): d = how far before/after the corner the spline control points are placed (bigger = wider corner).
d = 0 means a plain pass-through point. The game itself only stores/edits the resulting control points."""
import json, math
def build(corners, width, runoff, bank=None, elev=None):
    """bank / elev: optional lists (one value per corner tuple) -> per control point props [w, runoff, bank, elev]."""
    pts, props = [], []
    n = len(corners)
    for i, (x, y, d) in enumerate(corners):
        pr = [width, runoff, (bank[i] if bank else 0.0), (elev[i] if elev else 0.0)]
        if d <= 0:
            pts.append([x, y]); props.append(pr); continue
        ax, ay, _ = corners[i - 1]; bx, by, _ = corners[(i + 1) % n]
        la = math.hypot(ax - x, ay - y); lb = math.hypot(bx - x, by - y)
        pts.append([round(x + (ax - x) / la * d, 1), round(y + (ay - y) / la * d, 1)])
        pts.append([round(x + (bx - x) / lb * d, 1), round(y + (by - y) / lb * d, 1)])
        props.append(pr); props.append(list(pr))
    return pts, props
# per-track character: (runoff, bank per corner, elevation per corner)
CHARACTER = {
 "harbor_park":   (25, None, [0,0,2,6,8,8,6,4,2,0,0,0,2,2,0]),
 "old_town":      (3, None, [0,0,1,2,4,4,3,3,2,1,0,0]),
 "speedway":      (30, [0,14,14,14,14], None),
 "alpine_ring":   (18, None, [0,4,12,18,24,30,36,40,34,26,18,10,6,3,1]),
 "desert_sprint": (45, None, None),
 "coastal_esses": (14, None, [0,2,5,9,12,14,12,8,5,3,2,1,0]),
}

TRACKS = [
 ("harbor_park", "Harbor Park", "Portsmouth, UK", 14, 12, [(0,0,0),(800,0,40),(950,-150,60),(950,-400,120),(700,-550,30),(450,-550,30),(350,-750,80),(500,-950,150),(200,-1150,40),(-100,-1100,60),(-200,-850,25),(-450,-800,25),(-550,-500,200),(-400,-150,100),(-200,0,80)]),
 ("old_town", "Old Town Street Circuit", "Valletta, Malta", 11, 15, [(0,0,0),(700,0,25),(700,-200,25),(900,-200,25),(900,-500,30),(600,-500,25),(600,-350,25),(300,-350,25),(300,-600,25),(0,-600,40),(-150,-400,40),(-150,-150,40)]),
 ("speedway", "Lakeside Speedway", "Indiana, USA", 16, 16, [(0,0,0),(900,0,300),(900,-700,300),(-400,-700,300),(-400,0,300)]),
 ("alpine_ring", "Alpine Ring", "Spielberg, Austria", 12, 14, [(0,0,0),(600,0,30),(650,-250,15),(450,-300,15),(500,-550,60),(800,-600,40),(850,-850,15),(600,-900,15),(300,-800,50),(100,-950,30),(-200,-850,40),(-150,-600,15),(-350,-550,15),(-300,-300,70),(-150,-80,60)]),
 ("desert_sprint", "Desert Sprint", "Doha, Qatar", 15, 11, [(0,0,0),(1300,0,180),(1600,-300,180),(1400,-700,150),(900,-800,100),(700,-1100,150),(200,-1200,200),(-200,-900,120),(-100,-600,80),(-400,-400,150),(-300,0,150)]),
 ("coastal_esses", "Coastal Esses", "Estoril, Portugal", 13, 13, [(0,0,0),(700,0,50),(900,-120,80),(800,-300,80),(1000,-450,80),(900,-650,80),(600,-700,30),(300,-550,100),(100,-750,40),(-250,-700,60),(-300,-400,30),(-100,-300,30),(-200,-100,60)]),
]
for tid, name, loc, width, laps, corners in TRACKS:
    runoff, bank, elev = CHARACTER[tid]
    pts, props = build(corners, width, runoff, bank, elev)
    data = {"format": 2, "id": tid, "name": name, "location": loc, "width": width, "default_laps": laps,
            "sectors": [0.333, 0.667], "builtin": True, "start_u": 0.0, "points": pts, "props": props}
    json.dump(data, open(f"data/tracks/{tid}.json", "w"), indent=1)
print("ok")
