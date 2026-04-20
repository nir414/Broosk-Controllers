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
- `Project.gpr` 기준 진입점은 `ProjectStart="Main"`이다.
- `Entry_*.gpl`: 상위 흐름(오케스트레이션)만 담당한다.
- `Core_*.gpl`: 공통 유틸/에러 처리/기반 기능을 담당한다.
- 현재 엔트리 포인트는 `projects/GPL_Code/Project.gpr`의 `ProjectStart="Entry_Main.MAIN"`이다.

## Build and Deploy
- 기본 배포/컴파일/시작 명령은 `tools/controller-f5.ps1`를 사용한다.
- 권장 실행: `-ProjectKey GPL_Code`
- 에이전트가 배포를 수행할 때는 프로젝트 폴더명(`GPL_Code`)과 `Project.gpr`의 `ProjectName` 일치 여부를 먼저 확인한다.

## GPL Code Conventions
- **하드코딩 금지**: 개수·크기·상한 등 수량 관련 값을 상수(`Const`)로 고정하지 않는다. 런타임 가변 변수 또는 수요 비례 동적 생성 방식을 기본으로 사용한다. 고정 배열 상한이 불가피한 경우에만 최소 범위의 `Const`를 허용하되, 실제 사용량은 반드시 가변으로 둔다.
- 파일/모듈 역할:
  - `Core_*.gpl` = 공통 기능
  - `Entry_*.gpl` = 실행 흐름
- 로그는 `CEH` 경유를 기본으로 한다.
  - 일반 로그: `CEH.cehLog(msg, context)`
  - 예외 로그: `CEH.cehLogEx(ex, context)`
- 현재 코드베이스의 기본 로그 API는 `Core_ErrorHandler` 경유(`log`, `logException`, 필요 시 `logExceptionThrottled`)를 사용한다.
- `context`는 함수명 수준의 짧은 식별자(예: `SetupAndMacroClass.SetupMacroThread`)를 유지한다.
- GPL 런타임 특성상 문자열/객체는 `Nothing` 가능성을 항상 고려한다.
- `Catch`에서 예외를 의도적으로 무시하면 이유를 주석으로 남긴다.

## Project.gpr Rules
- `ProjectSource` 순서는 의존성 기준(Core/Init 먼저, 실행 모듈 마지막)을 유지한다.
- 모듈 추가/삭제 시 `Project.gpr` 변경을 같은 작업에 포함한다.
- `.gpr`에 존재하지 않는 `ProjectSource` 참조가 생기지 않도록 유지한다.

## Known Pitfalls
- `ProjectName` 불일치(특히 대소문자 차이)는 컴파일/시작 실패 원인이 된다.
- `projects/MergeCode/Project.gpr`의 `ProjectName="MergeCode"`는 폴더명과 일치한다. 향후 변경 시 대소문자 일치를 유지한다.
- `.gpp`/`.gpo`는 바이너리로 열리지 않을 수 있으므로, 가능한 경우 원본 `.gpl` 또는 `Project.gpr`를 기준으로 분석한다.
- 구형 CEH API(`CEH.log`, `CEH.logException`) 대신 `cehLog`, `cehLogEx`를 사용한다.
- `tools/controller-f5.ps1`에서 `-SkipUnchanged`/`-VerifySize`는 업로드 전략에 영향을 주므로 의도적으로 선택한다.

## Editing Guidance
- 기존 스타일(들여쓰기, 주석 톤, 모듈 구조)을 유지하고, 관련 없는 리포맷은 피한다.
- 사용자가 특정 범위를 지정해 수정을 요청하면, 해당 범위만 최소 변경한다. 요청 범위를 벗어난 자율 리팩터링/추가 수정은 금지한다.
- 스레드 제어(`Thread.Abort`, `Thread.Sleep`)와 파일 삭제 같은 운영 민감 로직은 주변 컨텍스트 없이 임의 변경하지 않는다.

## Agent Operation Quality Guardrails
- 비자명한 작업은 `탐색 → 계획 → 수정 → 검증` 순서를 기본으로 한다.
- 코드 변경 전, 성공 기준(예: 정적 오류 0건, 특정 동작 보존)을 먼저 명시하고 그 기준으로 검증한다.
- 증상 완화보다 근본 원인 해결을 우선한다. 임시 우회(하드코딩/테스트 통과만 목적)는 지양한다.
- 파괴적/되돌리기 어려운 작업(대량 삭제, 강제 리셋/푸시, 외부 시스템 변경)은 사용자 명시 승인 없이 수행하지 않는다.
- 요청이 모호하면 질문을 최소화하되(최대 2개), 나머지는 보수적 가정으로 진행한다.

## Instruction & Agent Hygiene
- 지침 파일은 짧고 검증 가능한 규칙 위주로 유지한다(중복/모순 규칙 정기 정리).
- 프롬프트/에이전트의 `description`에는 실제 트리거 키워드를 포함한다.
- 도구 강제 문구는 과도하게 공격적으로 쓰지 않는다. 과호출(오버트리거)이 보이면 조건을 구체화해 조정한다.
- 항상 적용될 필요가 없는 규칙은 범위 기반 규칙 또는 온디맨드 자산(프롬프트/에이전트)로 분리한다.

## Research & Evidence Policy
- 동작/워크플로우 규칙 개선 시 공식 문서(벤더/플랫폼) 근거를 우선한다.
- 외부 자료를 반영할 때는 적용 이유를 현재 저장소 맥락(`projects/MergeCode`, `tools/controller-f5.ps1`)에 연결해 기록한다.
- 자료 간 충돌 시 저장소의 기존 안전 규칙(운영 민감 로직 보수성, 최소 수정 원칙)을 우선한다.

## Macro.gpl Fast Improvement Workflow
- 사용자가 `Macro.gpl` 중심 개선을 요청하면, 우선 `Macro.gpl` → `Project.gpr` → `Core_ErrorHandler.gpl` 순서로 의존/로깅/실행 맥락을 먼저 확인한다.
- 기본 검증은 정적 오류 확인 중심으로 수행하고, 전체 배포/컴파일/시작은 사용자가 명시적으로 요청할 때만 실행한다.
- 수정 보고는 "변경 지점 / 변경 이유 / 운영 리스크(스레드·삭제·기동)" 3요소를 반드시 포함한다.

## Custom Prompt & Agent Assets
- 반복 작업 패턴은 워크스페이스 자산으로 축적한다.
  - 커스텀 프롬프트: `.github/prompts/*.prompt.md`
  - 커스텀 에이전트: `.github/agents/*.agent.md`
- 프롬프트/에이전트는 단일 책임 원칙으로 작성하고, 설명(description)에 트리거 키워드(예: `Macro.gpl`, `Project.gpr`, `controller-f5`)를 명시한다.
- 새 자산 추가 시 기존 프로젝트 지침과 충돌하지 않도록 최소 규칙만 포함한다.

## Legacy-to-New Transition Policy
- 기능 개선으로 신규 구현이 도입되면, 기존 구현과 혼동되지 않도록 레거시 코드에 경고성 주석(예: LEGACY, 신규 권장 API)을 명시한다.
- 레거시 코드가 아직 참조 중이면 즉시 삭제하지 않고 호환 계층으로 유지하되, 제거 조건(호출부 마이그레이션 완료/검증 완료)을 주석 또는 문서에 남긴다.
- 레거시 코드 참조가 모두 제거된 것이 확인되면, 같은 작업에서 안전 검증 후 레거시 코드를 제거하는 방향을 우선한다.
