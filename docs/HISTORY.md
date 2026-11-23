# บันทึกการทำงาน — ci-standards

ทำอะไร เมื่อไร เพราะอะไร และบทเรียนที่ได้ — ล่าสุดอยู่บน
(repo นี้เป็น public: ไม่ระบุชื่อ repo private หรือรายละเอียด finding — ดู `CI-CD.md` ของแต่ละ repo แทน)

หา repo ที่ใช้มาตรฐานอยู่:
```bash
gh search code --owner nuttkku --filename .security-scan.conf     # v2
gh search code --owner nuttkku "nuttkku/ci-standards" --filename CI-CD.md
```

---

## 2026-11-23 — v2.0: ย้ายสแกนความปลอดภัยไปรันในเครื่องด้วย Docker

**ตัดสินใจ** (เจ้าของ repo กำหนด)
- container = Trivy · โค้ด = Semgrep หรือ Snyk Code · DAST = OWASP ZAP — ทั้งหมดรันบนเครื่องด้วย Docker
- dependency = Dependabot ของ GitHub
- GitHub Actions เหลือแค่ lint/typecheck/test + gitleaks commit ใหม่

**เหตุผล**
- ระบบส่วนใหญ่อยู่ในเครือข่ายภายใน — runner ของ GitHub เข้าไม่ถึง ZAP จึงทำใน CI ไม่ได้
- job SAST ใน CI พึ่ง repo secret `SNYK_TOKEN`; repo ที่ลืมตั้ง job จะข้ามด้วย warning แล้วผ่าน — ไม่มีใครเห็นผล
- build image + สแกนเป็นงานที่ช้าที่สุดใน workflow (มี repo ที่ CI ใช้ ~20 นาที/PR จนโควตา Actions หมดเมื่อปลาย ต.ค. 2026 และ CI บน main ไม่รันราว 10 วัน)

**ทำอะไร**
- เขียน `templates/scripts/security-scan.sh` (secrets / sast / container / dast) + `.security-scan.conf` ต่อ repo · เพิ่มโฟลเดอร์ `templates/`
- actions/checkout + setup-node → v7 (Node 24) · Dependabot เพิ่ม `github-actions`, ไม่ใช้ `docker`
- ย้าย 4 repo private ที่ใช้ v1.x อยู่ — ลบ `security-weekly.yml` (และ `dast.yml` ใน repo หนึ่ง), e2e ที่ไม่ใช่สแกนแยกเป็น workflow รายสัปดาห์
- รันสแกนรอบแรกทั้ง 4 repo บน Windows (Git Bash + Docker Desktop): ใช้เวลา ~30 วินาที (secrets+sast) ถึง ~3 นาที (container, รวม build) ต่อ repo
  ทุก repo เจอ finding ที่ v1 ไม่เคยเห็น — บันทึกเป็น "งานค้าง" ใน `CI-CD.md` ของแต่ละ repo
- ตรวจ workflow ด้วย actionlint 1.7.7 · CI บน PR ของทั้ง 4 repo ผ่าน

**บทเรียน**
- **report-only ต้องไม่กลบ error** — Snyk timeout เคยแสดงเป็น "FINDINGS (report-only)" → แยก exit 1 (finding) กับ ≥ 2 (เครื่องมือพัง)
- **report-only แบบ `|| true` ใน CI ทำให้ finding ใหม่หายเงียบ** — ใช้ได้เฉพาะเมื่อตรวจ finding ครบทุกจุดแล้ว และต้องรันดูผลเป็นระยะ
- **Trivy config ไม่ใส่ `--exit-code 1` = ไม่เคยล้ม** — v2 ให้ล้มที่ HIGH/CRITICAL
- **Windows `core.autocrlf=true`** แปลง `.sh` เป็น CRLF แล้ว bash พัง → `.gitattributes` `*.sh text eol=lf` + สคริปต์อ่าน config ผ่าน `tr -d '\r'`
- **Git Bash แปลง path** ที่ส่งให้ docker → `MSYS_NO_PATHCONV=1` + `pwd -W` ตอน mount
- **เน็ตหลุดระหว่าง `docker build --pull` / `npm install`** เกิดบ่อย — รันขั้นนั้นซ้ำก่อนสรุปว่าไม่ผ่าน
- **Snyk ใน Docker** ใช้ credential `snyk auth` ของเครื่องได้ด้วยการ mount `~/.config/configstore` — ไม่ต้องแจก token
- **gitleaks `[[allowlists]] regexes`** จับที่ค่า secret ที่ถูกพบ ไม่ใช่ทั้งบรรทัด — ดูค่าจริงใน commit ก่อนเขียน regex

## 2026-11-07 — repo ที่ 3–4 ย้ายเข้า v1.2
- เลิกใช้ `npm audit`, `snyk test` / `snyk container test` / `snyk monitor`, Trivy fs; Dependabot เหลือเฉพาะ PR ความปลอดภัย
- บทเรียน: image ที่ลบ npm/corepack ทิ้งหลัง `npm install` ทำให้ Trivy เขียวโดยไม่ต้องข้ามโฟลเดอร์

## 2026-11-03 — v1.1 / v1.2 (พบตอนย้าย repo แรก)
- job `secrets` ต้องมี `permissions: pull-requests: read` — ไม่งั้น gitleaks-action ได้ 403 บน PR ของ repo private
- gitleaks-action v3.0.0 ปักด้วย SHA + `GITLEAKS_VERSION: 8.30.1` (ตัวที่แถมมา 8.24 ไม่อ่าน `[[allowlists]]`)
- `concurrency` ของงาน weekly แยกตาม `github.event_name` — push เข้า main เคยยกเลิกรอบ weekly ที่กำลังรัน

## 2026-11-01 — v1.0
- มาตรฐานแรก: เครื่องมือเดียวต่อหน้าที่, `ci.yml` (PR) + `security-weekly.yml` (main + รายสัปดาห์), Dependabot รวมกลุ่ม, เป้า ≤ 2,000 นาที Actions/เดือน
