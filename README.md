# ci-standards

มาตรฐาน CI/CD และความปลอดภัยที่ใช้ร่วมกันทุก repo ของ `nuttkku` — **v2.0 (2026-11-23)**

**สั้นๆ:** GitHub Actions ทำแค่งานเร็ว (test + หา secret ใน commit ใหม่) · สแกนความปลอดภัยหนัก (Trivy, Semgrep/Snyk Code, ZAP)
รันบนเครื่องด้วย Docker ผ่านสคริปต์เดียว · dependency ใช้ Dependabot

| ไฟล์ | คืออะไร |
|---|---|
| [standards/CI-CD.md](standards/CI-CD.md) | มาตรฐานฉบับเต็ม — เครื่องมือต่อหน้าที่, รายการห้ามใช้, เมื่อไรต้องสแกน, ประวัติการแก้ไข, เช็กลิสต์ย้ายเข้ามาตรฐาน |
| [templates/.github/workflows/ci.yml](templates/.github/workflows/ci.yml) | workflow เดียวที่ต้องมี |
| [templates/.github/dependabot.yml](templates/.github/dependabot.yml) | Dependabot — PR ความปลอดภัยรวมกลุ่ม |
| [templates/scripts/security-scan.sh](templates/scripts/security-scan.sh) | สแกนในเครื่อง: `secrets` (gitleaks) · `sast` (Semgrep/Snyk Code) · `container` (Trivy) · `dast` (ZAP) |
| [templates/.security-scan.conf](templates/.security-scan.conf) | ค่าต่อ repo ของสคริปต์สแกน |
| [templates/CI-CD.md](templates/CI-CD.md) | หน้าสรุปที่แต่ละ repo ต้องมี |

## เริ่มใช้ใน repo ใหม่
```bash
# ที่ราก repo ปลายทาง
base=https://raw.githubusercontent.com/nuttkku/ci-standards/main/templates
mkdir -p .github/workflows scripts
curl -fsSL $base/.github/workflows/ci.yml -o .github/workflows/ci.yml
curl -fsSL $base/.github/dependabot.yml   -o .github/dependabot.yml
curl -fsSL $base/scripts/security-scan.sh -o scripts/security-scan.sh
curl -fsSL $base/.security-scan.conf      -o .security-scan.conf
curl -fsSL $base/CI-CD.md                 -o CI-CD.md
echo 'security-reports/' >> .gitignore
bash scripts/security-scan.sh             # ต้องมี Docker; Windows ใช้ Git Bash
```
แล้วปรับ `ci.yml` (คำสั่ง test, matrix), `dependabot.yml` (โฟลเดอร์ lockfile), `.security-scan.conf` (image, SAST) และกรอก `CI-CD.md` ตามเช็กลิสต์ใน [มาตรฐาน](standards/CI-CD.md#เช็กลิสต์ย้ายเข้ามาตรฐาน-สำหรับผู้ดูแล--ai-ประจำ-repo)

## ทำไมสแกนในเครื่อง
- ระบบส่วนใหญ่อยู่ในเครือข่ายภายใน — runner ของ GitHub เข้าไม่ถึง (ZAP ทำไม่ได้)
- ไม่ต้องแจก token ของ Snyk ให้ทุก repo และไม่ถูก "ข้ามเงียบๆ" เมื่อลืมตั้ง token
- ไม่กินนาที GitHub Actions (build image + สแกนเป็นงานที่ช้าที่สุดใน workflow เดิม) และเห็นผลเต็มทันทีบนเครื่อง

## แก้มาตรฐาน
เปิด PR ที่ repo นี้ก่อน → เพิ่มบรรทัดใน "ประวัติการแก้ไข" → ค่อยอัปเดต repo ต่างๆ
`security-scan.sh` ห้ามแก้ใน repo ปลายทาง — ปรับที่นี่แล้วคัดลอกไป

repo นี้เป็น public เพื่อให้ทุก repo (ทั้ง public และ private) และผู้ร่วมงานเปิดอ่านได้ — **ห้ามใส่ secret, hostname/IP ภายใน หรือข้อมูลองค์กร**
