# ci-standards

มาตรฐาน CI/CD และความปลอดภัยที่ใช้ร่วมกันทุก repo ของ `nuttkku`

| ไฟล์ | คืออะไร |
|---|---|
| [standards/CI-CD.md](standards/CI-CD.md) | มาตรฐาน v1 — เครื่องมือต่อหน้าที่, template `ci.yml` / `security-weekly.yml` / `dependabot.yml`, กติกาประหยัดนาที, เช็กลิสต์ |

แต่ละ repo มี `CI-CD.md` ของตัวเองที่สรุปมาตรฐานนี้ + สิ่งที่ต้องปรับเฉพาะ repo นั้น

repo นี้เป็น public เพื่อให้ทุก repo (ทั้ง public และ private) และผู้ร่วมงานเปิดอ่านได้ — **ห้ามใส่ secret, hostname/IP ภายใน หรือข้อมูลองค์กร**
