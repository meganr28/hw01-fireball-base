#version 300 es
precision highp float;
precision highp int;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform int u_Time;
uniform float u_NoiseScale;

in vec2 fs_Pos;
out vec4 out_Col;

const float PI = 3.1415926535897932384626433832795;

// Noise function implementation based on CIS 560 and CIS 566 Slides - "Noise Functions"
float noise2D(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise3D(vec3 p) 
{
    return fract(sin((dot(p, vec3(127.1, 311.7, 191.999)))) * 43758.5453);
}

float cosineInterpolate(float a, float b, float t)
{
    float cos_t = (1.f - cos(t * PI)) * 0.5f;
    return mix(a, b, cos_t);
}

float interpolateNoise3D(float x, float y, float z)
{
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);
    int intZ = int(floor(z));
    float fractZ = fract(z);

    float v1 = noise3D(vec3(intX, intY, intZ));
    float v2 = noise3D(vec3(intX + 1, intY, intZ));
    float v3 = noise3D(vec3(intX, intY + 1, intZ));
    float v4 = noise3D(vec3(intX + 1, intY + 1, intZ));
    float v5 = noise3D(vec3(intX, intY, intZ + 1));
    float v6 = noise3D(vec3(intX + 1, intY, intZ + 1));
    float v7 = noise3D(vec3(intX, intY + 1, intZ + 1));
    float v8 = noise3D(vec3(intX + 1, intY + 1, intZ + 1));

    float i1 = cosineInterpolate(v1, v2, fractX);
    float i2 = cosineInterpolate(v3, v4, fractX);
    float mix1 = cosineInterpolate(i1, i2, fractY);
    float i3 = cosineInterpolate(v5, v6, fractX);
    float i4 = cosineInterpolate(v7, v8, fractX);
    float mix2 = cosineInterpolate(i3, i4, fractY);
    return cosineInterpolate(mix1, mix2, fractZ);
}

float fbm3D(vec3 p)
{
    float total = 0.f;
    float persistence = 0.5f;
    int octaves = 8;

    for (int i = 1; i < octaves; ++i)
    {
        float freq = pow(2.f, float(i));
        float amp = pow(persistence, float(i));

        total += amp * interpolateNoise3D(p.x * freq, p.y * freq, p.z * freq);
    }

    return total;
}

float star(vec2 uv)
{
    // Distance from fragment to screen center
    float dist = length(uv);

    // Compute color
    float color = 0.02 / dist;
    color *= smoothstep(1.0, 0.2, dist);

    return color;
}

float halo(vec2 uv)
{
    // Distance from fragment to screen center
    float dist = length(uv);

    // Compute color
    // TODO: change second number to scale with noise offset and camera zoom
    // float color = 3.0 - (mix(12.0, 6.0, u_NoiseScale) * length(2.5 * uv));
    float color = u_NoiseScale * 0.1 / pow(dist, 1.2);
    color = max(0.0, color);

    return color;
}

void main() {
    // Bring coordinate to the middle of the screen
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_Dimensions.xy) / u_Dimensions.y;
    
    vec3 haloColor = vec3(0.0);  
    vec3 starColor = vec3(0.0);
    vec3 color = vec3(0.0);
    float time = float(u_Time) / 1000.f;
    
    float halo = halo(uv);
    haloColor += vec3(halo, pow(halo, 2.0), pow(halo, 10.0) * 0.8);
    
    //uv *= 20.0;
    for (float i = 0.0; i < 1.; i += 1.0 / 4.0) {
        float depth = fract(i + time);
        float scale = mix(20.0, 0.5, depth);
        vec2 gridPos = fract(uv * scale + i * 647.) - 0.5;
        vec2 gridId = floor(uv * scale + i * 247.);

        // Check neighboring cells for contribution
        for (int y = -1; y <= 1; ++y) {
            for (int x = -1; x <= 1; ++x) {
                vec2 idOffset = vec2(x, y);
                float r = noise2D(gridId + idOffset);
                vec2 uvOffset = vec2(r, fract(r * 48.0));
                float glow = star(gridPos - idOffset - uvOffset + 0.5);
                float size = fract(r * 146.86);
                vec3 sColor = 0.5 * (sin(vec3(0.2, 0.3, 0.8) * fract(r * 546.86) * PI) + 1.0);
                sColor *= vec3(1.0, 0.7, 1.0 * size);
                starColor += sColor * size * glow * depth;
            }
        }
    }


    color = haloColor + starColor;
    //color.rg = gridPos;
    out_Col = vec4(color, 1.0);
}
