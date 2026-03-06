# Project Guidelines

## Scope
- 기본 작업 대상은 `projects/GPL_Code`와 `tools/controller-f5.ps1`이다.
- 사용자가 명시하지 않는 한 `docs/` 폴더는 분석/수정 대상에서 제외한다.

## Persistent Request Handling
- 사용자가 "영구", "항상", "기본으로", "앞으로도" 같은 표현으로 **지속 반영**을 요청하면, 에이전트는 해당 요청을 프로젝트 지침 컴포넌트(예: `.github/copilot-instructions.md`, 필요 시 `.github/instructions/*.instructions.md`)에 즉시 반영한다.
- 반영 시 기존 규칙과 충돌 여부를 먼저 확인하고, 충돌 시에는 기존 규칙을 깨지 않는 방향으로 최소 수정한다.
- 영구 요청으로 반영한 내용은 같은 세션에서 다시 묻지 않고 기본 동작으로 간주한다.
- 영구 요청이 저장소 전역 규칙이 아닌 사용자 선호 성격이면 사용자 메모리에 함께 기록해 다음 작업에도 우선 적용한다.

## Architecture
- 이 저장소는 **Entry/Core 분리 구조**를 따른다.
- `Entry_*.gpl`: 상위 흐름(오케스트레이션)만 담당한다.
- `Core_*.gpl`: 공통 유틸/에러 처리/기반 기능을 담당한다.
- 현재 엔트리 포인트는 `projects/GPL_Code/Project.gpr`의 `ProjectStart="Entry_Main.MAIN"`이다.

## Build and Deploy
- 기본 배포/컴파일/시작 명령은 `tools/controller-f5.ps1`를 사용한다.
- 권장 실행: `-ProjectKey GPL_Code`
- 에이전트가 배포를 수행할 때는 프로젝트 폴더명(`GPL_Code`)과 `Project.gpr`의 `ProjectName` 일치 여부를 먼저 확인한다.

## GPL Code Conventions
- 파일/모듈 역할:
  - `Core_*.gpl` = 공통 기능
  - `Entry_*.gpl` = 실행 흐름
- 로그는 `CEH` 경유를 기본으로 한다.
  - 일반 로그: `CEH.cehLog(msg, context)`
  - 예외 로그: `CEH.cehLogEx(ex, context)`
- `context`는 함수명 수준의 짧은 식별자(예: `MAIN`)를 사용한다.
- 사용자 정의 에러는 `CEH.cehThrow(...)`, `CEH.cehThrowRobot(...)`를 우선 사용한다.
- `Catch`에서 예외를 의도적으로 무시하면 이유를 주석으로 남긴다.

## Project.gpr Rules
- `ProjectSource` 순서는 의존성 기준(Core 먼저, Entry 마지막)을 유지한다.
- 모듈 추가/삭제 시 `Project.gpr` 변경을 같은 작업에 포함한다.
- `.gpr`에 존재하지 않는 `ProjectSource` 참조가 생기지 않도록 유지한다.

## Known Pitfalls
- `ProjectName` 불일치(특히 대소문자 차이)는 컴파일/시작 실패 원인이 된다.
- 구형 CEH API(`CEH.log`, `CEH.logException`) 대신 `cehLog`, `cehLogEx`를 사용한다.
- `tools/controller-f5.ps1`에서 `-SkipUnchanged`/`-VerifySize`는 업로드 전략에 영향을 주므로 의도적으로 선택한다.

## Editing Guidance
- 기존 스타일(들여쓰기, 주석 톤, 모듈 구조)을 유지하고, 관련 없는 리포맷은 피한다.
- 공개 API 이름은 의도를 드러내게 작성한다.
- 수학/기하 계산 함수는 좌표계(XY/XYZ)와 단위를 주석으로 명시한다.

## Legacy-to-New Transition Policy
- 기능 개선으로 신규 구현이 도입되면, 기존 구현과 혼동되지 않도록 레거시 코드에 경고성 주석(예: LEGACY, 신규 권장 API)을 명시한다.
- 레거시 코드가 아직 참조 중이면 즉시 삭제하지 않고 호환 계층으로 유지하되, 제거 조건(호출부 마이그레이션 완료/검증 완료)을 주석 또는 문서에 남긴다.
- 레거시 코드 참조가 모두 제거된 것이 확인되면, 같은 작업에서 안전 검증 후 레거시 코드를 제거하는 방향을 우선한다.
