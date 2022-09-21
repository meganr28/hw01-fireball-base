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

// Function to cycle layers
float sawtoothWave(float x, float freq, float amplitude)
{
    return (x * freq - floor(x * freq)) * amplitude;
}

// Noise and interpolation functions based on CIS 560 and CIS 566 Slides - "Noise Functions"
float noise2Df(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 noise2Dv( vec2 p ) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)),
                 dot(p, vec2(269.5,183.3))))
                 * 43758.5453);
}

float cosineInterpolate(float a, float b, float t)
{
    float cos_t = (1.f - cos(t * PI)) * 0.5f;
    return mix(a, b, cos_t);
}

float surflet(vec2 P, vec2 gridPoint) {
    // Compute falloff function by converting linear distance to a polynomial
    float distX = abs(P.x - gridPoint.x);
    float distY = abs(P.y - gridPoint.y);
    float tX = 1.0 - 6.0 * pow(distX, 5.f) + 15.0 * pow(distX, 4.f) - 10.0 * pow(distX, 3.f);
    float tY = 1.0 - 6.0 * pow(distY, 5.f) + 15.0 * pow(distY, 4.f) - 10.0 * pow(distY, 3.f);
    // Get the random vector for the grid point
    vec2 gradient = 2.f * noise2Dv(gridPoint) - vec2(1.f);
    // Get the vector from the grid point to P
    vec2 diff = P - gridPoint;
    // Get the value of our height field by dotting grid->P with our gradient
    float height = dot(diff, gradient);
    // Scale our height field (i.e. reduce it) by our polynomial falloff function
    return height * tX * tY;
}

float perlinNoise(vec2 uv) 
{
    float surfletSum = 0.f;
    // Iterate over the four integer corners surrounding uv
    for(int dx = 0; dx <= 1; ++dx) {
      for(int dy = 0; dy <= 1; ++dy) {
        surfletSum += surflet(uv, floor(uv) + vec2(dx, dy));
      }
    }
    return surfletSum;
}

float interpolateNoise2D(float x, float y) 
{
    // Get integer and fractional components of current position
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);

    // Get noise value at each of the 4 vertices
    float v1 = noise2Df(vec2(intX, intY));
    float v2 = noise2Df(vec2(intX + 1, intY));
    float v3 = noise2Df(vec2(intX, intY + 1));
    float v4 = noise2Df(vec2(intX + 1, intY + 1));

    // Interpolate in the X, Y directions
    float i1 = cosineInterpolate(v1, v2, fractX);
    float i2 = cosineInterpolate(v3, v4, fractX);
    return cosineInterpolate(i1, i2, fractY);
}

float fbm2D(vec2 p) 
{
    float total = 0.f;
    float persistence = 0.5f;
    int octaves = 8;

    for(int i = 1; i <= octaves; i++)
    {
        float freq = pow(2.f, float(i));
        float amp = pow(persistence, float(i));

        float perlin = (perlinNoise(vec2(p.x * freq, p.y * freq)));
        total += amp * (0.5 * (perlin + 1.0));
    }
    return total;
}

float cloud(vec2 uv)
{
    float fbm = fbm2D(uv) * 1.3 * (1.0 - abs(perlinNoise(0.9f * uv)));
    float color = pow(fbm, 3.0);
    return color;
}

float star(vec2 uv)
{
    // Distance from fragment to screen center
    float dist = length(uv);

    // Compute color
    float color = 0.02 / dist;
    color *= smoothstep(1.0, 0.2, dist);

    // Rays
    //color += 3.0 - abs(uv.x * uv.y * 200000.0);
    //color = max(0.0, color);

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
    vec3 cloudColor = vec3(0.0);

    vec3 color = vec3(0.0);
    float time = float(u_Time) / 1000.f;
    
    // Halo
    float halo = halo(uv);
    haloColor += vec3(halo, pow(halo, 2.0), pow(halo, 10.0) * 0.8);
    
    // Stars
    //uv *= 20.0;
    for (float i = 0.0; i < 1.; i += 1.0 / 4.0) {
        float depth = sawtoothWave(i + time, 1.0, 1.0);
        float scale = mix(20.0, 0.5, depth);
        vec2 gridPos = fract(uv * scale + i * 647.) - 0.5;
        vec2 gridId = floor(uv * scale + i * 247.);

        // Check neighboring cells for contribution
        for (int y = -1; y <= 1; ++y) {
            for (int x = -1; x <= 1; ++x) {
                vec2 idOffset = vec2(x, y);
                float r = noise2Df(gridId + idOffset);
                vec2 uvOffset = vec2(r, fract(r * 48.0));
                float glow = star(gridPos - idOffset - uvOffset + 0.5);
                float size = fract(r * 146.86);
                vec3 sColor = 0.5 * (sin(vec3(0.2, 0.3, 0.8) * fract(r * 546.86) * PI) + 1.0);
                sColor *= vec3(1.0, 0.7, 1.0 * size);
                starColor += sColor * size * glow * depth * smoothstep(1.0, 0.5, depth);
            }
        }
    }

    // Clouds
    for (float i = 0.0; i < 1.; i += 1.0 / 4.0) {
        float depth = sawtoothWave(i + time, 1.0, 1.0);
        float scale = mix(15.0, 0.1, depth);

        float fbm = cloud(uv * scale + i * 544.5);
        vec3 cColor = vec3(0.2 + fbm, 0.3, 0.8) * fract(i * 34.3);
        cloudColor += cColor * fbm * depth * smoothstep(1.0, 0.8, depth);
    }
    //cloudColor += vec3(0.2, 0.3, 0.8) * cloud(uv);

    color = haloColor + starColor + cloudColor;
    out_Col = vec4(color, 1.0);
}
