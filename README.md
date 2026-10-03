# Racing Team Operations

레이싱 팀 운영 시뮬레이터입니다. 팀을 만들고, 차를 개발하고, 실시간 레이스 시뮬레이션에서 전략을 지시합니다. 최종 목표는 플레이어가 직접 그린 트랙에서 레이스를 치르는 것입니다.

- 엔진: **Godot 4.3** (GDScript), Windows 데스크톱 타깃
- 화면: 2D 탑다운, 다크 모터스포츠 UI

## 실행 방법

1. [Godot 4.3 stable](https://godotengine.org/download/archive/4.3-stable/) (Standard 버전, .NET 아님)을 받습니다.
2. Godot를 실행해 **Import**를 누르고 이 폴더의 `project.godot`를 선택합니다.
3. **F5**(Run Project)를 누릅니다.

### Windows .exe 만들기

1. Godot 에디터에서 **Editor → Manage Export Templates → Download and Install**을 실행합니다(최초 1회).
2. **Project → Export…**를 열어 `Windows Desktop` 프리셋을 고르고 **Export Project**를 누릅니다. 결과물은 `export/RacingTeamOperations.exe`(단일 파일)입니다.

## 조작

| 키 | 기능 |
|---|---|
| F12 | 디버그 메뉴 (돈 추가, 레이스 스킵, 부품 최대치, 타이어 마모 설정, 고장 강제 등) |
| Space | 레이스 일시정지/재개 |
| 1–4 | 레이스 배속 1x / 2x / 4x / 8x |
| 마우스 휠 / 드래그 | 트랙 줌 / 이동 |

## 테스트

```
godot --headless res://tests/TestRunner.tscn          # 시뮬레이션·커리어·세이브 자동 테스트
xvfb-run godot --rendering-driver opengl3 res://tests/UISmoke.tscn -- <screenshot_dir>   # 실제 UI 흐름 + 스크린샷
```

## 구조

```
data/                  게임 데이터(JSON). 수치는 여기서 수정하면 됩니다.
  balance.json         포인트, 상금, 비용, 예산/본부/철학/차량 레벨
  components.json      부품 17종과 각 부품이 영향 주는 성능 축
  drivers.json         드라이버 30명 (tools/gen_database.py로 생성)
  teams.json           AI 팀 9개
  championships.json   챔피언십/캘린더
  tracks/*.json        트랙 = 컨트롤 포인트 + 폭 + 섹터 (tools/gen_tracks.py)
scripts/
  autoload/            DataDB(데이터 로더), Game(커리어·설정·화면 전환), SaveSystem
  models/              Career, Team, Driver, Car, CarComponent, Finance
  track/track_data.gd  스플라인 → 샘플링, 곡률, 코너·추월구간 감지, 트랙 통계
  sim/                 PerformanceModel(물리), RaceSimulation, RaceCar, Qualifying
  ai/                  AITeamManager(AI 팀 개발·정비)
  ui/                  UI 헬퍼·테마, 화면(screens), 커리어 페이지(pages), 위젯
tests/                 헤드리스 테스트, UI 스모크 테스트
docs/PROGRESS.md       구현 현황과 다음 단계
```

자세한 설계와 진행 상황은 [docs/PROGRESS.md](docs/PROGRESS.md)에 있습니다.
