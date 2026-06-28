#!/usr/bin/env bash
# torbox-signup.sh — Create + verify TorBox account via Proton
set -euo pipefail
CRED="torbox_credentials.txt"
ANON=$(cat /home/runner/workspace/credentials/.supabase_anon_key)

# Step 1: Sign up
EMAIL=$(bash /home/runner/workspace/scripts/email.sh)
PW=$(python3 -c "import sys,os;sys.path.insert(0,os.path.expanduser('~'));import config;print(config.TORBOX_PASSWORD)")
echo "Signing up $EMAIL ..."
B=$(curl -s -X POST "https://db.torbox.app/auth/v1/signup" \
  -H 'Content-Type: application/json' \
  -H "apikey: $ANON" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")
E=$(echo "$B"|python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('msg',d.get('error_description','')))" 2>/dev/null||true)
[[ -n "$E" ]] && { echo "✗ $E"; exit 1; }
ID=$(echo "$B"|python3 -c "import sys,json;print(json.load(sys.stdin).get('id','?'))" 2>/dev/null||echo "?")
echo "✓ Signed up $EMAIL | $ID"

# Step 2: Verify via Proton
echo "Checking Proton ..."
VERIFY_URL=$(python3 - "$EMAIL" << 'PYEOF'
import sys,os,re
sys.path.insert(0,os.path.expanduser("~"))
from playwright.sync_api import sync_playwright
import importlib
if "config" in sys.modules: del sys.modules["config"]
C=importlib.import_module("config")
email=sys.argv[1]
CH="/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"
PR=os.path.expanduser("~/proton_profile")
url="NOT_FOUND"
with sync_playwright() as p:
 ctx=p.chromium.launch_persistent_context(PR,executable_path=CH,headless=True,args=["--no-sandbox","--disable-gpu"])
 pg=ctx.new_page()
 pg.goto("https://account.proton.me/login",timeout=60000); pg.wait_for_timeout(3000)
 logged_in=False
 try:
  if pg.locator("a:has-text('Mail')").is_visible(timeout=3000): logged_in=True
 except: pass
 if not logged_in:
  pg.locator("#username").fill(C.PROTON_USERNAME)
  pg.locator("#password").fill(C.PROTON_PASSWORD)
  pg.locator("button[type='submit']").click(); pg.wait_for_timeout(10000)
  pg.locator("a:has-text('Mail')").first.click(timeout=0); pg.wait_for_timeout(5000)
 pg.goto("https://mail.proton.me/u/0/inbox",timeout=30000); pg.wait_for_timeout(2000)
 for _ in range(7):
  try:
   pg.keyboard.press("/"); pg.wait_for_timeout(800)
   pg.keyboard.type(email,delay=20); pg.keyboard.press("Enter"); pg.wait_for_timeout(4000)
   items=pg.locator(".item-container,.message-item,[data-testid='message-item']")
   if items.count()>0: items.first.click(); pg.wait_for_timeout(2000); break
   pg.reload(); pg.wait_for_load_state("networkidle"); pg.wait_for_timeout(2000)
  except:
   try: pg.keyboard.press("Escape")
   except: pass
   pg.wait_for_timeout(2000)
 else:
  print("NOT_FOUND",end=""); ctx.close(); sys.exit(0)
 pg.wait_for_timeout(1500)
 for frame in pg.frames:
  try:
   for href in frame.eval_on_selector_all("a[href]","els=>els.map(e=>e.href)"):
    if ("verify" in href.lower() or "confirm" in href.lower()) and "torbox" in href.lower():
     url=href.replace("&amp;","&"); break
   if url!="NOT_FOUND": break
  except: continue
 if url=="NOT_FOUND":
  html=""
  for f in pg.frames:
   try: html+=f.content()+"\n"
   except: pass
  m=re.search(r'https://db\.torbox\.app/auth/v1/verify[^\s"\'<>]*',html)
  if m: url=m.group(0).replace("&amp;","&")
 ctx.close()
print(url,end="")
PYEOF
)

# Step 3: Write credentials

  echo "email=$EMAIL" >> "$CRED"
  echo "password=$PW" >> "$CRED"
  echo "user_id=$ID" >> "$CRED"
  echo "magic_link=$VERIFY_URL" >> "$CRED"
  echo "" >> "$CRED"


  echo "✓ Verified"
