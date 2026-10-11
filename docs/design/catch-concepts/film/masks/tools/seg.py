# Object masks for the scan films (what Vision's instance masks give in the app). Run from film/:  python3 masks/tools/seg.py
# 1) the cup (+ straw) stands in front of everything: its precise contour (assets/contours.json) is the cup mask and is
#    inpainted away so the things behind it can be segmented; 2) GrabCut seeded by the rough contour of each thing;
#    the scooter excludes foliage (green), the plant keeps it. Writes masks/{cup,scooter,plant,sign}.png (1080x2340, L).
import json, numpy as np, cv2
ph = cv2.imread('assets/photo_1080.jpg'); H, W = ph.shape[:2]
C = json.load(open('assets/contours.json'))
def poly(pts):
    m = np.zeros((H, W), np.uint8); cv2.fillPoly(m, [np.array(pts, np.int32)], 255); return m
cup = poly(C['cup']); cupd = cv2.dilate(cup, np.ones((15, 15), np.uint8))
clean = cv2.inpaint(ph, cupd, 9, cv2.INPAINT_TELEA)
hsv = cv2.cvtColor(ph, cv2.COLOR_BGR2HSV); green = ((hsv[..., 0] > 30) & (hsv[..., 0] < 95) & (hsv[..., 1] > 70) & (hsv[..., 2] > 40)).astype(np.uint8)
boxes = {'scooter': (0, 430, 560, 1240), 'plant': (480, 420, 900, 1010), 'sign': (660, 850, 980, 1400)}
for k, (x0, y0, x1, y1) in boxes.items():
    rough = poly(C[k]); gm = np.full((H, W), cv2.GC_BGD, np.uint8)
    gm[cv2.dilate(rough, np.ones((61, 61), np.uint8)) > 0] = cv2.GC_PR_BGD; gm[rough > 0] = cv2.GC_PR_FGD
    if k == 'scooter': gm[(green > 0) & (rough > 0)] = cv2.GC_BGD
    if k == 'plant': gm[(green > 0) & (rough > 0)] = cv2.GC_FGD
    gm[cupd > 0] = cv2.GC_BGD
    bg, fg = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    sub = (slice(y0, y1), slice(x0, x1)); g2 = gm[sub].copy()
    cv2.grabCut(clean[sub].copy(), g2, None, bg, fg, 10, cv2.GC_INIT_WITH_MASK)
    B = np.zeros((H, W), np.uint8); B[sub] = np.where((g2 == cv2.GC_FGD) | (g2 == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
    B = cv2.morphologyEx(B, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8)); B = cv2.morphologyEx(B, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(B); keep = np.zeros_like(B)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] > 2500: keep[lab == i] = 255
    keep[cupd > 0] = 0
    cv2.imwrite(f'masks/{k}.png', cv2.GaussianBlur(keep, (0, 0), .9))
cv2.imwrite('masks/cup.png', cv2.GaussianBlur(cup, (0, 0), .9))
# precise outlines (the light of P1 runs along these)
out = {}
for k in ['cup', 'scooter', 'plant', 'sign']:
    _, b = cv2.threshold(cv2.imread(f'masks/{k}.png', 0), 127, 255, cv2.THRESH_BINARY)
    cs = sorted([c for c in cv2.findContours(b, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)[0] if cv2.contourArea(c) > 1500], key=cv2.contourArea, reverse=True)
    out[k] = [cv2.approxPolyDP(c, 0.9, True)[:, 0, :].tolist() for c in cs]
json.dump(out, open('masks/outlines.json', 'w'))
print('masks + outlines ok')
