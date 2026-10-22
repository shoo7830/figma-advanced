#!/usr/bin/env bash
set -euo pipefail

for command in curl tar python3 node; do
  command -v "$command" >/dev/null 2>&1 || {
    printf '필수 명령어가 없습니다: %s\n' "$command" >&2
    exit 1
  }
done

base_url="${FIGMA_SKILL_BASE_URL:-https://figma-advanced.vercel.app}"
target_agent=claude
scope=global
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

curl --fail --silent --show-error --location \
  "$base_url/downloads/gabia-figma-extract.tar.gz" -o "$staging/skill.tar.gz"
tar -xzf "$staging/skill.tar.gz" -C "$staging"
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
