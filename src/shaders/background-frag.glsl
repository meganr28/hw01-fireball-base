#version 300 es
precision highp float;
precision highp int;

uniform vec2 u_Dimensions;
uniform int u_Time;

uniform vec4 u_CloudColor;
uniform vec4 u_StarColor;

uniform float u_NoiseScale;
uniform float u_CoronaScale;
uniform float u_StarDensity;

in vec2 fs_Pos;
out vec4 out_Col;

#define NUM_LAYERS 4.0
const float PI = 3.1415926535897932384626433832795;

// Noise and interpolation functions based on CIS 560 and CIS 566 Slides - "Noise Functions"
float noise2Df(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 noise2Dv( vec2 p ) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5,183.3)))) * 43758.5453);
}

float cosineInterpolate(float a, float b, float t)
{
    float cos_t = (1.f - cos(t * PI)) * 0.5f;
    return mix(a, b, cos_t);
}

float sawtoothWave(float x, float freq, float amplitude)
{
    return (x * freq - floor(x * freq)) * amplitude;
}

float ease_in_quadratic(float t)
{
    return t * t;
}

float ease_in_out_quadratic(float t)
{
    if (t < 0.5)
    {
        return ease_in_quadratic(t * 2.0) * 0.5;
    }
    else 
    {
        return 1.0 - ease_in_quadratic((1.0 - t) * 2.0) * 0.5;
    }
}

// From CIS 560 implementation of Perlin noise
float surflet(vec2 P, vec2 gridPoint) {
    float distX = abs(P.x - gridPoint.x);
    float distY = abs(P.y - gridPoint.y);
    // Polynomial falloff function (quintic)
    float tX = 1.0 - 6.0 * pow(distX, 5.f) + 15.0 * pow(distX, 4.f) - 10.0 * pow(distX, 3.f);
    float tY = 1.0 - 6.0 * pow(distY, 5.f) + 15.0 * pow(distY, 4.f) - 10.0 * pow(distY, 3.f);
    // Generate random normalized vector for each cell corner
    vec2 gradient = 2.f * noise2Dv(gridPoint) - vec2(1.f);
    // Get vector from cell corner to point
    vec2 diff = P - gridPoint;
    // Compute surflet
    float height = dot(diff, gradient);
    return height * tX * tY;
}

float perlinNoise(vec2 uv) 
{
    float result = 0.f;
    // Iterate over the four cell corners
    for(int dx = 0; dx <= 1; ++dx) {
      for(int dy = 0; dy <= 1; ++dy) {
        result += surflet(uv, floor(uv) + vec2(dx, dy));
      }
    }
    return result;
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

float star(vec2 uv, float noise)
{
    // Distance from fragment to screen center
    float dist = length(uv);

    // Compute color (inverse square falloff)
    // Additionally add an ease factor for a slight flicker around the stars
    float ease = 0.5 * (sin(float(u_Time) * 0.03 * noise) + 1.f) + 0.5;
    float color = 0.02 * ease / dist;

    // Make sure halo is confined to grid cell
    color *= smoothstep(1.0, 0.2, dist);

    return color;
}

// Inspired by the Art of Code's Starfield Shader/Tutorial
// https://www.shadertoy.com/view/tlyGW3
vec3 checkStarNeighbors(vec2 pos, vec2 id, float depth)
{
    vec3 starColor = vec3(0.0);

    // Similar to Worley noise, check neighboring cells for contribution to star color
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            vec2 neighborOffset = vec2(x, y);
            float noise = noise2Df(id + neighborOffset);
            vec2 uvOffset = vec2(noise, fract(noise * 48.0));
            
            // Starlight (sample at jittered position)
            float glow = star(pos - neighborOffset - uvOffset + 0.5, noise);
            
            // Star size (a scalar between 0.0 and 1.0)
            float size = fract(noise * 46.86);

            // Star color
            vec3 sColor = 0.5 * (sin(u_StarColor.xyz * fract(noise * 546.86) * PI) + 1.0);
            
            // Lower the green channel in the star color (keep more oranges and blue)
            sColor *= vec3(1.0, 0.7, 1.0 * size);

            // Add to accumulated color, using the ease-in-out function to have stars fade in and out
            starColor += sColor * size * glow * ease_in_out_quadratic(depth);
        }
    }

    return starColor;
}

float halo(vec2 uv)
{
    // Distance from fragment to screen center
    float dist = length(uv);

    // Compute color
    // TODO: change color to scale with noise offset and camera zoom
    float color = u_NoiseScale * u_CoronaScale / pow(dist, 1.2);
    color = max(0.0, color);

    return color;
}

vec3 nebulaLayer(vec2 uv)
{
    vec3 starColor = vec3(0.0);
    vec3 cloudColor = vec3(0.0);

    float time = float(u_Time) / 1000.f;
    
    // Clouds and star layer
    for (float i = 0.0; i < 1.0; i += 1.0 / NUM_LAYERS) {
        // Returns a depth value between 0.0 and 1.0
        // Signifies where the layer is located in space
        float depth = sawtoothWave(i + time, 1.0, 1.0);

        // Amount to scale the grid (based on depth)
        // If closer to the camera, grid will be bigger to give illusion of zooming in
        float starScale = mix(u_StarDensity, 0.5, depth);
        float cloudScale = mix(15.0, 0.1, depth);

        // Jitter the grid position and id for stars
        // Subtract 0.5 from grid position to remap cell from [-.5, .5]
        vec2 gridPos = fract(uv * starScale + i * 47.0) - 0.5;
        vec2 gridId = floor(uv * starScale + i * 607.0);

        // Calculate star color
        starColor += checkStarNeighbors(gridPos, gridId, depth);

        // Calculate cloud color (perturb it by random amount)
        float fbm = cloud(uv * cloudScale + i * 544.5);
        vec3 cColor = (u_CloudColor.xyz + vec3(fbm, 0.0, 0.0)) * fract(i * 34.3);

        // Add accumulated color, using smootstep to fade out
        cloudColor += cColor * fbm * depth * smoothstep(1.0, 0.8, depth);
    }

    return starColor + cloudColor;
}

void main() {
    // Bring coordinate to the middle of the screen
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_Dimensions.xy) / u_Dimensions.y;

    vec3 haloColor = vec3(0.0);  
    vec3 nebulaColor = vec3(0.0);
    vec3 color = vec3(0.0);
    
    // Main star halo
    float halo = halo(uv);
    haloColor += vec3(halo, pow(halo, 3.0), pow(halo, 10.0) * 0.8);
    
    // Nebula layers (stars and gas clouds)
    nebulaColor += nebulaLayer(uv);

    color = haloColor + nebulaColor;
    out_Col = vec4(color, 1.0);
}
