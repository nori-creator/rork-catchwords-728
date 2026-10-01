// SwiftUI shader effects (iOS 17+): used with .colorEffect / .layerEffect.
// Compiled into the app's default Metal library; called as ShaderLibrary.<name>.
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float valueNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float a = hash21(i), b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1)), d = hash21(i + float2(1, 1));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

/// Background dissolve: the photo breaks into glowing dust from the top down.
/// progress 0 = untouched, 1 = gone. `size` is the view size in points.
[[ stitchable ]] half4 dissolve(float2 position, half4 color, float2 size, float progress) {
    float2 uv = position / max(size, float2(1));
    float n = valueNoise(uv * 16.0) * 0.65 + valueNoise(uv * 60.0) * 0.35;
    float front = progress * 1.35 - 0.2;
    float d = (n * 0.55 + uv.y * 0.45) - front;
    if (d < 0.0) { return half4(0.0); }
    float glow = smoothstep(0.07, 0.0, d);
    half3 ember = half3(0.62, 0.95, 1.0) * color.a;
    half3 rgb = mix(color.rgb, ember * 1.4h, half(glow));
    return half4(rgb, color.a);
}

/// Sticker outline traced around a cut-out subject (transparent background).
/// - progress: 0→1 how much of the outline is drawn, going round from the top (like scissors).
/// - width: outline width in points. - solid: 0 = glowing trace, 1 = plain white sticker edge.
[[ stitchable ]] half4 outline(float2 position, SwiftUI::Layer layer, float2 size, float progress, float width, float solid) {
    half4 here = layer.sample(position);
    float outside = 0.0;
    for (int i = 0; i < 16; i++) {
        float a = float(i) / 16.0 * 6.2831853;
        float2 o = float2(cos(a), sin(a)) * width;
        outside = max(outside, float(layer.sample(position + o).a));
    }
    float ring = saturate(outside - float(here.a));
    if (ring <= 0.001) { return here; }

    float2 c = size * 0.5;
    float2 v = position - c;
    // Angle measured clockwise from 12 o'clock, 0…1.
    float ang = fract((atan2(v.x, -v.y) / 6.2831853) + 1.0);
    float drawn = step(ang, progress);
    // Bright "blade" at the head of the trace.
    float head = exp(-pow((ang - progress) * 40.0, 2.0)) * (1.0 - solid);

    half3 trace = mix(half3(0.55, 0.93, 1.0), half3(1.0), half(solid));
    float alpha = ring * max(drawn, float(head));
    half3 rgb = trace * half(alpha) + half3(1.0) * half(head * ring);
    // Composite the ring under the subject (premultiplied).
    return half4(rgb, half(alpha)) * (1.0h - here.a) + here;
}
