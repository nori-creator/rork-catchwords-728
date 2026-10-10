# The photo's real structure for P3 (in the app: Vision VNDetectContoursRequest / Core Image). python3 masks/tools/edges.py
import cv2, numpy as np, json
g = cv2.cvtColor(cv2.imread('assets/photo_1080.jpg'), cv2.COLOR_BGR2GRAY); g1 = cv2.GaussianBlur(g, (0, 0), 1.6)
e = np.maximum(cv2.Canny(g1, 40, 110), (cv2.Canny(cv2.GaussianBlur(g, (0, 0), 3.2), 20, 60) * .7).astype(np.uint8))
gx = cv2.Sobel(g1, cv2.CV_32F, 1, 0); gy = cv2.Sobel(g1, cv2.CV_32F, 0, 1); mag = np.sqrt(gx * gx + gy * gy); mag = np.clip(mag / np.percentile(mag, 99), 0, 1)
a = (e > 0).astype(np.float32) * (.35 + .65 * mag); a = cv2.GaussianBlur(a, (0, 0), .7)
a = np.maximum(a, cv2.dilate(a, np.ones((2, 2), np.uint8)) * .85); a = np.clip(cv2.GaussianBlur(a, (0, 0), .8) * 1.6 * 1.3, 0, 1)
rgba = np.zeros((*a.shape, 4), np.uint8); rgba[..., :3] = 255; rgba[..., 3] = (a * 255).astype(np.uint8); cv2.imwrite('masks/edges.png', rgba)
objs = np.zeros(a.shape, np.float32); kp = {}
for k in ['cup', 'scooter', 'sign']:
    m = cv2.imread(f'masks/{k}.png', 0); objs = np.maximum(objs, cv2.dilate(m, np.ones((9, 9), np.uint8)).astype(np.float32) / 255)
    pts = cv2.goodFeaturesToTrack(g1, maxCorners=70 if k == 'cup' else 45, qualityLevel=.02, minDistance=22, mask=(m > 127).astype(np.uint8))
    kp[k] = [] if pts is None else [[int(x), int(y)] for x, y in pts[:, 0, :]]
ro = rgba.copy(); ro[..., 3] = (ro[..., 3] * objs).astype(np.uint8); cv2.imwrite('masks/edges_obj.png', ro)
json.dump(kp, open('masks/keypoints.json', 'w')); print('edges + keypoints ok')
