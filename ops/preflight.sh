#!/bin/sh
# ตรวจก่อนทำใบใหม่ — ★ รันอันนี้ก่อน seal.sh ทุกครั้ง
#
# เหตุผล: ถ้าต้นทางไฟล์ไหนหาย เราจะได้ใบที่ "ดูเหมือนสำเร็จแต่ขาดไฟล์"
# ซึ่งรู้ตัวตอนกู้ระบบจริงคือสายไปแล้ว
set -u
. "$(dirname "$0")/lib.sh"
box_required

ok=0
have() { if [ -f "$1" ]; then echo "มี     $1"; else echo "ไม่พบ  $1"; ok=1; fi; }

echo "— ต้นทางบนเครื่องนี้ —"
have "$APP/.env"
have "$APP/weather/.env"
have "$NR/flows_cred.json"
have "$NR/settings.js"

echo "— ต้นทางบนกล่อง —"
if out=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$BOX" \
  "for f in '$BOX_ENV' '$BOX_PW'; do [ -f \"\$f\" ] && echo \"มี     \$f\" || echo \"ไม่พบ  \$f\"; done" 2>&1); then
  echo "$out"
  echo "$out" | grep -q "ไม่พบ" && ok=1
else
  echo "ต่อกล่องไม่ได้ — $out"
  ok=1
fi

echo "— ของค้างจากรอบก่อน (เคยเกิดจริง ดู วิธีเปิดและทำใบใหม่.md) —"
for p in "$HOME/swine-สำรอง" "$HOME/ส.tar.gz"; do
  if [ -e "$p" ]; then echo "ค้าง   $p  ← ลบก่อน"; ok=1; else echo "สะอาด $p"; fi
done

echo
if [ "$ok" = 0 ]; then
  echo "[ พร้อม ] ทำใบใหม่ได้ —  BOX=$BOX sh ops/seal.sh"
else
  echo "[ ยังไม่พร้อม ] แก้บรรทัดที่ขึ้น ไม่พบ / ค้าง ก่อน แล้วรันอันนี้ซ้ำ"
fi
exit "$ok"
