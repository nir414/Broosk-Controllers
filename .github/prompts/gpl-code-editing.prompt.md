# GPL_Code Editing Prompt (Korean)

`projects/GPL_Code`의 PA GPL 라이브러리, API, 공통 기반 모듈을 수정할 때 사용하는 전용 지침이다.
트리거 키워드: `GPL_Code`, `Project.gpr`, `Orchestration_Main`, `Observability_Logger`, `GPL 편집`, `PA GPL`, `라이브러리 모듈`, `API 모듈`

## 목표
- `projects/GPL_Code`를 안전하게 수정한다.
- 개별 기능 수정뿐 아니라 라이브러리/API 관점의 재사용성을 유지한다.
- 변경 시 항상 호환성, 확정성, 유연성을 우선한다.

## 기본 원칙
- 이 저장소는 PA GPL 라이브러리, API, 공통 기반 모듈을 개발하는 공간으로 본다.
- 변경은 국소 편의보다 **호환성**, **확정성**, **유연성**, **재사용성**을 우선한다.
- 기존 호출부, 데이터 형식, 제어기 동작을 가능하면 깨지 않도록 유지한다.
- 동작 변경이 불가피하면 래퍼, 호환 계층, 명시적 마이그레이션 경로를 먼저 검토한다.
- 하드코딩은 피하고 런타임 가변 또는 수요 비례 구조를 우선한다.

## 적용 범위
- 기본 작업 대상은 `projects/GPL_Code`이다.
- 기본 베이스 라이브러리 모듈 개발/수정은 반드시 `projects/GPL_Code`에서 진행한다.
- `projects/KDY_Module`은 사용자가 명시적으로 요청한 경우를 제외하고 수정하지 않는다.
- 사용자가 명시하지 않는 한 `docs/`는 분석/수정 대상에서 제외한다.

## 현재 코드 구조
- 현재 진입점은 `projects/GPL_Code/Project.gpr`의 `ProjectStart="ORCH_Main.MAIN"`이다.
- 소스는 `Concurrency_`, `Core_`, `Debug_`, `Format_`, `Foundation_`, `Networking_`, `Observability_`, `Orchestration_`, `Parsing_`, `Persistence_`, `Pipeline_` 같은 기능별 prefix 구조를 따른다.
- 최상위 실행 흐름은 `Orchestration_Main.gpl`에 두고, 재사용 가능한 로직은 기능별 모듈로 분리한다.
- 기존 코드는 `Module` 심볼에 약칭(`ORCH_Main`, `LOG`, `NET`, `APN` 등)을 사용하므로 파일명과 심볼명을 일괄 정규화하려 하지 않는다.

## 편집 규칙
- 기존 스타일을 유지하고, 관련 없는 리포맷·자율 리팩터링은 피한다.
- 사용자가 범위를 지정하면 해당 범위만 최소 변경한다.
- 사용자가 범위를 지정하지 않았을 때 모듈 수정 대상은 `projects/GPL_Code`로 고정한다.
- 작업 전에 수정 파일 경로를 확인하고, `projects/KDY_Module` 경로는 명시 요청 없이는 편집하지 않는다.
- GPL 런타임 특성상 문자열/객체의 `Nothing` 가능성을 항상 고려한다.
- 예외를 임시로 무시해야 하면 이유를 주석으로 남긴다.
- 스레드 제어, 파일 삭제, 기동 로직 같은 운영 민감 코드는 주변 맥락 없이 임의 변경하지 않는다.
- 구조 개선이 필요해도 Helper/Wrapper를 습관적으로 늘리지 말고, 가독성을 먼저 본다.
- 동일 로직이 여러 곳에서 반복되거나 의미 있는 경계가 있을 때만 Helper/Wrapper로 분리한다.
- 필드 반환만 하는 getter, 단순 값 대입만 감싼 setter, 한 번만 호출되는 얇은 helper처럼 읽는 흐름만 끊는 껍데기는 만들지 않거나 가능하면 줄인다.

## 로깅 규칙
- 현재 코드베이스의 기본 로그 API는 `Observability_Logger.gpl`의 `LOG` 모듈(`cehLog`, `cehLogEx`, `cehLogExThrottled`)을 사용한다.
- 로그 `context`는 함수명 수준의 짧은 식별자를 유지한다.
- 로깅 호출은 가능하면 `LOG.cehLog(...)`, `LOG.cehLogEx(...)` 형태로 통일한다.

## Versioning and Project.gpr
- `.gpl` 파일을 수정하면 해당 파일의 `Module` 선언 주석의 patch 버전(Z)을 +1 한다.
- 같은 작업에서 `Project.gpr`의 해당 `ProjectSource` 버전 주석도 함께 갱신한다.
- `ProjectSource` 순서는 의존성 기준으로 유지하고, 현재 `Orchestration_Main.gpl`은 마지막에 둔다.
- `.gpr`에 없는 소스를 참조하지 않도록 유지한다.
- `ProjectName` 대소문자 불일치는 컴파일/시작 실패 원인이 되므로 폴더명과 일치시킨다.

## 빌드, 배포, 디버깅
- 제어기 Stop/Deploy/Compile/Start/Live Log은 기본적으로 `GPL_language` 확장 경로를 우선한다.
- `_debug_cycle.ps1`과 직접 FTP/1402 명령은 확장으로 재현 불가능한 증거 수집이 꼭 필요할 때만 보조로 사용한다.
- 배포 전에는 프로젝트 폴더명(`GPL_Code`)과 `Project.gpr`의 `ProjectName` 일치 여부를 확인한다.
- 사용자가 말하는 "제어기 디버깅"의 기본 의미는 `Stop → GPL_Code 업로드/컴파일 → 실행 → 1403 실시간 로그 수신 → 로그 분석`이다.
- 판정 근거는 확장 Output/Debug Console/DAP 로그를 우선하고, 그다음 1403 Live Log를 본다. `Robot.log`는 기본 판정 근거로 사용하지 않는다.
- 로그 분석 시 `배포/컴파일 단계 오류`, `런타임 쓰레드 오류`, `1403 콘솔/포트 문제`, `제어기 시스템 환경 오류`를 분리한다.
- `-1521` 같은 시스템 오류는 GPL 코드 실패와 분리 해석한다.
- `-782`가 보이면 먼저 오류 쓰레드와 직전 명령을 식별하고, 에러 체인과 초기화 지점을 역추적한다. 정보가 부족하면 쓰레드명/ID, 직전 명령, 스택/프레임, 원문 로그를 요구한다.
- 확장 피드백은 작업자에게 그대로 전달 가능한 문안으로 작성하고, 최소 `재현 절차 / 실행 증거 / 판정 / 원인 후보 / 개선 필요사항(P0~P2)`를 포함한다.

## 문서와 근거
- Brooks GPL/Console/Error Reference/Dictionary 관련 질의는 가능하면 먼저 `gpl-docs` 리소스를 확인한다.
- 로컬 자료와 공식 문서가 충돌하면 `https://www2.brooksautomation.com`를 우선한다.
- 플랫폼 의미 해석이 개입되는 판단은 공식 문서 확인 전 단정하지 않는다.
- GPL 문제를 수정해 동작이 개선되면, 같은 작업에서 직접 관련된 문서만 함께 갱신한다.

## 권장 작업 순서
- 탐색 → 계획 → 수정 → 검증 순서를 기본으로 한다.
- 코드 변경 전 성공 기준을 먼저 정하고 그 기준으로 검증한다.
- 정적 오류 검사는 참고 지표로만 사용하고, 근본 원인 해결을 우선한다.
- 공용 API/라이브러리 모듈 변경 시에는 호출부 파급 영향까지 함께 점검한다.
