# Broosk Controllers 프로젝트 규칙

이 문서는 `GPL_Code` 폴더의 GPL 코드 작성/수정 시 지켜야 할 최소 규칙을 정의합니다.

## 1) 진입점(Entry) 규칙
- 실행 시작점은 `Project.gpr`의 `ProjectStart`로 단일 지정한다.
- 현재 시작점은 `Entry_Main.MAIN`이며, 변경 시 반드시 `Project.gpr`를 함께 수정한다.
- `Entry_*` 모듈은 **오케스트레이션(흐름 제어)** 만 담당하고, 공통 로직은 `Core_*`로 이동한다.

## 2) 파일/모듈 네이밍
- 공통 유틸/기반 기능: `Core_*.gpl`
- 엔트리/상위 실행 흐름: `Entry_*.gpl`
- 모듈 선언은 아래 형식을 사용한다.
  - `Module ModuleName ' ModuleFullName VER x.y.z`
  - 예: `Module CEH ' Core_ErrorHandler VER 1.0.0`
- 모듈별 버전은 서로 독립적으로 관리한다. (모듈 단위 버전)
- 파일명과 `Module` 이름은 1:1로 맞춘다. (예: `Core_ErrorHandler.gpl` ↔ `Module CEH`는 예외적 별칭이므로 신규 파일은 가급적 동일 이름 권장)

## 3) Project.gpr 관리
- `ProjectSource` 순서는 의존성 기준으로 유지한다.
  - Core(기반) 먼저
  - Entry(최상위) 마지막
- 모듈 추가/삭제 시 `Project.gpr` 업데이트를 같은 커밋에 포함한다.

## 4) 배포 스크립트 경로/이름 규칙
- 로컬 실행 대상은 `projects` 폴더 하위의 단일 프로젝트 폴더를 사용한다. (기본 루트: `projects`)
- 기본 선택 파라미터는 `-ProjectKey`를 사용한다. (예: `-ProjectKey GPL_Code`)
- `projects` 하위에 폴더가 여러 개면 `-ProjectKey` 지정이 필수다.
- `-LocalProjectDir`는 하위 호환/예외 상황에서만 사용한다. (`-ProjectKey`보다 직접 경로 우선)
- 기본 규칙은 **프로젝트 폴더명 = 프로젝트 식별자**로 통일한다.
  - `ProjectName` 기본값: 프로젝트 폴더명
  - `FtpProjectDir` 기본값: `/GPL/<프로젝트 폴더명>`
  - `LoadPath` 기본값: `FtpProjectDir`
- `Project.gpr`의 `ProjectName`도 프로젝트 폴더명과 동일하게 유지한다.
- 컴파일 명령은 프로젝트 폴더명 기준을 우선 사용하고, 필요 시 파라미터로 override 한다.
- 특정 장비/환경에서 이름이 다르면 스크립트 파라미터로 명시 override 한다.

## 5) 로깅 규칙
- 로그 출력은 `CEH` 경유를 기본으로 한다.
- 일반 로그: `cehLog(msg, context)`
- 예외 로그: `cehLogEx(ex, context)`
- `context`는 함수명만 적는 형태를 권장한다. (예: `FunctionName`)

## 6) 예외/에러 처리
- 사용자 정의 에러는 `CEH.cehThrow(...)`, `CEH.cehThrowRobot(...)` 사용을 우선한다.
- `Catch` 블록에서 무시가 필요한 경우, 이유를 주석으로 남긴다.

## 7) 함수 작성 규칙
- 공개 API(`Public Sub/Function`)는 의도가 드러나는 이름 사용.
- 수학/기하 계산 함수는 입력 좌표계(XY/XYZ)와 단위를 주석에 명시한다.
- 동일 파일 내 helper 함수는 한 가지 책임만 갖도록 분리한다.
- `Function`의 반환값은 **함수명 대입(`FunctionName = ...`)을 기본으로 사용**한다.
  - 목적: 다른 언어의 `return` 관성과 혼동을 줄이고, GPL 관례를 일관되게 유지한다.
  - `Return ...`은 조기 종료가 필요한 흐름 제어 상황에서만 예외적으로 사용한다.

## 8) 선언문(Declaration) 통일화 규칙
- 근거 문서
  - [Dim Statement](https://www2.brooksautomation.com/#Controller_Software/Software_Reference/GPL_Dictionary/Statement_Dictionary/Dim.htm)
  - [Statements Summary](https://www2.brooksautomation.com/#Controller_Software/Software_Reference/GPL_Dictionary/Statement_Dictionary/statementintro.htm)
  - [Const Statement](https://www2.brooksautomation.com/Controller_Software/Software_Reference/GPL_Dictionary/Statement_Dictionary/Const.htm)
  - [ReDim Statement](https://www2.brooksautomation.com/Controller_Software/Software_Reference/GPL_Dictionary/Statement_Dictionary/redim.htm)
  - [Module Statement](https://www2.brooksautomation.com/Controller_Software/Software_Reference/GPL_Dictionary/Statement_Dictionary/Module.htm)
- 선언 위치
  - 변수/상수/프로시저 선언은 반드시 `Module` 또는 `Class` 내부에 둔다.
  - `Dim`/`Const`는 클래스, 프로시저, 모듈 내부에서만 선언한다.
- `Dim` 통일 규칙
  - 기본 형식은 `Dim name As Type`를 사용한다. (`As Type` 생략 금지)
  - 프로시저 내부에서는 `Public`/`Private`를 사용하지 않는다.
  - 모듈 레벨 변수는 암묵적으로 공유되므로 `Shared`를 쓰지 않는다.
  - 배열 선언은 `name(dim1[, dim2 ...]) As Type` 형식을 사용하고, 최대 4차원까지만 허용한다.
  - 한 줄 다중 선언이 가능하더라도 가독성을 위해 **변수 1개당 1선언문**을 권장한다.
- `Const` 통일 규칙
  - `Const`는 읽기 전용 상수에만 사용한다.
  - 한 `Const` 선언문에는 변수 1개만 선언한다.
  - 초기값은 상수식(리터럴, 다른 `Const`, 내장 시스템 함수 조합)만 허용한다.
- `ReDim` 통일 규칙
  - 배열 크기 변경은 `ReDim`으로만 수행한다.
  - `ReDim`은 원래 선언과 동일 차원 수를 유지해야 한다.
  - `ReDim Preserve`는 마지막 차원(우측 차원)만 변경한다.
- 객체 선언 권장
  - 객체 변수는 의도를 명확히 하기 위해 `Dim obj As New ClassName` 또는 `Dim obj As ClassName` 후 별도 할당 중 하나로 팀 내에서 일관되게 사용한다.
  - 본 프로젝트 신규 코드는 **선언 시점 명시형(`As New`)** 을 기본 권장으로 한다.

## 9) 코드 리뷰 체크리스트
- [ ] `Project.gpr`의 시작점/소스 순서가 맞는가?
- [ ] 신규 코드가 `Entry`와 `Core` 역할 분리에 맞는가?
- [ ] 로그/예외 처리가 `CEH` 경유로 일관적인가?
- [ ] 하드코딩 경로/매직넘버에 설명이 있는가?
- [ ] `Dim/Const/ReDim` 선언이 본 문서의 선언문 통일화 규칙을 따르는가?

## 10) 점진 개선 권장사항(기존 코드 호환 유지)
- 기존 `CEH.log(...)` 호출은 동작 확인 후 `cehLog(..., context)`로 점진 치환한다.
- 네이밍/주석 규칙은 신규 코드부터 우선 적용하고 기존 코드는 변경 시 함께 정리한다.
