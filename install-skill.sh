#!/usr/bin/env bash
set -euo pipefail

for command in curl tar python3 node; do
  command -v "$command" >/dev/null 2>&1 || {
    printf '필수 명령어가 없습니다: %s\n' "$command" >&2
    exit 1
  }
done

base_url="${FIGMA_SKILL_BASE_URL:-https://figma-advanced.vercel.app}"
target_agent=
scope=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target|--scope)
      [ "$#" -ge 2 ] || { printf '옵션 값이 필요합니다: %s\n' "$1" >&2; exit 1; }
      case "$1" in
        --target) target_agent="$2" ;;
        --scope) scope="$2" ;;
      esac
      shift 2 ;;
    *) printf '사용법: bash install-skill.sh [--target claude|agents|codex] [--scope global|local]\n' >&2; exit 1 ;;
  esac
done
if [ -z "$target_agent" ] || [ -z "$scope" ]; then
  if ! [ -t 0 ]; then
    printf '터미널에서 실행하거나 --target 및 --scope 옵션을 지정하세요.\n' >&2
    exit 1
  fi
  if [ -z "$target_agent" ]; then
    printf '설치 대상: 1) Claude Code (.claude)  2) 공용/Codex (.agents, 권장)  3) .codex\n'
    read -r -p '선택 [1-3]: ' selection
    case "$selection" in
      1) target_agent=claude ;;
      2) target_agent=agents ;;
      3) target_agent=codex ;;
      *) printf '잘못된 선택입니다.\n' >&2; exit 1 ;;
    esac
  fi
  if [ -z "$scope" ]; then
    printf '설치 범위: 1) 전역 (홈 폴더)  2) 프로젝트 (현재 폴더: %s)\n' "$PWD"
    read -r -p '선택 [1-2]: ' selection
    case "$selection" in
      1) scope=global ;;
      2) scope=local ;;
      *) printf '잘못된 선택입니다.\n' >&2; exit 1 ;;
    esac
  fi
fi
case "$target_agent" in
  claude|agents|codex) ;;
  *) printf '지원하지 않는 대상: %s\n' "$target_agent" >&2; exit 1 ;;
esac
case "$scope" in
  global) install_root="$HOME" ;;
  local) install_root="$PWD" ;;
  *) printf '지원하지 않는 범위: %s\n' "$scope" >&2; exit 1 ;;
esac
skills_dir="$install_root/.$target_agent/skills"
target="$skills_dir/gabia-figma-extract"
mkdir -p "$skills_dir"
staging=$(mktemp -d "$skills_dir/.gabia-figma-extract.XXXXXX")
trap 'rm -rf "$staging"' EXIT

case "$base_url" in
  https://*) ;;
  *) printf '다운로드 주소는 HTTPS여야 합니다.\n' >&2; exit 1 ;;
esac
curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
  --connect-timeout 15 --max-time 120 --max-filesize 10485760 \
  "$base_url/downloads/gabia-figma-extract.tar.gz" -o "$staging/skill.tar.gz"
python3 - "$staging" <<'PY'
import sys
import tarfile
from pathlib import Path

root = Path(sys.argv[1])
files = {
    'gabia-figma-extract/SKILL.md',
    'gabia-figma-extract/scripts/figma_extract.py',
    'gabia-figma-extract/scripts/parse_figma.mjs',
}
directories = {'gabia-figma-extract', 'gabia-figma-extract/scripts'}
with tarfile.open(root / 'skill.tar.gz', 'r:gz') as archive:
    seen = set()
    total = 0
    members = []
    for member in archive:
        if member.isdir() and member.name in directories:
            continue
        if member.name not in files or not member.isfile() or member.name in seen:
            raise SystemExit('허용되지 않은 압축 항목: ' + member.name)
        seen.add(member.name)
        total += member.size
        if member.size < 0 or total > 10 * 1024 * 1024:
            raise SystemExit('압축 해제 크기 제한 초과')
        members.append(member)
    if seen != files:
        raise SystemExit('설치 파일 누락')
    for member in members:
        destination = root / member.name
        destination.parent.mkdir(parents=True, exist_ok=True)
        with archive.extractfile(member) as source, destination.open('xb') as output:
            output.write(source.read())
        destination.chmod(0o600)
PY
for file in SKILL.md scripts/figma_extract.py scripts/parse_figma.mjs; do
  test -s "$staging/gabia-figma-extract/$file" || {
    printf '설치 파일이 누락되었습니다: %s\n' "$file" >&2
    exit 1
  }
done

if [ -e "$target" ] || [ -L "$target" ]; then
  backup=$(mktemp -d "$skills_dir/gabia-figma-extract.backup.XXXXXX")
  mv "$target" "$backup/"
  printf '기존 스킬 백업: %s\n' "$backup"
fi
mv "$staging/gabia-figma-extract" "$target"
printf '설치 완료: %s\n대상: %s / 범위: %s\n사용 중인 에이전트를 다시 시작하고 gabia-figma-extract 스킬을 호출하세요.\n' "$target" "$target_agent" "$scope"
