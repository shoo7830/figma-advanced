# figma-advanced

## 스킬 웹 배포

`skill.html`에서 설치 대상(`claude`, `agents`, `codex`)과 범위(`global`, `local`)를 선택합니다.
`install-skill.sh`는 `downloads/gabia-figma-extract.tar.gz`를 내려받습니다.
전역은 홈 폴더, 지역은 명령을 실행한 현재 폴더 아래에 설치합니다. 기존 설치는 백업합니다.

원본: https://github.com/shoo7830/figma-extract-preprocess/tree/master/skill/gabia-figma-extract

`skills/gabia-figma-extract/`는 원본 스킬의 웹 배포용 사본입니다.
SKILL.md의 경로 탐색과 설치 안내를 여러 에이전트 및 설치 범위에 맞게 조정했습니다.
실행 스크립트는 원본 그대로입니다. 원본 변경은 자동 반영되지 않습니다.
사본을 수정하면 아래 명령으로 다운로드 묶음도 갱신합니다.

```bash
tar -czf downloads/gabia-figma-extract.tar.gz -C skills gabia-figma-extract
```

설치 명령을 공개하기 전에 이 사이트를 배포해야 합니다.
