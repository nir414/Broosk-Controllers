# Project Guidelines

## Scope
- 기본 작업 대상은 `projects/GPL_Code`이다.
- 사용자가 명시하지 않는 한 `docs/`는 분석/수정 대상에서 제외한다.

## Quick Links (Link, don't duplicate)
- GPL 전용 편집 지침: [`/.github/prompts/gpl-code-editing.prompt.md`](./prompts/gpl-code-editing.prompt.md)
- GPL 코딩 표준: [`/projects/GPL_Code/GPL_Code_코딩표준.md`](../projects/GPL_Code/GPL_Code_코딩표준.md)
- 소스 등록/의존 순서: [`/projects/GPL_Code/Project.gpr`](../projects/GPL_Code/Project.gpr)
- 디버거 동작 기준: [`/.vscode/launch.json`](../.vscode/launch.json), [`/.vscode/settings.json`](../.vscode/settings.json)
- 멀티 에이전트 오케스트레이션 템플릿: [`/.github/prompts/meta-orchestrator.prompt.md`](./prompts/meta-orchestrator.prompt.md)

## Current Customization Baseline
- 현재 저장소는 `AGENTS.md`보다 `copilot-instructions.md` + `.github/prompts/*.prompt.md` 중심으로 운영한다.
- 새 규칙을 만들 때는 먼저 기존 prompt/instructions를 갱신하고, 반복 워크플로우가 커질 때만 `.github/agents/*.agent.md`를 추가한다.

## Response
- 답변 첫 1~3줄에 핵심 결론을 먼저 제시한다.
- 기본 답변은 간결하게 작성하고, 분석/비교/추천/판단에는 근거·대안과 `Confidence: NN%`를 포함한다.
- 내부 독백은 노출하지 않고 검증 가능한 요약 근거만 제시한다.
- 정보가 부족하면 추측하지 말고 핵심 질문만 최대 3개 한다.
- 사용자가 요청한 형식·길이·말투·코드 스타일을 우선한다.
- 오류 지적이나 재검토 요청이 있으면 먼저 수정 결론을 제시한 뒤 이유를 짧게 설명한다.
- 수식 표기는 필요한 경우에만 사용하고 `*`, `/`, `^` 표기를 따른다.

## Persistent Requests
- 사용자가 "영구", "항상", "기본으로", "앞으로도" 같은 지속 반영을 요청하면, 먼저 반영 초안을 제시하고 확인 후 적용한다.
- 기존 규칙과 충돌하면 최소 수정으로 조정한다.
- 저장소 전역 규칙이 아닌 사용자 선호는 사용자 메모리에도 반영한다.

## GPL Project Editing Guidance
- `projects/GPL_Code`는 제대로 된 재사용 가능한 라이브러리의 기반 틀을 만드는 작업으로 본다. 구조 결정은 줄 수나 호출부 변경 회피가 아니라 재사용·결합 경계 기준으로 한다.
- `projects/GPL_Code` 편집 규칙은 `.github/prompts/gpl-code-editing.prompt.md`를 기준으로 따른다.
- GPL 라이브러리/API 모듈 작업에서는 호환성, 확정성, 유연성, 재사용성을 우선한다.
- `projects/KDY_Module`은 사용자가 명시적으로 요청한 경우를 제외하고 수정하지 않는다.

## Execution/Debug Entry Points
- 기본 실행 경로는 VS Code 디버그 설정 `GPL: F5 Upload + Attach`를 우선한다.
- 제어기 디버깅 기본 의미는 `Stop → GPL_Code 업로드/컴파일 → 실행 → 1403 실시간 로그 수신 → 로그 분석`이다.
- 1403 로그/Output/Debug Console/DAP를 판정 근거로 우선 사용하고, `Robot.log`는 기본 판정 근거로 사용하지 않는다.

## Working Style
- 비자명한 작업은 `탐색 → 계획 → 수정 → 검증` 순서를 기본으로 한다.
- 코드 변경 전 성공 기준을 먼저 정하고 그 기준으로 검증한다.
- 정적 오류 검사는 참고 지표로만 사용하고, 근본 원인 해결을 우선한다.
- 대량 삭제, 강제 리셋/푸시, 외부 시스템 변경 같은 파괴적 작업은 사용자 승인 없이 수행하지 않는다.

## Prompt and Legacy Assets
- 반복 작업 패턴은 `.github/prompts/*.prompt.md`, `.github/agents/*.agent.md`로 축적한다.
- `projects/GPL_Code` 전용 편집 지침은 `.github/prompts/gpl-code-editing.prompt.md`에 유지한다.
- 프롬프트/에이전트 `description`에는 실제 트리거 키워드를 포함한다.
- 신규 구현을 도입하면 레거시 코드에 경고성 주석을 남기고, 참조 제거와 검증이 끝난 뒤 제거한다.
