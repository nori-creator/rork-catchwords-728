"""Production latency benchmark for the catch flow, called the way the iOS app calls it (LATENCY.md 0a).

  a guest session (the same anonymous sign-in as the pre-signup tutorial) → POST <app>/api/native-fn
    suggestWords   {imageBase64: 768 px JPEG q0.8 data URL, targetLanguage}
    checkOwnedWord {headword, language}                            (the check iOS waited for after a tap)
    generateCard   {headword, targetLanguage, hintCategory}        (what iOS waited for on 「図鑑に追加」)
Per call: status, time to the response headers, total time, size. The server's own split is in public.ai_runs for the
printed guest user id (capture_suggest: ms / ai_ms / pre_ms / cap_ms; card_generate: ms / ai_ms / attempts).

  WEB_REPO=/path/to/Lovable-catch-words-app python3 latency_bench.py https://catchwords.lovable.app out.json [--cards]

Reads the public Supabase URL and publishable key from the web repo's .env (never printed). The photos are made from
images already in the two repos (`make_photos`). A guest may call suggestWords 10 times a day: one run = 6 photos.
"""
import base64, io, json, os, statistics, sys, time
import requests
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WEB = os.environ.get('WEB_REPO', os.path.join(HERE, '..', '..', '..', '..', '..', 'Lovable-catch-words-app'))
PHOTOS = {
    'street_bubbletea': os.path.join(HERE, '..', 'film', 'assets', 'photo_1080.jpg'),
    'cafe': os.path.join(WEB, 'public', 'first-catch-cafe.webp'),
    'cat': os.path.join(WEB, 'public', 'first-catch-cat.webp'),
    'flower': os.path.join(WEB, 'public', 'first-catch-flower.webp'),
    'santorini': os.path.join(WEB, 'public', 'first-catch-ready.webp'),
}

def make_photos():
    out = {}
    for k, p in PHOTOS.items():
        if not os.path.exists(p): print('skip (missing):', p); continue
        im = Image.open(p).convert('RGB'); w, h = im.size; s = min(1, 768 / max(w, h))
        small = im.resize((round(w * s), round(h * s)), Image.LANCZOS); b = io.BytesIO(); small.save(b, 'JPEG', quality=80)
        out[k] = 'data:image/jpeg;base64,' + base64.b64encode(b.getvalue()).decode()
    return out

def env():
    e = {}
    for line in open(os.path.join(WEB, '.env')).read().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            k, v = line.split('=', 1); e[k.strip()] = v.strip().strip('"')
    return e['VITE_SUPABASE_URL'], e['VITE_SUPABASE_PUBLISHABLE_KEY']

def guest(url, key):
    r = requests.post(f'{url}/auth/v1/signup', headers={'apikey': key, 'Content-Type': 'application/json'}, json={}, timeout=20)
    r.raise_for_status(); d = r.json(); return d['access_token'], d['user']['id']

def call(s, app, token, fn, data, timeout):
    t0 = time.perf_counter()
    try:
        r = s.post(f'{app}/api/native-fn', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
                   data=json.dumps({'fn': fn, 'data': data}), timeout=timeout, stream=True)
        head = time.perf_counter() - t0; body = r.content; total = time.perf_counter() - t0
        try: j = json.loads(body)
        except Exception: j = None
        return {'fn': fn, 'status': r.status_code, 'head_ms': round(head * 1000), 'total_ms': round(total * 1000), 'bytes': len(body),
                'error': (j or {}).get('error') if r.status_code != 200 else None}, j
    except requests.exceptions.RequestException as e:
        return {'fn': fn, 'status': 0, 'total_ms': round((time.perf_counter() - t0) * 1000), 'error': type(e).__name__}, None

def main():
    app, out_path, cards = sys.argv[1].rstrip('/'), sys.argv[2], '--cards' in sys.argv
    url, key = env(); photos = make_photos(); token, uid = guest(url, key); s = requests.Session(); rows = []
    print('guest user id:', uid, flush=True)
    for i, (name, img) in enumerate(photos.items()):
        r, j = call(s, app, token, 'suggestWords', {'imageBase64': img, 'targetLanguage': 'zh-TW'}, 60)
        sug = ((j or {}).get('result') or {}).get('suggestions') or []
        rows.append({'photo': name, 'n': len(sug), **r}); print(json.dumps(rows[-1], ensure_ascii=False), flush=True)
        if i < 2 and sug:
            hw = sug[0].get('headword')
            r2, _ = call(s, app, token, 'checkOwnedWord', {'headword': hw, 'language': 'zh-TW'}, 20)
            rows.append({'photo': name, **r2}); print(json.dumps(rows[-1], ensure_ascii=False), flush=True)
            if cards:
                r3, _ = call(s, app, token, 'generateCard', {'headword': hw, 'targetLanguage': 'zh-TW', 'hintCategory': sug[0].get('category_key')}, 200)
                rows.append({'photo': name, **r3}); print(json.dumps(rows[-1], ensure_ascii=False), flush=True)
    json.dump({'app': app, 'guest_user_id': uid, 'rows': rows}, open(out_path, 'w'), ensure_ascii=False, indent=1)
    for fn in ['suggestWords', 'checkOwnedWord', 'generateCard']:
        v = sorted(r['total_ms'] for r in rows if r['fn'] == fn and r['status'] == 200)
        if v: print(f'{fn}: n {len(v)}  median {statistics.median(v):.0f} ms  min {v[0]}  max {v[-1]}')

if __name__ == '__main__':
    main()
