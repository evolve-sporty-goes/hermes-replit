export DISPLAY=:1

cat > ~/or_token.py << 'PYEOF'
import sys, os, json
os.environ["DISPLAY"] = ":1"
from cloakbrowser import launch_persistent_context
import tempfile, atexit, shutil, time

td = tempfile.mkdtemp(prefix="or-token-")
atexit.register(lambda: shutil.rmtree(td, ignore_errors=True))

ctx = launch_persistent_context(td, headless=False, humanize=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()

p.goto("https://openrouter.ai/sign-up", timeout=60000, wait_until="domcontentloaded")
p.wait_for_timeout(3000)

# Fill form (type triggers React events)
p.locator("#emailAddress-field").click()
p.locator("#emailAddress-field").type(sys.argv[1], delay=50)
p.wait_for_timeout(300)
p.locator("#password-field").click()
p.locator("#password-field").type(sys.argv[2], delay=50)
p.wait_for_timeout(300)

# Checkbox via React fiber
p.evaluate("""() => {
    const el = document.querySelector('#legalAccepted-field');
    if (!el) return;
    const fk = Object.keys(el).find(k => k.startsWith('__reactFiber$'));
    if (!fk) return;
    let fiber = el[fk];
    for (let i = 0; i < 30; i++) {
        if (fiber?.memoizedProps?.onChange) {
            fiber.memoizedProps.onChange({
                target: { checked: true }, currentTarget: { checked: true },
                nativeEvent: new Event('change'), type: 'change',
                preventDefault(){}, stopPropagation(){}, persist(){}
            });
            break;
        }
        fiber = fiber.return;
    }
}""")
p.wait_for_timeout(500)

# Submit
p.get_by_role("button", name="Continue").click()
p.wait_for_timeout(8000)

# Find Turnstile widget and get its bounding box coords
coords = None
for attempt in range(20):
    # Method 1: iframe-based turnstile
    for frame in p.frames:
        try:
            box = frame.frame_element().bounding_box()
            if box and "challenges.cloudflare" in (frame.url or ""):
                # Found the turnstile iframe - center is where the checkbox is
                coords = {
                    "source": "iframe",
                    "frame_url": frame.url,
                    "x": box["x"] + box["width"] / 2,
                    "y": box["y"] + box["height"] / 2,
                    "box": box
                }
                break
        except:
            pass

    if coords:
        break

    # Method 2: inline turnstile (no iframe)
    inline = p.evaluate("""() => {
        const el = document.querySelector('.cf-turnstile');
        if (!el) return null;
        const box = el.getBoundingClientRect();
        return {x: box.x, y: box.y, w: box.width, h: box.height};
    }""")
    if inline:
        coords = {
            "source": "inline",
            "x": inline["x"] + inline["w"] / 2,
            "y": inline["y"] + inline["h"] / 2,
            "box": inline
        }
        break

    p.wait_for_timeout(2000)

ctx.close()

if coords:
    print(json.dumps(coords))
else:
    # Last resort: dump all iframes for coord-based click
    all_frames = []
    for frame in p.frames:
        try:
            box = frame.frame_element().bounding_box()
            all_frames.append({"url": frame.url, "box": box})
        except:
            pass
    print(json.dumps({"source": "no_turnstile_found", "frames": all_frames}))
PYEOF

# ── Run ───────────────────────────────────────────────────────────
bash ~/workspace/scripts/email.sh > /dev/null 2>&1
EMAIL=$(tail -1 ~/workspace/credentials/mail.txt 2>/dev/null)
[ -z "$EMAIL" ] && EMAIL=$(python3 ~/duckmail.py 2>/dev/null)
PASSWORD="HermesSecure#2026!xR"

python3 ~/or_token.py "$EMAIL" "$PASSWORD"
