# Development progress

## Architecture decisions

- **Simulation is UI-independent.** `RaceSimulation` is a plain `RefCounted` stepped at a fixed 1/30 s. The UI only reads state and sends commands (`set_mode`). Game speed = more fixed steps per frame, so 8x and "sim to end" produce the same logic as 1x. Headless tests run whole seasons without a window.
- **Physics-based lap times, not "car level = speed".** `PerformanceModel` turns car dimensions into physical parameters (vmax, acceleration, traction, mechanical grip, aero grip, braking grip). For every track sample it computes a corner speed from the local radius, then backward/forward passes for braking and acceleration. Tight tracks reward mechanical grip/traction/braking; fast tracks reward aero and top speed, automatically and with no per-track tuning.
- **Tracks are just control points.** `TrackData` builds everything else from the points: a centripetal Catmull-Rom centerline, 4 m samples, smoothed curvature, corners, overtaking zones (braking points after straights), sectors, and stats. The future track editor only has to edit `points`, `width` and `sectors`.
- **Data-driven.** Balance values, components, drivers, teams, championships and tracks live in `data/*.json`. Saves are JSON in `user://saves/`.
- **Same rules for AI and player.** AI teams buy upgrades through the same `Career.upgrade_component()` with the same prices.

## Phase 1 — playable core ✅

| System | Status | Notes |
|---|---|---|
| Main menu | ✅ | Continue, New, Load, Custom Race, Track Library, Settings, Exit. Animated AI race in the background |
| Team creation | ✅ | Name, abbreviation, 2 colours, logo shape, budget, HQ, starting car, philosophy, difficulty, sign 2 free agents |
| Philosophies / HQ | ✅ | Affect budget, upgrade cost and effect, reliability, quali/race pace, tyre wear, young driver salary |
| Drivers | ✅ | 22 attributes, traits, morale, age, salary, contract years, career stats. Replace a driver with a free agent |
| Car components | ✅ | 17 components with performance, reliability, wear, weight, level, failure chance. Upgrade, reliability work, rebuild |
| Performance dimensions | ✅ | 11 dimensions + reliability, derived from components |
| AI teams | ✅ | 9 teams with budgets and philosophies. They maintain worn parts and upgrade by priority and value |
| Tracks | ✅ | 6 built-in circuits with different characters (street, speedway, technical, high-downforce…) |
| Qualifying | ✅ | 3 runs per driver with the race physics, sector times and mistakes |
| Race simulation | ✅ | Cars move on the spline. Traffic, slipstream, overtaking in braking zones, blue flags, lap-1 grid start with reaction times, mistakes (lock-up, off-track, spin, crash), contact, reliability failures, tyre wear, pace modes |
| Race UI | ✅ | Track view, timing tower (gap, interval, last lap, fastest lap, tyres, status), driver panels with Conserve/Normal/Push, radio and race control feed, camera follow, pause + 1/2/4/8x, sim to end |
| Results / analysis | ✅ | Classification, positions gained, best lap, points, overtakes, mistakes, team income/expenses, driver vs car potential, incidents, position and lap-time charts |
| Championship | ✅ | Driver + constructor standings, calendar with results, season end (prizes, ageing, development), multiple seasons |
| Finance | ✅ | Ledger, per-category summary, projected cash flow, balance chart, negative balance warning |
| Reputation | ✅ | Changes with results, reliability and finances; drives sponsor income |
| Save / load | ✅ | 5 slots + autosave, atomic writes, menu Continue |
| Debug menu (F12) | ✅ | Money, max car, repair, boost drivers, skip race, tyre wear, force failure, all-push, reload data |
| Settings | ✅ | Superseded by the v0.2 settings screen (see below) |

## Phase 4 — track creator ✅ (v0.2)

| System | Status | Notes |
|---|---|---|
| Track format v2 | ✅ | Per control point: width, runoff, banking, elevation. Start/finish anchor, sectors, DRS zones, pit lane. Older files load with defaults |
| Editor tools | ✅ | Freehand draw (RDP simplification), select/move, add point (inserted into the nearest segment), delete point, start/finish, sector 2/3, DRS zone (click a straight; it runs to the next braking point), pit entry/exit |
| Editor actions | ✅ | Templates (circle/oval/square), clear and draw, smooth, scale ±10%, reverse direction, 10 m snap, auto DRS, auto pit lane, flip/remove pit, undo/redo (80 steps), keyboard shortcuts |
| Live preview | ✅ | Fast rebuild while dragging, full rebuild (with racing line) 0.35 s after the last change. Racing line, braking zones, overtaking zones, elevation colours, bridges, overlap markers |
| Racing line | ✅ | Multi-resolution minimum-curvature relaxation inside the track limits. Physics uses the racing-line radius, so wider tracks are faster and have more room to pass |
| Elevation / banking / runoff | ✅ | Slopes change acceleration and braking; banking adds corner grip; runoff under 6 m acts as walls, so mistakes turn into crashes more often. Width changes overtaking chances |
| Bridges | ✅ | Crossings are allowed when the sections are at least 5 m apart in elevation; the renderer draws the higher section on top with a shadow |
| DRS | ✅ | Detection 120 m before each zone, within 1 s of the car ahead from lap 2: higher straight-line speed and a better overtaking chance at the next braking zone |
| Validation | ✅ | Errors (too few points, too short/long, ground-level overlap, bad sectors, pit lane too long) block saving and racing; warnings (tight corners, steep slopes, start line in a corner, no DRS/pit) are advisory |
| Race mode | ✅ | Switch the editor into a live AI race on the unsaved layout, at 1-8x; switch back to keep editing |
| Library | ✅ | Built-in + custom tracks, preview, statistics, edit (built-ins as a copy), duplicate, rename, delete, race here |
| Career integration | ✅ | Pick the season calendar (any valid tracks, up to 24 rounds) when creating a career; edit this season before round 1, or next season's calendar any time. Deleted tracks are replaced automatically |
| Custom race | ✅ | Any valid track, DRS on/off, grid modes |

## Settings + localisation (v0.2)

- Full settings screen (General / Display / Audio / Race / Controls): language, units (metric/imperial), autosave, UI sounds, window mode, UI scale, graphics quality (high = anti-aliased track edges, low = surface only), V-Sync, master and effects volume, default race speed, default camera, radio filter, racing line in races, simulation detail (30/60 steps per second), key reference.
- Procedural sound effects (no audio files): clicks, start lights, chequered flag.
- **Korean is the default language.** Translations are plain JSON (`data/i18n/ko.json`, English source text as keys) loaded at runtime. `tools/extract_strings.py ko` lists strings that still need a translation. Notifications and ledger entries are stored as keys + arguments, so they switch language with the game.
- Font: Pretendard (SIL Open Font License, `assets/fonts/`), with Godot's built-in font as fallback for symbols.

## Next phases

- **Phase 2 — management depth:** contract negotiation (salary, length, bonuses, number-1 status), staff (engineers, mechanics, strategist, scouts…), development projects that take weeks, facilities, sponsors with objectives, scouting with uncertainty ranges, driver development via training and staff, AI hiring and firing, transfer market.
- **Phase 3 — advanced racing:** tyre compounds and strategy, fuel load, pit stops (crew skill, mistakes), weather (dynamic, affects grip and incidents), damage model, safety car / VSC, penalties, team orders, advanced strategy commands.
- **Phase 4 follow-ups:** multiple layouts per venue, track logo, tunnels, speed trap / detection loop display, user-made championships.
- **Phase 5 — polish:** audio, animations, tutorial, achievements, balance pass, localisation (strings are already isolated in the UI layer).

## Known limitations

- Single tyre compound, no pit stops, no fuel strategy, weather always clear (Phase 3). Pit lanes are already part of every track and are drawn, but cars only use them once pit stops arrive in Phase 3.
- Contracts auto-renew at season end (Phase 2).
- Godot 4.3's Compatibility renderer has no 2D MSAA, so "High" graphics uses anti-aliased edge lines instead.
- "Sim to end" takes a few seconds on a long race. It runs across frames, so the window stays responsive.
