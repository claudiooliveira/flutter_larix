#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct RotateParameters
{
    float2x2 scaleM;
    float2 offsetM;
};

struct PipParameters {
    uint4 mainRect;
    uint4 pipRect;
    RotateParameters mainTransform;
    RotateParameters pipTransform;
};

constant sampler kBilinearSampler(filter::linear,  coord::pixel, address::clamp_to_zero);

// Compute kernel
kernel void rotateShader(texture2d<half, access::sample>    source          [[ texture(0) ]],
                         texture2d<half, access::write>     destination     [[ texture(1) ]],
                          const device    RotateParameters& params          [[ buffer(0) ]],
                          uint2                             gid             [[thread_position_in_grid]])

{
    float2 samplingPos = params.offsetM + float2(gid) * params.scaleM;
    half4 output = source.sample(kBilinearSampler, samplingPos);
    
    destination.write(output, gid);
}

kernel void rotateMixShader(texture2d<half, access::sample>     source      [[ texture(0) ]],
                            texture2d<half, access::read>       overlay     [[ texture(1) ]],
                            texture2d<half, access::write>      destination [[ texture(2) ]],
                            const device    RotateParameters&   params      [[ buffer(0) ]],
                            uint2                               gid         [[thread_position_in_grid]])

{
    float2 samplingPos = params.offsetM + float2(gid) * params.scaleM;
    half4 output = source.sample(kBilinearSampler, samplingPos);
    if (!is_null_texture(overlay)) {
        half4 overlayPix = overlay.read(gid);
        output = mix(output, overlayPix, overlayPix.a);
    }
    
    destination.write(output, gid);
}


kernel void rotateMixDualShader(texture2d<half, access::sample>     main        [[ texture(0) ]],
                                texture2d<half, access::sample>     pip         [[ texture(1) ]],
                                texture2d<half, access::read>       overlay     [[ texture(2) ]],
                                texture2d<half, access::write>      destination [[ texture(3) ]],
                                const device    PipParameters&      params      [[ buffer(0) ]],
                                uint2                               gid         [[thread_position_in_grid]])

{
    
    half4 output = half4(0.0);
    if (gid.x >= params.pipRect.x && gid.x <= params.pipRect.z &&
        gid.y >= params.pipRect.y && gid.y <= params.pipRect.w) {
    
        float2 samplingPos = params.pipTransform.offsetM + float2(gid) * params.pipTransform.scaleM;
        output = pip.sample(kBilinearSampler, samplingPos);
    } else if (gid.x >= params.mainRect.x && gid.x <= params.mainRect.z &&
               gid.y >= params.mainRect.y && gid.y <= params.mainRect.w) {
          
       float2 samplingPos = params.mainTransform.offsetM + float2(gid) * params.mainTransform.scaleM;
       output = main.sample(kBilinearSampler, samplingPos);
    }
    if (!is_null_texture(overlay)) {
        half4 overlayPix = overlay.read(gid);
        output = mix(output, overlayPix, overlayPix.a);
    }
    
    destination.write(output, gid);
}


