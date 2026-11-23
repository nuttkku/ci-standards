## CI/CD และความปลอดภัย — nuttkku/ci-standards v2

repo นี้ใช้มาตรฐาน https://github.com/nuttkku/ci-standards/blob/main/standards/CI-CD.md
สรุปเฉพาะ repo + ข้อยกเว้น + ผลสแกนล่าสุดอยู่ใน `CI-CD.md` — **อ่านก่อนแก้ `.github/`, Dockerfile หรือ `.security-scan.conf`**

- **GitHub Actions ทำแค่งานเร็ว** (`ci.yml`: lint/typecheck/test + gitleaks commit ใหม่) — ห้ามเพิ่ม job Trivy / Semgrep / Snyk / ZAP / CodeQL / OSV / `npm audit` ใน workflow
- **สแกนความปลอดภัยรันในเครื่องด้วย Docker:** `bash scripts/security-scan.sh` (ไม่ใส่อะไร = secrets + sast + container; `dast` ต้องเปิดสแต็กก่อน)
  - Windows: เปิด Docker Desktop แล้วรันผ่าน Git Bash · Snyk ใช้ credential ของ `snyk auth` บนเครื่อง (หรือ `SNYK_TOKEN`)
  - รายงานอยู่ใน `security-reports/` (gitignored — มีรายละเอียดช่องโหว่ ห้าม commit / ห้ามวางในที่สาธารณะ)
- **ต้องรันสแกน** ก่อน deploy และใน PR ที่แตะ auth / upload / query / Dockerfile — แนบบรรทัด "สรุป" ท้ายสคริปต์ในคำอธิบาย PR และอัปเดตตาราง "ผลสแกนล่าสุด" ใน `CI-CD.md`
- ถ้าสแกนล้มเพราะเน็ต (pull image / npm ECONNRESET / Snyk timeout) ให้รันขั้นนั้นซ้ำ — ผลขึ้น `ERROR` ไม่ใช่ `FAIL`
- **ข้อยกเว้นทุกข้อต้องมีเหตุผล + เงื่อนไขเอาออก** ใน `CI-CD.md` (ไฟล์ข้อยกเว้น: `.security-scan.conf`, `.trivyignore.yaml`, `.gitleaks.toml`, `.snyk`, `.zap/rules.tsv`) — ห้ามกด finding ให้เงียบโดยไม่ได้ตรวจ
- **ห้ามแก้ `scripts/security-scan.sh` ใน repo นี้** — ปรับผ่าน `.security-scan.conf`; ถ้าต้องแก้สคริปต์ให้แก้ที่ ci-standards แล้วคัดลอกมา
- Dependency: Dependabot เท่านั้น (PR ความปลอดภัยรวมกลุ่ม) — ห้ามปิด PR ของ Dependabot เอง
- เปลี่ยน pipeline ผ่าน PR เสมอ ไม่ push เข้า `main` ตรง
