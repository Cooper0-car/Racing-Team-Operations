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
| Settings | ✅ (basic) | Autosave, default race speed, UI scale, master volume |

## Next phases

- **Phase 2 — management depth:** contract negotiation (salary, length, bonuses, number-1 status), staff (engineers, mechanics, strategist, scouts…), development projects that take weeks, facilities, sponsors with objectives, scouting with uncertainty ranges, driver development via training and staff, AI hiring and firing, transfer market.
- **Phase 3 — advanced racing:** tyre compounds and strategy, fuel load, pit stops (crew skill, mistakes), weather (dynamic, affects grip and incidents), damage model, safety car / VSC, penalties, team orders, advanced strategy commands.
- **Phase 4 — track creator:** draw and edit control points, width, start/finish, pit lane, sectors, DRS, elevation, banking, validation, save to `user://tracks/`, library rename/duplicate/delete, custom race on any track. Most of the generation pipeline already exists in `TrackData`.
- **Phase 5 — polish:** audio, animations, tutorial, achievements, balance pass, localisation (strings are already isolated in the UI layer).

## Known limitations (Phase 1)

- Single tyre compound, no pit stops, no fuel strategy, weather always clear (Phase 3).
- Cars follow the centerline with lateral offsets for passing; there is no optimised racing line yet (Phase 4).
- Contracts auto-renew at season end (Phase 2).
- "Sim to end" takes a few seconds on a long race. It runs across frames, so the window stays responsive.
