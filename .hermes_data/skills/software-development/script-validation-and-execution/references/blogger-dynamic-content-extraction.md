# Case: Extracting content from Blogger/Blogspot dynamic pages

Date: 2026-06-29

## What happened

User asked to extract a Maithili song from `https://mithiladharohar.blogspot.com/2018/11/naina-jogeen-kaal-maithili-geet.html`. Standard `web_extract` only returned the page chrome (nav, sidebar, footer) — not the post body content, which is loaded dynamically via JavaScript.

## Technique that worked

Since `web_extract` couldn't render JS, raw HTML was fetched via `curl` and the post content was located by finding the `<div class="post-hentry">` marker (Blogger's standard class for the main post container):

```bash
curl -sL "<url>" | python3 -c "
import sys, re, html as h
raw = sys.stdin.read()
# Remove scripts and styles
raw = re.sub(r'<script[^>]*>.*?</script>', '', raw, flags=re.DOTALL)
raw = re.sub(r'<style[^>]*>.*?</style>', '', raw, flags=re.DOTALL)
# Find the post content area (Blogger-specific class)
idx = raw.find('post-hentry')
chunk = raw[idx:idx+20000]
# Convert to clean text
text = re.sub(r'<br\s*/?>', '\n', chunk)
text = re.sub(r'<[^>]+>', '', text)
text = h.unescape(text)
text = re.sub(r'\n{3,}', '\n\n', text)
print(text.strip())
"
```

## Alternative Blogger content markers

If `post-hentry` doesn't exist, try searching for these in order:
1. `class="post-body` (older Blogger templates)
2. `class="entry-content`
3. `class="article-content`
4. Fall back to: find all text blocks with substantial Devanagari/non-Latin content and sort by length

## Pattern for Devanagari/Hindi/Maithili content extraction

When extracting Indic-language content from JS-rendered pages:

```python
# Find text blocks with >30 Devanagari characters
text_blocks = re.findall(r'>([^<]+)<', raw_clean)
for block in text_blocks:
    dev_count = sum(1 for c in block if '\u0900' <= c <= '\u097F')
    devanagari_blocks = [b for b in text_blocks if sum(1 for c in b if '\u0900' <= c <= '\u097F') > 30]
# Sort by length — songs/articles are usually the longest blocks
devanagari_blocks.sort(key=len, reverse=True)
```

## Lesson

When `web_extract` returns page chrome but not body content, the site likely loads content via JS. Blogger/Blogspot sites put the actual post in a div identifiable by class names like `post-hentry`, `post-body`, or `entry-content`. Combined with HTML entity unescaping (`html.unescape`) and Devanagari character counting, you can reliably extract the content.
