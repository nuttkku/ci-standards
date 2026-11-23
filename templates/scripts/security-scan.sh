#!/usr/bin/env bash
# security-scan.sh — สแกนความปลอดภัยบนเครื่องด้วย Docker (nuttkku/ci-standards v2)
#
#   bash scripts/security-scan.sh [secrets|sast|container|dast|all]...   (ไม่ใส่ = all)
#
#   secrets    gitleaks ทั้ง history (อ่าน .gitleaks.toml / .gitleaksignore ที่ราก repo เอง)
#   sast       Semgrep (ค่าเริ่มต้น) หรือ Snyk Code ถ้า SAST=snyk และมี SNYK_TOKEN
#   container  build image ตาม IMAGES แล้วสแกนด้วย Trivy (image + config)
#   dast       OWASP ZAP baseline ไปที่ ZAP_TARGET — ต้องเปิดสแต็กไว้ก่อน (เช่น docker compose up -d)
#   all        secrets + sast + container (+ dast ถ้าตั้ง ZAP_TARGET)
#
# ค่าของแต่ละ repo อยู่ใน .security-scan.conf ที่ราก repo · ผลอยู่ใน security-reports/ (อยู่ใน .gitignore)
# ใช้ได้บน Linux, macOS และ Windows (Git Bash / WSL) — ต้องมี Docker เท่านั้น
# ต้นฉบับ: https://github.com/nuttkku/ci-standards/blob/main/templates/scripts/security-scan.sh — แก้ที่ต้นฉบับก่อน
set -uo pipefail

# --- เวอร์ชันเครื่องมือ (ปักไว้ — อัปเดตที่ต้นฉบับ) -----------------------------------------
GITLEAKS_IMAGE=zricethezav/gitleaks:v8.30.1
SEMGREP_IMAGE=semgrep/semgrep:1.186.0
TRIVY_IMAGE=aquasec/trivy:0.76.2
ZAP_IMAGE=zaproxy/zap-stable:2.17.0
SNYK_IMAGE=snyk/snyk:linux@sha256:b58d519288c5f0848deeb93074fe6492f1ee0a47575e14182a8385c046704426  # CLI 1.1309.0

# --- ค่าเริ่มต้น (override ใน .security-scan.conf หรือ env ตอนรัน — env ชนะ) ----------------------
ENV_VARS=(SAST SAST_FAIL ZAP_TARGET ZAP_NETWORK ZAP_RULES ZAP_FAIL TRIVY_IGNOREFILE)
ENV_OVERRIDES=()
for v in "${ENV_VARS[@]}"; do [ -n "${!v+x}" ] && ENV_OVERRIDES+=("$v=${!v}"); done
# IMAGES: หนึ่งบรรทัดต่อ image — "ชื่อ|build context|target (เว้นได้)|trivy skip-dirs|trivy skip-files|ignorefile"
IMAGES=()
TRIVY_CONFIG_PATHS=(.)          # โฟลเดอร์ที่ตรวจ Dockerfile / compose (trivy config)
TRIVY_IGNOREFILE=""             # ว่าง = ใช้ .trivyignore.yaml หรือ .trivyignore ที่ราก ถ้ามี
SAST=semgrep                    # semgrep | snyk
SAST_FAIL=1                     # 0 = รายงานอย่างเดียว (ต้องเขียนเหตุผลไว้ใน CI-CD.md)
SEMGREP_CONFIGS=(p/security-audit p/secrets p/javascript p/typescript p/nodejsscan)
SEMGREP_EXCLUDES=(node_modules dist build .svelte-kit security-reports '*.md')
ZAP_TARGET=""                   # เช่น http://localhost:8080 — localhost จะถูกแปลงเป็น host.docker.internal ให้
ZAP_NETWORK=""                  # หรือใส่ชื่อ docker network ของ compose แล้วใช้ชื่อ service ใน ZAP_TARGET
ZAP_RULES=""                    # เช่น .zap/rules.tsv (finding ที่ยอมรับพร้อมเหตุผล)
ZAP_FAIL=1                      # 0 = รายงานอย่างเดียว

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "ต้องรันในโฟลเดอร์ของ git repo" >&2; exit 2; }
cd "$ROOT" || exit 2
[ -f .security-scan.conf ] && . <(tr -d '\r' < .security-scan.conf)  # ทนไฟล์ที่ Windows แปลงเป็น CRLF
for kv in "${ENV_OVERRIDES[@]}"; do declare "$kv"; done

REPORTS="$ROOT/security-reports"
mkdir -p "$REPORTS"

# Git Bash: ห้ามแปลง path ที่ส่งให้ docker และใช้ path แบบ Windows ตอน mount
export MSYS_NO_PATHCONV=1
HOST_ROOT=$ROOT
if pwd -W >/dev/null 2>&1; then HOST_ROOT=$(pwd -W); fi
HOST_REPORTS="$HOST_ROOT/security-reports"

declare -A RESULT=()
FAILED=0
say() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
mark() { # mark <step> <exit code> [fail-on-findings]
  # exit 1 = พบ finding · ≥2 = เครื่องมือทำงานไม่สำเร็จ (Snyk/Semgrep/ZAP) — report-only ต้องไม่กลบ error
  if [ "$2" -eq 0 ]; then RESULT[$1]=PASS
  elif [ "$2" -eq 1 ] && [ "${3:-1}" -eq 0 ]; then RESULT[$1]="FINDINGS (report-only)"
  elif [ "$2" -eq 1 ]; then RESULT[$1]=FAIL; FAILED=1
  else RESULT[$1]="ERROR (exit $2) — ดู log ด้านบน"; FAILED=1; fi
}

run_secrets() {
  say "secrets — gitleaks ทั้ง history"
  docker run --rm -v "$HOST_ROOT:/repo" "$GITLEAKS_IMAGE" \
    git /repo --redact --no-banner -v \
    --report-format json --report-path /repo/security-reports/gitleaks.json
  mark secrets $?
}

run_sast() {
  if [ "$SAST" = snyk ]; then
    say "sast — Snyk Code"
    # ใช้ SNYK_TOKEN ถ้ามี ไม่งั้นใช้ credential ของ `snyk auth` ที่เคย login ไว้บนเครื่อง
    local auth=() store="$HOME/.config/configstore"
    if [ -n "${SNYK_TOKEN:-}" ]; then auth=(-e SNYK_TOKEN)
    elif [ -f "$store/snyk.json" ]; then
      pwd -W >/dev/null 2>&1 && store=$(cd "$store" && pwd -W)
      auth=(-v "$store:/root/.config/configstore")
    else
      echo "ต้อง login Snyk ก่อน (snyk auth หรือ export SNYK_TOKEN=...) หรือใช้ SAST=semgrep" >&2; mark sast 1; return
    fi
    docker run --rm "${auth[@]}" -v "$HOST_ROOT:/project" -w /project "$SNYK_IMAGE" \
      snyk code test --severity-threshold=high --sarif-file-output=security-reports/snyk-code.sarif
    mark sast $? "$SAST_FAIL"
  else
    say "sast — Semgrep (${SEMGREP_CONFIGS[*]})"
    local args=()
    for c in "${SEMGREP_CONFIGS[@]}"; do args+=(--config "$c"); done
    for e in "${SEMGREP_EXCLUDES[@]}"; do args+=(--exclude "$e"); done
    docker run --rm -v "$HOST_ROOT:/src" -w /src "$SEMGREP_IMAGE" \
      semgrep scan "${args[@]}" --severity WARNING --severity ERROR --metrics=off --error \
      --sarif-output=security-reports/semgrep.sarif .
    mark sast $? "$SAST_FAIL"
  fi
}

trivy() { # รัน trivy ใน container โดยใช้ docker daemon ของเครื่อง + cache ข้ามรอบ
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
    -v "$HOST_ROOT:/src" -w /src "$TRIVY_IMAGE" "$@"
}

run_container() {
  local ignore=$TRIVY_IGNOREFILE rc=0
  if [ -z "$ignore" ]; then
    for f in .trivyignore.yaml .trivyignore; do [ -f "$f" ] && { ignore=$f; break; }; done
  fi
  if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "ไม่ได้ตั้ง IMAGES ใน .security-scan.conf — ข้าม Trivy image"
  fi
  local line name ctx target skip_dirs skip_files img_ignore
  for line in "${IMAGES[@]}"; do
    IFS='|' read -r name ctx target skip_dirs skip_files img_ignore <<<"$line"
    say "container — build + Trivy image: $name"
    # --pull: ดึง base image ล่าสุดทุกครั้ง เพื่อเจอ CVE ใหม่ของ OS package
    docker build --pull ${target:+--target "$target"} -t "security-scan/$name:local" "$ctx" || { mark "image:$name" 1; rc=1; continue; }
    local args=(image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --scanners vuln)
    [ -n "$skip_dirs" ] && args+=(--skip-dirs "$skip_dirs")
    [ -n "$skip_files" ] && args+=(--skip-files "$skip_files")
    [ -n "${img_ignore:-$ignore}" ] && args+=(--ignorefile "${img_ignore:-$ignore}")
    trivy "${args[@]}" "security-scan/$name:local"
    mark "image:$name" $?
  done
  local p
  for p in "${TRIVY_CONFIG_PATHS[@]}"; do
    say "container — Trivy config: $p"
    local args=(config --severity HIGH,CRITICAL --exit-code 1)
    [ -n "$ignore" ] && args+=(--ignorefile "$ignore")
    trivy "${args[@]}" "$p"
    mark "config:$p" $?
  done
}

run_dast() {
  if [ -z "$ZAP_TARGET" ]; then
    echo "ไม่ได้ตั้ง ZAP_TARGET — ข้าม DAST"; return
  fi
  local target=$ZAP_TARGET net=()
  if [ -n "$ZAP_NETWORK" ]; then
    net=(--network "$ZAP_NETWORK")
  else
    target=$(printf '%s' "$target" | sed -E 's#//(localhost|127\.0\.0\.1)([:/]|$)#//host.docker.internal\2#')
    net=(--add-host host.docker.internal:host-gateway)
  fi
  say "dast — ZAP baseline: $target"
  chmod 777 "$REPORTS" 2>/dev/null  # ZAP รันเป็น uid 1000
  local args=(-t "$target" -r zap-baseline.html -J zap-baseline.json -I)
  if [ -n "$ZAP_RULES" ]; then cp "$ZAP_RULES" "$REPORTS/zap-rules.tsv" && args+=(-c zap-rules.tsv); fi
  docker run --rm "${net[@]}" -v "$HOST_REPORTS:/zap/wrk:rw" "$ZAP_IMAGE" zap-baseline.py "${args[@]}"
  mark dast $? "$ZAP_FAIL"
}

steps=("$@")
[ ${#steps[@]} -eq 0 ] && steps=(all)
for s in "${steps[@]}"; do
  case $s in
    secrets) run_secrets ;;
    sast) run_sast ;;
    container) run_container ;;
    dast) run_dast ;;
    all) run_secrets; run_sast; run_container; [ -n "$ZAP_TARGET" ] && run_dast ;;
    *) echo "ไม่รู้จัก: $s (ใช้ secrets|sast|container|dast|all)" >&2; exit 2 ;;
  esac
done

say "สรุป ($(date '+%Y-%m-%d %H:%M'), $(git rev-parse --short HEAD))"
for k in "${!RESULT[@]}"; do printf '  %-28s %s\n' "$k" "${RESULT[$k]}"; done | sort
echo "  รายงาน: security-reports/"
exit $FAILED
