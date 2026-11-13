#!/bin/sh
# ทำใบใหม่ — รวมไฟล์ความลับแล้วเข้ารหัส AES-256 เป็นก้อนเดียว
#
# ★★★ โครงของสคริปต์นี้คือตัวที่สำคัญที่สุด ไม่ใช่คำสั่งเข้ารหัส
#   ขั้นลบไฟล์ชั่วคราวอยู่ใน trap จึงทำงาน **ทุกกรณี** ไม่ว่าสำเร็จหรือล้มกลางทาง
#   ของเดิมแขวนขั้นลบไว้กับ && แล้วล้มสองรอบ เหลือความลับนอนเป็นข้อความเปล่าบนดิสก์
#
#   ใช้: BOX=root@<ที่อยู่ของกล่อง> sh ops/seal.sh
set -eu
. "$(dirname "$0")/lib.sh"

# ที่อยู่ของสองไฟล์บนกล่อง — ตั้ง SRC_ENV/SRC_PW ทับได้ (ใช้ตอนทดสอบสคริปต์นี้)
if [ -z "${SRC_ENV:-}" ] || [ -z "${SRC_PW:-}" ]; then
  box_required
  SRC_ENV="$BOX:$BOX_ENV"
  SRC_PW="$BOX:'$BOX_PW'"
fi

STAGE=$(mktemp -d)
TAR=$(mktemp)
TMPOUT=$(mktemp)
# ★ ลบทุกอย่างที่เป็นข้อความเปล่าเสมอ — สำเร็จก็ลบ ล้มก็ลบ กด Ctrl-C ก็ลบ
trap 'rm -rf "$STAGE" "$TAR" "$TMPOUT"' EXIT INT TERM HUP

echo "— รวบรวมไฟล์ —"
cp "$APP/.env"           "$STAGE/env-เครื่องผู้พัฒนา.txt"
cp "$APP/weather/.env"   "$STAGE/env-คลังพยากรณ์.txt"
cp "$NR/flows_cred.json" "$NR/settings.js" "$STAGE/"
eval scp -q "$SRC_ENV" '"$STAGE/env-กล่อง.txt"'
eval scp -q "$SRC_PW"  '"$STAGE/รหัสผ่านของระบบ.txt"' 
ls -1 "$STAGE" | sed 's/^/  /'

n=$(ls -1 "$STAGE" | wc -l | tr -d ' ')
[ "$n" -eq 6 ] || { echo "ได้ $n ไฟล์ ควรได้ 6 — ไม่เข้ารหัส"; exit 1; }

tar czf "$TAR" -C "$STAGE" .

# หาชื่อที่ยังว่าง — ★ ห้ามทับใบที่ยังใช้ได้ (openssl เปิดไฟล์ปลายทางก่อนถามรหัส
#   พิมพ์รหัสพลาดแล้วไฟล์ดีจะกลายเป็นไฟล์ว่างทันที)
base="$BUNDLES/swine-ความลับ-$(be_today)"
OUT="$base.tar.gz.enc"
for s in b c d e f; do
  [ -e "$OUT" ] || break
  OUT="$base$s.tar.gz.enc"
done
[ -e "$OUT" ] && { echo "วันนี้มีใบครบทุกชื่อแล้ว — ลบใบที่ไม่ใช้ก่อน"; exit 1; }

echo
if [ -n "$PASSFILE" ]; then
  echo "— ใช้รหัสจากไฟล์ $PASSFILE (ไม่ต้องพิมพ์) —"
  openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -in "$TAR" -out "$TMPOUT" -pass "file:$PASSFILE"
else
  echo "— ใส่รหัสผ่านที่จะใช้ปิดก้อน (หน้าจอไม่แสดงตัวอักษร ถามสองครั้ง) —"
  echo "★ ก๊อปจากที่เก็บรหัสมาวาง อย่าคิดสดตอนนี้"
  openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -in "$TAR" -out "$TMPOUT"
fi

head -c 8 "$TMPOUT" | grep -q "Salted__" || { echo "ผลลัพธ์ไม่ใช่ไฟล์เข้ารหัส — ไม่เก็บ"; exit 1; }
cp "$TMPOUT" "$OUT"
chmod 600 "$OUT"

echo
echo "[ สำเร็จ ] $OUT  ($(du -h "$OUT" | cut -f1))"
echo "➜ ขั้นต่อไป **เปิดดูให้ผ่านก่อน** แล้วค่อยลบใบเก่า:  sh ops/verify.sh"
