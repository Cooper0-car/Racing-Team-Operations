# Racing Team Operations

레이싱 팀 운영 시뮬레이터입니다. 팀을 만들고, 차를 개발하고, 실시간 레이스 시뮬레이션에서 전략을 지시합니다. 트랙 크리에이터로 직접 그린 서킷을 시즌 캘린더에 넣어 내 팀이 그 트랙에서 경쟁하는 모습을 볼 수 있습니다.

현재 버전: **v0.2** (Phase 1 + Phase 4 트랙 크리에이터 + 설정 + 한국어)

- 엔진: **Godot 4.3** (GDScript), Windows 데스크톱 타깃
- 화면: 2D 탑다운, 다크 모터스포츠 UI

## 실행 방법

**바로 플레이:** 배포된 `RacingTeamOperations.exe`를 실행하면 됩니다(설치 불필요). 처음 실행할 때 Windows SmartScreen 경고가 뜨면 "추가 정보 → 실행"을 누르세요.

**소스에서 실행:**

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
| V D A X | 트랙 에디터: 선택 / 그리기 / 포인트 추가 / 포인트 삭제 |
| S 2 3 Z P | 트랙 에디터: 출발선 / 섹터 2 / 섹터 3 / DRS / 피트레인 |
| Ctrl+Z / Ctrl+Y / Ctrl+S / F | 트랙 에디터: 실행 취소 / 다시 실행 / 저장 / 화면 맞춤 |

## 번역

기본 언어는 한국어이며 설정에서 영어로 바꿀 수 있습니다. 번역은 `data/i18n/ko.json`(영어 원문 → 한국어)에 있습니다. `python3 tools/extract_strings.py ko`를 실행하면 번역이 빠진 문구를 보여 줍니다.

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
  tracks/*.json        트랙 = 컨트롤 포인트 + 포인트별 폭/런오프/뱅킹/고도 + 섹터 (tools/gen_tracks.py)
  i18n/ko.json         한국어 번역
scripts/
  autoload/            DataDB(데이터 로더), Game(커리어·설정·화면 전환), SaveSystem
  models/              Career, Team, Driver, Car, CarComponent, Finance
  track/track_data.gd  스플라인 → 샘플링, 레이싱 라인, 곡률, 코너·제동·추월구간, DRS, 피트레인, 다리/겹침 검사, 통계, 편집 연산
  sim/                 PerformanceModel(물리), RaceSimulation, RaceCar, Qualifying
  ai/                  AITeamManager(AI 팀 개발·정비)
  ui/                  UI 헬퍼·테마, 화면(screens: 메뉴, 커리어, 레이스, 트랙 에디터, 설정 …), 커리어 페이지(pages), 위젯
assets/fonts/          Pretendard 글꼴 (SIL OFL)
tests/                 헤드리스 테스트, UI 스모크 테스트
docs/PROGRESS.md       구현 현황과 다음 단계
```

자세한 설계와 진행 상황은 [docs/PROGRESS.md](docs/PROGRESS.md)에 있습니다.
