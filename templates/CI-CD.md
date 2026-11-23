# CI/CD — <ชื่อ repo>

ทำตามมาตรฐาน [`nuttkku/ci-standards`](https://github.com/nuttkku/ci-standards/blob/main/standards/CI-CD.md) **v2.0** — ถ้าจะเปลี่ยนกติกา แก้ที่ต้นฉบับก่อน

| อะไร | รันที่ / เมื่อ | งาน |
|---|---|---|
| `.github/workflows/ci.yml` | Actions — ทุก PR + push `main` | <lint / typecheck / test ของ repo> · gitleaks เฉพาะ commit ใหม่ |
| `.github/dependabot.yml` | GitHub — จันทร์ 06:00 | PR ความปลอดภัยรวมกลุ่ม: <โฟลเดอร์ที่มี lockfile> + GitHub Actions |
| `scripts/security-scan.sh` | เครื่อง (Docker) — ก่อน deploy + รายสัปดาห์ | gitleaks ทั้ง history · <Semgrep/Snyk Code> · Trivy <image ...> + config · ZAP baseline <เป้า> |

```bash
bash scripts/security-scan.sh                 # ทั้งหมด
docker compose up -d && bash scripts/security-scan.sh dast
```

## เฉพาะ repo นี้
- <ข้อยกเว้น / ความต่างจากมาตรฐาน — ทุกข้อมีเหตุผล + เงื่อนไขเอาออก>

## ผลสแกนล่าสุด
| วันที่ | commit | secrets | sast | container | dast | หมายเหตุ |
|---|---|---|---|---|---|---|
| YYYY-MM-DD | abc1234 | PASS | PASS | PASS | — | |
