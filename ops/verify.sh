#!/bin/sh
# เปิดก้อน — ค่าตั้งต้นคือ "ดูชื่อไฟล์ข้างในเท่านั้น ไม่แกะออกมา"
#
#   sh ops/verify.sh              ดูว่ามีไฟล์อะไรข้างใน (ปลอดภัยที่สุด)
#   sh ops/verify.sh --extract    แกะออกมาจริงตอนกู้ระบบ
#   sh ops/verify.sh <ไฟล์>       เลือกใบเอง (ไม่ใส่ = ใบล่าสุด)
set -eu
. "$(dirname "$0")/lib.sh"

extract=0
file=""
for a in "$@"; do
  case "$a" in
    --extract) extract=1 ;;
    *) file="$a" ;;
  esac
done
[ -n "$file" ] || file=$(newest_bundle || true)
[ -n "$file" ] || { echo "ยังไม่มีก้อนใน $BUNDLES — ทำใบใหม่ด้วย ops/seal.sh"; exit 1; }

echo "ใบที่เปิด: $file"
head -c 8 "$file" | grep -q "Salted__" || { echo "ไม่ใช่ไฟล์เข้ารหัสของเรา"; exit 1; }

if [ "$extract" = 0 ]; then
  echo "— ใส่รหัสผ่าน —"
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "$file" | LC_ALL=en_US.UTF-8 tar tzf - | sed 's/^/  /'
  echo
  echo "★ ต้องเห็นครบ 6 ไฟล์ตามตารางข้อ 1 ของ รายการความลับ.md (ใบก่อน 6 พ.ย. 2569 มี 5 ไฟล์)"
else
  DEST=$(mktemp -d)
  echo "— ใส่รหัสผ่าน —"
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "$file" | LC_ALL=en_US.UTF-8 tar xzf - -C "$DEST"
  chmod -R go-rwx "$DEST"
  echo
  echo "แกะไว้ที่ $DEST"
  echo "★★ ตอนนี้ความลับนอนเป็นข้อความเปล่าอยู่บนดิสก์ — ใช้เสร็จลบทันที:"
  echo "    rm -rf $DEST"
fi
