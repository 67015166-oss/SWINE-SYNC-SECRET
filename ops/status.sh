#!/bin/sh
# สภาพของรีโปนี้ — มีก้อนไหม ใบไหนใหม่สุด และ ★ ก้อนเก่ากว่าต้นทางหรือเปล่า
#
# ★★ ข้อสุดท้ายสำคัญที่สุด: ก้อนที่เก่ากว่า .env ปัจจุบันคือก้อนที่กู้แล้วได้ระบบ
#   ที่ขาดค่า **โดยไม่มีอะไรฟ้อง** เกิดมาแล้วสองครั้ง
#   (ตั้ง BOX= ด้วยถ้าอยากให้ตรวจ .env ของกล่องให้)
set -u
. "$(dirname "$0")/lib.sh"

echo "— ก้อนในรีโปนี้ —"
if ls -1 "$BUNDLES"/*.tar.gz.enc >/dev/null 2>&1; then
  for f in "$BUNDLES"/*.tar.gz.enc; do echo "  $(basename "$f")  $(du -h "$f" | cut -f1)"; done
else
  echo "  (ยังไม่มี) ← รีโปนี้ยังไม่ครบ ทำใบใหม่ด้วย ops/seal.sh"
  exit 1
fi

newest=$(newest_bundle)
# วันที่ในชื่อไฟล์เป็น พ.ศ. — แปลงเป็น ค.ศ. เพื่อเทียบกับวันแก้ไขของต้นทาง
be=$(basename "$newest" | sed -E 's/[^0-9]*([0-9]{4})-([0-9]{2})-([0-9]{2}).*/\1 \2 \3/')
set -- $be
sealed="$(( $1 - 543 ))-$2-$3"
echo
echo "ใบล่าสุด: $(basename "$newest")  (ปิดผนึก $sealed)"

echo
echo "— ต้นทางถูกแก้หลังจากนั้นหรือเปล่า —"
stale=0
check() {
  [ -f "$2" ] || { echo "  $1 — ไม่พบไฟล์"; return; }
  d=$(date -r "$2" +%Y-%m-%d 2>/dev/null || stat -c %y "$2" | cut -d' ' -f1)
  if [ "$d" \> "$sealed" ]; then echo "  $1 — $d  ★ ใหม่กว่าก้อน"; stale=1
  else echo "  $1 — $d"; fi
}
check ".env (เครื่องนี้)" "$APP/.env"
check "weather/.env"       "$APP/weather/.env"
check "flows_cred.json"    "$NR/flows_cred.json"
check "settings.js"        "$NR/settings.js"

if [ -n "${BOX:-}" ]; then
  d=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$BOX" "date -r '$BOX_ENV' +%Y-%m-%d" 2>/dev/null || echo "")
  if [ -n "$d" ]; then
    if [ "$d" \> "$sealed" ]; then echo "  .env (กล่อง) — $d  ★ ใหม่กว่าก้อน"; stale=1
    else echo "  .env (กล่อง) — $d"; fi
  else
    echo "  .env (กล่อง) — ต่อกล่องไม่ได้ ยังไม่รู้"
  fi
else
  echo "  .env (กล่อง) — ไม่ได้ตรวจ (ตั้ง BOX= ถ้าอยากให้ตรวจ)"
fi

echo
if [ "$stale" = 0 ]; then
  echo "[ ดี ] ก้อนใหม่กว่าทุกต้นทางที่ตรวจได้"
else
  echo "[ ต้องทำใบใหม่ ] มีต้นทางที่ถูกแก้หลังปิดผนึก — กู้ตามใบนี้จะได้ระบบที่ขาดค่า"
fi
exit "$stale"
