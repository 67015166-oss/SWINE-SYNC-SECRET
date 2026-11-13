#!/bin/sh
# เปิดก้อน — ค่าตั้งต้นคือ "ดูชื่อไฟล์ข้างในเท่านั้น ไม่แกะออกมา"
#
#   sh ops/verify.sh                 ดูว่ามีไฟล์อะไรข้างใน (ปลอดภัยที่สุด)
#   sh ops/verify.sh --extract       แกะออกมาจริงตอนกู้ระบบ
#   sh ops/verify.sh --expect 6      ล้มถ้าไม่ได้ครบ 6 ไฟล์ (ship.sh ใช้ตัวนี้)
#   sh ops/verify.sh <ไฟล์>          เลือกใบเอง (ไม่ใส่ = ใบล่าสุด)
#
# ★★ ต้องนับจำนวนไฟล์ที่เปิดได้ ไม่ใช่ดูแค่ว่าคำสั่งล้มหรือไม่ล้ม
#   เพราะ `openssl | tar` คืนสถานะของ tar — รหัสผิดแล้ว tar ได้ท่อเปล่า
#   มันจึง "สำเร็จโดยไม่มีไฟล์" และสคริปต์ที่เชื่อสถานะจะเดินต่อเหมือนผ่าน
#   (เจอจริงตอนทดสอบ ship.sh 6 พ.ย. 2569 — เกือบ push ใบที่ยังไม่ได้ตรวจ)
set -eu
. "$(dirname "$0")/lib.sh"

extract=0
expect=0
file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --extract) extract=1 ;;
    --expect)  shift; expect="${1:-0}" ;;
    *)         file="$1" ;;
  esac
  shift
done

[ -n "$file" ] || file=$(newest_bundle || true)
[ -n "$file" ] || { echo "ยังไม่มีก้อนใน $BUNDLES — ทำใบใหม่ด้วย ops/seal.sh"; exit 1; }

echo "ใบที่เปิด: $file"
head -c 8 "$file" | grep -q "Salted__" || { echo "ไม่ใช่ไฟล์เข้ารหัสของเรา"; exit 1; }

open_bundle() {
  if [ -n "$PASSFILE" ]; then
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "$file" -pass "file:$PASSFILE"
  else
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "$file"
  fi
}

if [ "$extract" = 0 ]; then
  [ -n "$PASSFILE" ] || echo "— ใส่รหัสผ่าน —"
  list=$(open_bundle | LC_ALL=en_US.UTF-8 tar tzf - || true)
  n=$(printf '%s\n' "$list" | grep -vcE '^(\./)?$' || true)
  if [ "$n" -eq 0 ]; then
    echo "[ เปิดไม่ได้ ] รหัสผิด หรือไฟล์เสีย — ไม่มีไฟล์ไหนเปิดออกมาเลย"
    exit 1
  fi
  printf '%s\n' "$list" | grep -vE '^(\./)?$' | sed 's/^/  /'
  echo
  echo "เปิดได้ $n ไฟล์"
  if [ "$expect" -gt 0 ] && [ "$n" -ne "$expect" ]; then
    echo "[ ไม่ครบ ] ควรได้ $expect ไฟล์ — ดูตารางข้อ 1 ของ รายการความลับ.md"
    exit 1
  fi
  [ "$expect" -gt 0 ] || echo "★ ใบที่ทำตั้งแต่ 6 พ.ย. 2569 ต้องมี 6 ไฟล์ · ใบเก่ากว่านั้นมี 5"
else
  DEST=$(mktemp -d)
  [ -n "$PASSFILE" ] || echo "— ใส่รหัสผ่าน —"
  open_bundle | LC_ALL=en_US.UTF-8 tar xzf - -C "$DEST" || true
  n=$(ls -1A "$DEST" | wc -l | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    rm -rf "$DEST"
    echo "[ เปิดไม่ได้ ] รหัสผิด หรือไฟล์เสีย — ไม่ได้แกะอะไรไว้"
    exit 1
  fi
  chmod -R go-rwx "$DEST"
  ls -1 "$DEST" | sed 's/^/  /'
  echo
  echo "แกะ $n ไฟล์ไว้ที่ $DEST"
  echo "★★ ตอนนี้ความลับนอนเป็นข้อความเปล่าอยู่บนดิสก์ — ใช้เสร็จลบทันที:"
  echo "    rm -rf $DEST"
fi
