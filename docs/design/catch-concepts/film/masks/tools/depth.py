# Depth of the photo for P2 (in the app: the capture's depth data, or Apple's Core ML "Depth Anything V2").
# Here: Depth Anything ViT-S (ONNX, github.com/fabio-sim/Depth-Anything-ONNX releases).  python3 masks/tools/depth.py MODEL.onnx
import sys, numpy as np, cv2, onnxruntime as ort
sess = ort.InferenceSession(sys.argv[1], providers=['CPUExecutionProvider']); name = sess.get_inputs()[0].name
img = cv2.cvtColor(cv2.imread('assets/photo_1080.jpg'), cv2.COLOR_BGR2RGB).astype(np.float32) / 255; H0, W0 = img.shape[:2]
th = 518 * 2 // 14 * 14; tw = int(round(th * W0 / H0 / 14)) * 14
x = (cv2.resize(img, (tw, th), interpolation=cv2.INTER_CUBIC) - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
d = sess.run(None, {name: x.transpose(2, 0, 1)[None].astype(np.float32)})[0][0]
d = d[0] if d.ndim == 3 else d
d = cv2.resize(d, (W0, H0), interpolation=cv2.INTER_CUBIC); d = (d - d.min()) / (d.max() - d.min())   # 1 = near
cv2.imwrite('masks/depth.png', (d * 255).astype(np.uint8)); print('depth ok')
