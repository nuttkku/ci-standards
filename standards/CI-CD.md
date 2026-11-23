# มาตรฐาน CI/CD — nuttkku (v2.0, 2026-11-23)

ไฟล์ต้นฉบับอยู่ที่ `nuttkku/ci-standards/standards/CI-CD.md` (repo public) — แต่ละ repo มี `CI-CD.md` ย่อ + หัวข้อ "เฉพาะ repo นี้"
ถ้าจะเปลี่ยนมาตรฐาน แก้ที่ต้นฉบับก่อน แล้วค่อยอัปเดตสำเนา

## หลักการ
1. **GitHub Actions ทำแค่งานเร็ว** — lint / typecheck / test + หา secret ใน commit ใหม่ (PR ได้ผล ≤ 5 นาที)
2. **สแกนความปลอดภัยหนักทั้งหมดรันบนเครื่องด้วย Docker** — container (Trivy), โค้ด (Semgrep หรือ Snyk Code), DAST (OWASP ZAP)
   ผ่านสคริปต์เดียว `scripts/security-scan.sh` — ไม่กินนาที Actions, ใช้ได้กับระบบที่อยู่ในเครือข่ายภายใน, เห็นผลเต็มทันที
3. **Dependency = Dependabot ของ GitHub** อย่างเดียว
4. **เครื่องมือเดียวต่อหนึ่งหน้าที่** — ทุก repo ใช้ชุดเดียวกัน
5. Actions ของ repo private รวมกัน **≤ ~1,000 นาที/เดือน** (โควตา GitHub Pro 3,000)

## เครื่องมือมาตรฐาน
| หน้าที่ | ใช้ | รันที่ | รันเมื่อ |
|---|---|---|---|
| คุณภาพโค้ด | lint / typecheck / unit test ของ repo เอง | GitHub Actions `ci.yml` | ทุก PR + push `main` |
| หา secret (commit ใหม่) | **gitleaks-action** | GitHub Actions `ci.yml` | ทุก PR + push `main` |
| หา secret (ทั้ง history) | **gitleaks** `zricethezav/gitleaks` | เครื่อง — `security-scan.sh secrets` | ก่อน deploy + รายสัปดาห์ |
| SAST | **Semgrep** `semgrep/semgrep` หรือ **Snyk Code** `snyk/snyk` (เลือก 1 ต่อ repo) | เครื่อง — `security-scan.sh sast` | ก่อน deploy + รายสัปดาห์ |
| Container / Dockerfile | **Trivy** `aquasec/trivy` (image + config) | เครื่อง — `security-scan.sh container` | ก่อน deploy + รายสัปดาห์ |
| DAST | **OWASP ZAP baseline** `zaproxy/zap-stable` | เครื่อง — `security-scan.sh dast` (สแต็กที่เปิดในเครื่อง) | ก่อน deploy ที่แตะ API/หน้าเว็บ |
| Dependency | **Dependabot** alerts + security updates (PR รวมกลุ่ม) | GitHub | ต่อเนื่อง |
| e2e / smoke test | Playwright / สคริปต์ของ repo | Actions (push `main` หรือรายสัปดาห์เท่านั้น) หรือเครื่อง | ตามที่ repo กำหนด |

**เลือก SAST:** repo ที่มี Snyk Code อยู่แล้ว (มี `.snyk`, ตรวจ finding ไว้แล้ว) ใช้ Snyk ต่อ — ใบอนุญาตมหาวิทยาลัย (Team, Snyk Code อย่างเดียว)
repo ใหม่ / ผู้ร่วมงานที่ไม่มีบัญชี Snyk ใช้ Semgrep (ไม่ต้อง login) — ตั้งใน `.security-scan.conf` ด้วย `SAST=semgrep|snyk`

### ❌ ห้ามใช้
- **ใน GitHub Actions:** Trivy, Semgrep, Snyk, ZAP, CodeQL, OSV-Scanner, `npm audit` (ย้ายไปรันในเครื่องหรือซ้ำกับ Dependabot) — เหลือเฉพาะงานเร็วตามตารางด้านบน
- **ที่ไหนก็ตาม:** `snyk test` / `snyk container test` / `snyk monitor` (ไม่มีใบอนุญาต Open Source/Container; `monitor` สร้างโปรเจกต์บนเว็บ Snyk) ·
  `npm audit` เป็นเกต (มีจุดบอดกับเวอร์ชัน `-lts.x` และซ้ำกับ Dependabot) · Trivy `fs` สำหรับ dependency (ซ้ำกับ Dependabot)
- **ZAP กับ production** โดยไม่ได้แจ้งเจ้าของระบบ — baseline ปกติชี้ไปที่สแต็กในเครื่อง

## ไฟล์ที่ทุก repo ต้องมี
คัดลอกจาก [`templates/`](../templates) แล้วปรับตาม repo

| ไฟล์ | หน้าที่ |
|---|---|
| `.github/workflows/ci.yml` | test + gitleaks commit ใหม่ — [template](../templates/.github/workflows/ci.yml) |
| `.github/dependabot.yml` | PR ความปลอดภัยรวมกลุ่ม — [template](../templates/.github/dependabot.yml) |
| `scripts/security-scan.sh` | สแกนในเครื่อง — [ต้นฉบับ](../templates/scripts/security-scan.sh) **ห้ามแก้ใน repo** (ปรับผ่าน `.security-scan.conf`) |
| `.security-scan.conf` | ค่าของ repo: image ที่ต้อง build, SAST ที่ใช้, เป้า ZAP, ข้อยกเว้น — [template](../templates/.security-scan.conf) |
| `.gitignore` | ต้องมี `security-reports/` (รายงานมีรายละเอียดช่องโหว่ ห้าม commit) |
| `CI-CD.md` | สรุปมาตรฐาน + "เฉพาะ repo นี้" + ผลสแกนล่าสุด — [template](../templates/CI-CD.md) |

### `ci.yml` (template)
```yaml
name: ci
on:
  push:
    branches: [main]
    paths-ignore: ['**/*.md', 'docs/**', '.github/dependabot.yml']
  pull_request:
    paths-ignore: ['**/*.md', 'docs/**']
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with: { node-version: 24, cache: npm }     # ให้ตรงกับ Node ใน Dockerfile ของ production
      - run: npm ci
      - run: npm run lint --if-present && npm run typecheck --if-present && npm test --if-present
  secrets:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
      pull-requests: read                          # gitleaks-action อ่านรายการ commit ของ PR — ขาดแล้ว 403 บน repo private
    steps:
      - uses: actions/checkout@v7
        with: { fetch-depth: 0 }
      - uses: gitleaks/gitleaks-action@e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e  # v3.0.0 — scan เฉพาะ commit ใหม่
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_VERSION: 8.30.1                 # ตัวที่ action แถมมา (8.24) ไม่อ่าน [[allowlists]]
```
- `actions/*` ใช้ **v7** (runtime Node 24) — v4 รันบน Node 20 ที่ GitHub เลิกรองรับแล้ว · action ของ third-party ปักด้วย commit SHA
- monorepo: ทำ `test` เป็น `matrix` ต่อโฟลเดอร์ + `cache-dependency-path`
- e2e / smoke test บน `docker compose` ใส่ได้ แต่รันเฉพาะ push `main` (`if: github.event_name == 'push'`) หรือ workflow แยกที่รันรายสัปดาห์/สั่งเอง

### `dependabot.yml` (template)
```yaml
version: 2
updates:
  - package-ecosystem: npm
    directories: ["/"]                      # ใส่ทุกโฟลเดอร์ที่มี lockfile
    schedule: { interval: weekly, day: monday, time: "06:00", timezone: Asia/Bangkok }
    open-pull-requests-limit: 0             # ปิด PR อัปเวอร์ชันทั่วไป — PR ความปลอดภัยยังมา
    groups:
      security:
        applies-to: security-updates
        patterns: ["*"]
  - package-ecosystem: github-actions
    directory: /
    schedule: { interval: weekly, day: monday, time: "06:00", timezone: Asia/Bangkok }
    open-pull-requests-limit: 0
    groups:
      security:
        applies-to: security-updates
        patterns: ["*"]
```
- ต้องเปิด **Settings → Code security → Dependabot alerts + Dependabot security updates** ด้วย (ไฟล์อย่างเดียวไม่พอ)
- ไม่ใส่ ecosystem `docker` — Dependabot ไม่มี security update ของ base image; ใช้ `docker build --pull` + Trivy ในเครื่องแทน
- ecosystem อื่น (pip, composer, gomod, …) ใช้รูปแบบเดียวกัน · ห้ามปิด PR ความปลอดภัยของ Dependabot เอง — PR แบบกลุ่มจะปิดตัวเดี่ยวให้

## สแกนในเครื่อง — `scripts/security-scan.sh`
ต้องมีแค่ **Docker** (Docker Desktop บน Windows/macOS) + bash (Windows: Git Bash หรือ WSL)

```bash
bash scripts/security-scan.sh              # secrets + sast + container (+ dast ถ้าตั้ง ZAP_TARGET)
bash scripts/security-scan.sh container    # เฉพาะ Trivy
docker compose up -d && bash scripts/security-scan.sh dast   # ZAP baseline กับสแต็กในเครื่อง
```

| ขั้น | ทำอะไร | เกณฑ์ไม่ผ่าน |
|---|---|---|
| `secrets` | gitleaks ทั้ง history — อ่าน `.gitleaks.toml` / `.gitleaksignore` ที่ราก repo | พบ secret ที่ไม่ได้ allow-list |
| `sast` | Semgrep (`p/security-audit p/secrets p/javascript p/typescript p/nodejsscan`) หรือ `snyk code test` | finding ระดับ HIGH (Snyk) / WARNING+ (Semgrep) |
| `container` | `docker build --pull` ทุก image ใน `IMAGES` → `trivy image` + `trivy config` | HIGH/CRITICAL ที่มีตัวแก้ (`--ignore-unfixed`) |
| `dast` | `zap-baseline.py` ไปที่ `ZAP_TARGET` (แปลง `localhost` → `host.docker.internal` ให้) หรือผ่าน `ZAP_NETWORK` | FAIL ของ ZAP (WARN ไม่ล้ม) |

- เวอร์ชันของทุกเครื่องมือปักไว้ในสคริปต์ (gitleaks 8.30.1, Semgrep 1.186.0, Trivy 0.76.2, ZAP 2.17.0, Snyk CLI 1.1309.0 ปักด้วย digest) — อัปเดตที่ต้นฉบับแล้วคัดลอกไปทุก repo
- Snyk: ใช้ `SNYK_TOKEN` ถ้ามี ไม่งั้นใช้ credential จาก `snyk auth` ที่เคย login บนเครื่อง
- รายงานอยู่ที่ `security-reports/` (JSON / SARIF / HTML) · exit code ≠ 0 เมื่อมีขั้นที่ไม่ผ่าน
- ข้อยกเว้นใส่ใน `.security-scan.conf`, `.trivyignore.yaml`, `.gitleaks.toml`, `.snyk`, `.semgrepignore`/`# nosemgrep`, `.zap/rules.tsv`
  **ทุกข้อยกเว้นต้องมีเหตุผล + เงื่อนไขเอาออก** ใน `CI-CD.md` ของ repo · ตั้ง `SAST_FAIL=0` / `ZAP_FAIL=0` (รายงานอย่างเดียว) ได้เฉพาะเมื่อ finding ที่เหลือตรวจด้วยตาแล้วทั้งหมด

### เมื่อไรต้องรัน (แทนรอบ weekly บน Actions เดิม)
1. **ก่อน deploy ทุกครั้ง** — `bash scripts/security-scan.sh` ต้องผ่าน (หรือมีข้อยกเว้นที่บันทึกแล้ว)
2. **รายสัปดาห์** (วันจันทร์) สำหรับ repo ที่ deploy จริง — CVE ใหม่ของ base image ออกทุกวันแม้โค้ดไม่เปลี่ยน
3. **PR ที่แตะ auth / upload / query / Dockerfile** — แนบผลสรุป (บรรทัด "สรุป" ท้ายสคริปต์) ในคำอธิบาย PR
4. บันทึกวันที่ + commit + ผลล่าสุดในหัวข้อ "ผลสแกนล่าสุด" ของ `CI-CD.md`

## กติกาเพื่อประหยัดนาที
- commit ที่แก้แค่เอกสาร: `paths-ignore` จัดการให้ หรือใส่ `[skip ci]` ใน commit message
- ทุก job ต้องมี `timeout-minutes` · ทุก workflow ต้องมี `concurrency`
- e2e / Playwright / load test: push `main` หรือรายสัปดาห์ ไม่ใช่ทุก PR — หรือรันในเครื่อง
- ไม่มี secret ที่ CI ต้องใช้ (Snyk รันในเครื่องแล้ว) — ลบ `SNYK_TOKEN` ออกจาก repo secrets ได้

## ประวัติการแก้ไข
- **v2.0 (2026-11-23)** — ย้ายสแกนหนักทั้งหมด (Trivy, Snyk Code/Semgrep, ZAP, gitleaks ทั้ง history) จาก `security-weekly.yml` ไปรันในเครื่องด้วย Docker ผ่าน `scripts/security-scan.sh` (เลิกใช้ `security-weekly.yml`) ·
  SAST เลือก Semgrep หรือ Snyk Code ต่อ repo · `actions/checkout` / `setup-node` → v7 (Node 24) · Dependabot เพิ่ม ecosystem `github-actions`, ไม่ใช้ `docker` ·
  เพิ่มโฟลเดอร์ `templates/` · เป้านาที Actions ลดเหลือ ≤ ~1,000/เดือน ·
  ที่มา: ระบบส่วนใหญ่อยู่ในเครือข่ายภายใน มข. ที่ runner ของ GitHub เข้าไม่ถึง (ZAP), ไม่ต้องแจก `SNYK_TOKEN` ให้ทุก repo, และ repo ที่ไม่ได้ตั้ง token ถูกข้าม Snyk เงียบๆ มาตลอด
- **v1.2 (2026-11-03)** — ตั้ง `GITLEAKS_VERSION` (gitleaks ที่ action แถมมา 8.24 ไม่รองรับ `[[allowlists]]`) · `concurrency` ของ `security-weekly.yml` แยกตาม `github.event_name` · Trivy `skip-files` สำหรับเครื่องมือที่ใส่ไว้ใน image เอง พร้อมเหตุผล + เงื่อนไขเอาออก
- **v1.1 (2026-11-03)** — job `secrets` ต้องมี `permissions: pull-requests: read` (403 บน PR ของ repo private) · gitleaks-action → v3.0.0 ปักด้วย SHA
- **v1.0 (2026-11-01)** — มาตรฐานแรก: `ci.yml` + `security-weekly.yml` + Dependabot แบบรวมกลุ่ม

## เช็กลิสต์ย้ายเข้ามาตรฐาน (สำหรับผู้ดูแล / AI ประจำ repo)
- [ ] `ci.yml` ตาม template: `paths-ignore` + `concurrency` + `timeout-minutes` + actions v7 + gitleaks v3 ปัก SHA + `GITLEAKS_VERSION`
- [ ] ลบ workflow สแกนหนัก (`security-weekly.yml`, `codeql.yml`, `zap.yml`, …) และเครื่องมือในรายการ "ห้ามใช้"
- [ ] `dependabot.yml` แบบรวมกลุ่ม + เปิด Dependabot alerts / security updates ใน Settings
- [ ] คัดลอก `scripts/security-scan.sh`, เขียน `.security-scan.conf`, เพิ่ม `security-reports/` ใน `.gitignore`
- [ ] รัน `bash scripts/security-scan.sh` ครั้งแรก — บันทึกผล + ข้อยกเว้นทุกข้อพร้อมเหตุผลใน `CI-CD.md`
- [ ] เปิด PR (ไม่ push เข้า main ตรง) แนบผลรัน CI และผลสแกนในเครื่อง
