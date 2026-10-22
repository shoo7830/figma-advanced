---
name: gabia-figma-extract
description: PC/TB/MB Figma 시안 URL을 대화형으로 입력받아 figma_extract.py로 raw JSON + 이미지를 추출하고, parse_figma.mjs로 섹션별 파싱까지 자동 완료하는 스킬. "피그마 추출", "figma extract", "피그마 시안 가져와", "/gabia-figma-extract" 등의 요청 시 사용.
---

# Gabia Figma Extract

PC/TB/MB Figma 시안에서 raw JSON과 이미지 에셋을 추출하고, 섹션별 파싱까지 한 번에 완료합니다.
어느 디렉토리에서 호출해도 동작합니다.

## 워크플로우

```
1. 스크립트 경로 확인
2. FIGMA_TOKEN 환경변수 존재 확인
3. 폴더명 입력 (필수, 중복 경고 포함)
4. PC / TB / MB URL 입력 (각각 필수)
5. 이미지 모음 프레임 URL 입력 (선택)
6. 실행 전 요약 확인
7. figma_extract.py 실행
8. raw JSON 생성 확인
9. parse_figma.mjs 실행
10. 완료 메시지 출력
```

---

## Phase 1: 스크립트 경로 확인

현재 로드한 이 SKILL.md의 실제 경로를 기준으로 스크립트를 찾는다.
설치 위치를 ~/.claude로 고정하지 않는다. 전역 설치는 홈 폴더 아래,
프로젝트 설치는 프로젝트 폴더 아래의 .agents/skills, .codex/skills 또는 .claude/skills에 있을 수 있다.
여러 사본이 있으면 현재 로드된 스킬의 경로를 사용하고, 임의로 다른 사본을 선택하지 않는다.

`SKILL_DIR`은 이 문서가 위치한 디렉토리, `SCRIPTS_DIR`은 `$SKILL_DIR/scripts`이다.
심링크라면 Python 3의 `pathlib.Path(...).resolve()`로 실제 경로를 확인한다.
두 스크립트가 존재하는지 확인한 후 진행한다.

이후 모든 스크립트 호출은 `$SCRIPTS_DIR` 절대 경로를 사용한다.
CWD는 사용자의 현재 작업 디렉토리 그대로 유지한다.

---

## Phase 2: FIGMA_TOKEN 확인

현재 실행 환경의 `FIGMA_TOKEN` 존재 여부만 확인한다. 값을 출력하거나 로그에 남기지 않는다.
없으면 사용자가 로컬 터미널 또는 비밀 관리 도구에서 환경변수를 설정하도록 안내한다.
토큰을 채팅으로 요청하거나 셸 명령에 실제 값을 삽입하지 않는다.
`.zshrc` 등 설정 파일을 읽어 토큰 값을 도구 출력으로 노출하지 않는다.
인증서 검증은 항상 유지한다. 사내 CA가 필요하면 `SSL_CERT_FILE`로 신뢰할 CA 파일을 지정한다.

---

## Phase 3: 폴더명 입력

사용자에게 출력 폴더명을 묻는다.

> 출력 폴더명을 입력해주세요. (예: figma, vessl, my-project)

- 기본값 없음 — 빈 값이면 다시 묻는다.
- 폴더명에 공백, `/`, `\` 등 특수문자가 포함되면 경고 후 다시 묻는다:
  > 폴더명에 공백이나 특수문자는 사용할 수 없습니다. 다시 입력해주세요.
- 입력값을 `FOLDER` 변수로 저장한다.

**폴더 중복 확인:**

```bash
test -d "./<FOLDER>"
```

이미 존재하면:

> `./<FOLDER>` 폴더가 이미 존재합니다. 계속하면 기존 파일이 덮어씌워질 수 있습니다.
> 계속하시겠습니까? (y/n)

- `y`: 계속 진행
- `n` 또는 기타: 종료

---

## Phase 4: PC / TB / MB URL 입력

아래 순서로 각각 프롬프트한다:

> PC 시안 URL을 입력해주세요.
> (예: https://www.figma.com/design/ABC123/MyFile?node-id=1-23)

> TB 시안 URL을 입력해주세요.

> MB 시안 URL을 입력해주세요.

**3개 중 하나라도 빈 값이면:**

> PC/TB/MB URL은 모두 필수입니다. 입력되지 않은 항목이 있어 실행을 중단합니다.

출력 후 종료한다.

---

## Phase 5: 이미지 모음 프레임 URL 입력 (선택)

> 이미지 모음 프레임 URL이 있으면 입력해주세요. (없으면 엔터)

- 입력하면 `IMAGE_NODE` 변수로 저장하고 `--image-node` 인자에 추가한다.
- 빈 값이면 `--image-node` 인자를 생략한다.

---

## Phase 6: 실행 전 요약 확인

수집한 값을 요약해 보여주고 확인을 받는다:

```
─────────────────────────────────────
실행 전 확인
─────────────────────────────────────
출력 폴더  : ./<FOLDER>
PC URL     : <PC_URL>
TB URL     : <TB_URL>
MB URL     : <MB_URL>
이미지 프레임: <IMAGE_NODE | "없음">
스크립트   : <SCRIPTS_DIR>
─────────────────────────────────────
위 내용으로 실행하시겠습니까? (y/n)
```

- `y`: Phase 7로 진행
- `n` 또는 기타: "실행을 취소했습니다." 출력 후 종료

---

## Phase 7: figma_extract.py 실행

```bash
python3 "$SCRIPTS_DIR/figma_extract.py" \
  --url "<PC_URL>" \
  --url "<TB_URL>" \
  --url "<MB_URL>" \
  [--image-node "<IMAGE_NODE>"] \
  --types raw,images \
  --output ./<FOLDER>
```

- `--image-node` 인자는 Phase 5에서 값을 입력했을 때만 추가한다.
- 실행 중 오류가 발생하면 에러 메시지를 그대로 출력하고 Phase 8로 넘어가지 않고 종료한다.

---

## Phase 8: raw JSON 생성 확인

```bash
ls ./<FOLDER>/*_raw.json 2>/dev/null
```

파일이 하나도 없으면:

> figma_extract.py가 raw JSON을 생성하지 못했습니다. 위 에러를 확인해주세요.
> (주요 원인: 토큰 만료 / node-id 오류 / 네트워크 오류)

출력 후 종료한다. 파일이 존재하면 Phase 9로 진행한다.

---

## Phase 9: parse_figma.mjs 실행

```bash
node "$SCRIPTS_DIR/parse_figma.mjs" --dir ./<FOLDER> --out ./<FOLDER>/parsed
```

- 실행 중 오류가 발생하면 에러 메시지를 그대로 출력하고 중단한다.

---

## Phase 10: 완료 메시지 출력

```
완료되었습니다.

출력 구조:
  ./<FOLDER>/
  ├── *_raw.json          ← PC/TB/MB raw JSON
  ├── images/             ← 이미지 에셋 (--image-node 사용 시)
  └── parsed/
      ├── pc_index.md     ← Claude에 @참조로 전달
      ├── tb_index.md
      ├── mb_index.md
      └── *.json / *.spec.txt

다음 단계:
  @<FOLDER>/parsed/pc_index.md 등을 참조해 반응형 구현을 요청하세요.
  예: "세 시안을 반응형으로 구현해줘."
```

---

## 출력 구조 참고

```
{folder}/
├── pc_raw.json
├── tb_raw.json
├── mb_raw.json
├── images/              ← --image-node 사용 시
└── parsed/
    ├── pc_index.md
    ├── tb_index.md
    ├── mb_index.md
    ├── pc_Intro.json + .spec.txt
    └── ...
```

---

## 실제 커맨드 예시 (VESSL-AI 프로젝트)

```bash
FIGMA_TOKEN="figd_xxxx" python3 /path/to/skill/scripts/figma_extract.py \
  --url "https://www.figma.com/design/ilCLRjyByTdXm5GOMtVXGN/VESSL-AI?node-id=301-1658" \
  --url "https://www.figma.com/design/ilCLRjyByTdXm5GOMtVXGN/VESSL-AI?node-id=195-1374" \
  --url "https://www.figma.com/design/ilCLRjyByTdXm5GOMtVXGN/VESSL-AI?node-id=195-1373" \
  --types raw,images \
  --output ./figma

node /path/to/skill/scripts/parse_figma.mjs --dir ./figma --out ./figma/parsed
```

---

## 설치

웹사이트 설치 스크립트는 `--target claude|agents|codex`와 `--scope global|local`을 지원한다.
전역은 홈 폴더, 프로젝트 설치는 명령어를 실행한 현재 폴더에 설치한다.
스킬 문서와 scripts 폴더는 항상 함께 유지한다.
Claude Code에서는 `/gabia-figma-extract`, Codex에서는 `$gabia-figma-extract`로 호출한다.
설치 경로의 자동 인식 여부는 사용하는 에이전트의 설정을 따른다.
