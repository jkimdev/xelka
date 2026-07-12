//
//  Dither.metal
//  xelka
//
//  A Core Image general kernel that applies ordered (Bayer 4x4) dithering per
//  art-block, before the palette LUT snaps colors. This mirrors the CPU engine's
//  `orderedDither` so the live preview matches what still capture produces.
//
//  It's a general `CIKernel` (not a color kernel) because it reads the output
//  coordinate via `dest.coord()` to place the Bayer pattern. Built via the
//  target's `-fcikernel` / `-cikernel` flags, loaded from default.metallib.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

// `blockSize` is the art-pixel size in image pixels; `spread` is the dither
// strength. Offset per block matches the engine: (bayer/16 - 0.5) * spread.
extern "C" float4 orderedDither(coreimage::sampler src,
                                float blockSize,
                                float spread,
                                coreimage::destination dest) {
    const float bayer[16] = {
         0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
        12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
         3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
        15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
    };
    float4 s = src.sample(src.coord()); // color at this output pixel (1:1)
    float bs = max(blockSize, 1.0);
    float2 p = dest.coord();
    int bx = int(floor(p.x / bs));
    int by = int(floor(p.y / bs));
    int idx = (by & 3) * 4 + (bx & 3);
    float t = (bayer[idx] - 0.5) * spread;
    float3 rgb = clamp(s.rgb + t, 0.0, 1.0);
    return float4(rgb, s.a);
}
