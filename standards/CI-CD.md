# มาตรฐาน CI/CD — nuttkku (v1.1, 2026-11-03)

ไฟล์ต้นฉบับอยู่ที่ `nuttkku/ci-standards/standards/CI-CD.md` (repo public) — แต่ละ repo มีสำเนาย่อ + หัวข้อ "เฉพาะ repo นี้" ใน `CI-CD.md`
ถ้าจะเปลี่ยนมาตรฐาน แก้ที่ต้นฉบับก่อน แล้วค่อยอัปเดตสำเนา

## เป้าหมาย
1. ทุก repo ตรวจความปลอดภัยแบบเดียวกัน — **เครื่องมือเดียวต่อหนึ่งหน้าที่**
2. GitHub Actions ของ repo private รวมกันไม่เกิน **~2,000 นาที/เดือน** (โควตา GitHub Pro 3,000)
3. PR ได้ผลเร็ว (≤ 5 นาที) งานหนักรันแค่ตอนเข้า `main` และรายสัปดาห์

## เครื่องมือมาตรฐาน
| หน้าที่ | ใช้ | รันเมื่อ |
|---|---|---|
| คุณภาพโค้ด | lint / typecheck / unit test ของ repo เอง | ทุก PR |
| หา secret | **gitleaks** — PR: เฉพาะ commit ใหม่ · weekly: ทั้ง history | PR, weekly |
| SAST | **Snyk Code** (`snyk code test`) — ใบอนุญาตมหาวิทยาลัย (Team, Snyk Code อย่างเดียว) | push `main`, weekly |
| Dependency | **Dependabot** (alert + PR รวมกลุ่ม) + สแกน OSV รายสัปดาห์จาก devsecops-agent | ต่อเนื่อง |
| Container / Dockerfile | **Trivy** image + config | push `main`, weekly (เฉพาะ repo ที่มี Dockerfile) |
| DAST | **OWASP ZAP baseline** | weekly / สั่งเอง — เฉพาะแอปที่ deploy จริง |
| SAST (repo public) | CodeQL (ฟรีบน public) แทน/เสริม Snyk Code | weekly |

### ❌ ห้ามใช้ใน CI (ซ้ำหรือไม่มีใบอนุญาต)
`npm audit` (มีจุดบอดกับเวอร์ชัน `-lts.x`) · `snyk test` / `snyk container test` / `snyk monitor` (ไม่มีใบอนุญาต Open Source/Container
และ `monitor` สร้างโปรเจกต์บนเว็บ Snyk) · Semgrep (ซ้ำกับ Snyk Code) · OSV-Scanner / Trivy fs ใน CI (ซ้ำกับ Dependabot) ·
CodeQL บน repo **private** (Pro ไม่มี GHAS ใช้ผลไม่ได้) · ZAP ในทุก PR

## โครง workflow มาตรฐาน (2 ไฟล์)
### 1) `.github/workflows/ci.yml` — งานเร็ว ทุก PR + main
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
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 24, cache: npm }
      - run: npm ci
      - run: npm run lint --if-present && npm run typecheck --if-present && npm test --if-present
  secrets:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
      pull-requests: read                    # gitleaks-action อ่านรายการ commit ของ PR — ขาดแล้ว 403 บน repo private
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: gitleaks/gitleaks-action@e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e  # v3.0.0 (Node 24) — บัญชีส่วนตัวใช้ฟรี; scan เฉพาะ commit ใน PR
        env: { GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} }
```
### 2) `.github/workflows/security-weekly.yml` — งานหนัก main + รายสัปดาห์
```yaml
name: security-weekly
on:
  push:
    branches: [main]
    paths-ignore: ['**/*.md', 'docs/**']
  schedule: [{ cron: '0 20 * * 0' }]       # จันทร์ 03:00 เวลาไทย
  workflow_dispatch:
concurrency:
  group: security-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: read
jobs:
  snyk-code:
    if: github.actor != 'dependabot[bot]'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: snyk/actions/setup@master       # ปักเวอร์ชัน/SHA ตอนใช้จริง
      - run: snyk code test --severity-threshold=high
        env: { SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }} }
  trivy:                                       # ลบ job นี้ถ้า repo ไม่มี Dockerfile
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t app:ci -f Dockerfile .          # ปรับ path ตาม repo
      - uses: aquasecurity/trivy-action@<pinned-sha>         # ปักด้วย commit SHA เสมอ
        with: { image-ref: 'app:ci', severity: 'HIGH,CRITICAL', exit-code: '1', ignore-unfixed: true }
      - uses: aquasecurity/trivy-action@<pinned-sha>
        with: { scan-type: config, scan-ref: '.', severity: 'HIGH,CRITICAL' }
  gitleaks-history:
    if: github.event_name != 'push'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: gitleaks/gitleaks-action@e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e  # v3.0.0
        env: { GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} }
```
ZAP (เฉพาะแอปที่ deploy): เพิ่ม job `zaproxy/action-baseline` ใน `security-weekly.yml` โดยให้รันเฉพาะ `schedule`/`workflow_dispatch`

## Dependabot — `.github/dependabot.yml`
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
```
ห้ามปิด PR ความปลอดภัยของ Dependabot เอง — PR แบบกลุ่มจะปิดตัวเดี่ยวให้

## กติกาเพื่อประหยัดนาที
- commit ที่แก้แค่เอกสาร: ไม่ต้องทำอะไร (`paths-ignore`) หรือใส่ `[skip ci]` ใน commit message
- ทุก job ต้องมี `timeout-minutes`
- e2e / Playwright / load test: รันบน `main` หรือ weekly ไม่ใช่ทุก PR
- งาน refactor ใหญ่: ทดสอบในเครื่องหรือ Codespaces ก่อน push
- secret ที่ต้องใช้: `SNYK_TOKEN` (repo secret) — Dependabot PR จะไม่ได้รับ secret นี้ จึงข้าม snyk ใน PR ของ Dependabot

## ประวัติการแก้ไข
- **v1.1 (2026-11-03)** — job `secrets` ใน `ci.yml` ต้องมี `permissions: pull-requests: read` (เดิมได้แค่ `contents: read` จาก workflow → gitleaks-action ได้ 403 `Resource not accessible by integration` บน PR ของ repo private) · gitleaks-action → v3.0.0 (runtime Node 24, input/behavior เหมือน v2) ปักด้วย SHA — พบตอนย้าย `odt-infra-ticket`

## เช็กลิสต์ย้ายเข้ามาตรฐาน (สำหรับผู้ดูแล / AI ประจำ repo)
- [ ] ใส่ `paths-ignore` + `concurrency` + `timeout-minutes` ในทุก workflow
- [ ] ลบเครื่องมือในรายการ "ห้ามใช้"
- [ ] แยกงานหนักไป `security-weekly.yml`
- [ ] ใส่ `dependabot.yml` แบบรวมกลุ่ม
- [ ] ตั้ง `SNYK_TOKEN` (ถ้ามี Snyk Code job)
- [ ] เปิด PR (ไม่ push เข้า main ตรง) แนบผลรันครั้งแรกและเวลาที่ใช้ แล้วแจ้ง devsecops-agent ให้ตรวจ
