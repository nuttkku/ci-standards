# CLAUDE.md — ci-standards

repo นี้คือ**ต้นฉบับ**มาตรฐาน CI/CD + ความปลอดภัยของทุก repo `nuttkku` — repo อื่นคัดลอกจาก `templates/` และอ้างถึง `standards/CI-CD.md`

## กติกา
- **repo นี้เป็น public** — ห้ามใส่ secret, hostname/IP ภายใน, ชื่อระบบภายใน, รายละเอียดช่องโหว่หรือ finding ของ repo ใด (ข้อมูลพวกนั้นอยู่ใน `CI-CD.md` ของ repo นั้นเอง)
- ภาษา: เอกสารเป็นภาษาไทย ชื่อเครื่องมือ/คำสั่งเป็นภาษาอังกฤษ
- เปลี่ยนผ่าน PR · ทุกการเปลี่ยนกติกาต้อง: ขยับเวอร์ชันในหัว `standards/CI-CD.md` + บรรทัดใน "ประวัติการแก้ไข" + บันทึกใน `docs/HISTORY.md`
  - patch (v2.0 → v2.0.1): แก้คำ/ตัวอย่าง · minor (v2.1): เพิ่ม/ปรับเครื่องมือหรือค่าที่ repo ต้องตามแก้ · major (v3): เปลี่ยนโครงสร้าง
- template ใน `templates/` กับตัวอย่างโค้ดใน `standards/CI-CD.md` ต้องตรงกันเสมอ

## ไฟล์
| ไฟล์ | หน้าที่ |
|---|---|
| `standards/CI-CD.md` | มาตรฐานฉบับเต็ม (กติกา, รายการห้ามใช้, เช็กลิสต์, ประวัติเวอร์ชัน) |
| `templates/scripts/security-scan.sh` | สคริปต์สแกนในเครื่อง — ทุก repo ใช้สำเนาเดียวกันทุกไบต์ |
| `templates/.security-scan.conf` | ตัวอย่างค่าต่อ repo |
| `templates/.github/workflows/ci.yml`, `templates/.github/dependabot.yml` | workflow + Dependabot |
| `templates/CI-CD.md` | หน้าสรุปที่แต่ละ repo ต้องมี |
| `templates/CLAUDE.md` | ส่วนที่วางใน CLAUDE.md ของแต่ละ repo |
| `docs/HISTORY.md` | บันทึกการทำงาน: ทำอะไร เมื่อไร เพราะอะไร และบทเรียน |

## แก้ `security-scan.sh`
1. แก้ที่ `templates/scripts/security-scan.sh` → `bash -n` ผ่าน
2. ทดสอบจริงอย่างน้อย 1 repo ที่มี Dockerfile: `bash scripts/security-scan.sh` (Windows: Git Bash + Docker Desktop — ต้องเปิด Docker Desktop ก่อน)
3. กติกาที่ต้องคงไว้:
   - exit 1 = พบ finding, ≥ 2 = เครื่องมือทำงานไม่สำเร็จ → โหมด report-only (`SAST_FAIL=0`/`ZAP_FAIL=0`) ห้ามกลบ error
   - `MSYS_NO_PATHCONV=1` + `pwd -W` สำหรับ mount ใน Git Bash · อ่าน `.security-scan.conf` ผ่าน `tr -d '\r'`
   - เวอร์ชัน image ปักทุกตัว (Snyk ไม่มี tag เวอร์ชัน → ปักด้วย digest และเขียนเวอร์ชัน CLI ในคอมเมนต์)
4. คัดลอกไปทุก repo ที่ใช้ v2 ผ่าน PR (ดูรายชื่อใน `docs/HISTORY.md`)

## อัปเดตเวอร์ชันเครื่องมือ
```bash
curl -s "https://hub.docker.com/v2/repositories/<image>/tags?page_size=10&ordering=last_updated"   # gitleaks, semgrep, trivy, zap
docker pull snyk/snyk:linux && docker inspect --format '{{index .RepoDigests 0}}' snyk/snyk:linux
gh api repos/actions/checkout/releases/latest -q .tag_name   # และ setup-node, gitleaks-action
```
ปรับใน `security-scan.sh` + ตาราง/ข้อความใน `standards/CI-CD.md` พร้อมกัน
