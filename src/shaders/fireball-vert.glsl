#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.
precision highp float;
precision highp int;

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

uniform int u_Time;         // The current time elapsed since the start of the program.

uniform float u_NoiseScale; // The amount of influence the noise value will have on the vertex displacement.

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Pos;            
out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

const float PI = 3.1415926535897932384626433832795;

// Noise and interpolation functions based on CIS 560 and CIS 566 Slides - "Noise Functions"
float noise3Df(vec3 p) 
{
    return fract(sin((dot(p, vec3(127.1, 311.7, 191.999)))) * 43758.5453);
}

vec3 noise3Dv(vec3 p) {
    return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 191.999)),
                 dot(p, vec3(269.5,183.3,483.1)),
                 dot(p, vec3(564.5,96.3,223.9))))
                 * 43758.5453);
}

float cosineInterpolate(float a, float b, float t)
{
    float cos_t = (1.f - cos(t * PI)) * 0.5f;
    return mix(a, b, cos_t);
}

float bias(float b, float t)
{
    return pow(t, log(b) / log(0.5f));
}

float interpolateNoise3D(float x, float y, float z)
{
    // Get integer and fractional components of current position
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);
    int intZ = int(floor(z));
    float fractZ = fract(z);

    // Get noise value at each of the 8 vertices
    float v1 = noise3Df(vec3(intX, intY, intZ));
    float v2 = noise3Df(vec3(intX + 1, intY, intZ));
    float v3 = noise3Df(vec3(intX, intY + 1, intZ));
    float v4 = noise3Df(vec3(intX + 1, intY + 1, intZ));
    float v5 = noise3Df(vec3(intX, intY, intZ + 1));
    float v6 = noise3Df(vec3(intX + 1, intY, intZ + 1));
    float v7 = noise3Df(vec3(intX, intY + 1, intZ + 1));
    float v8 = noise3Df(vec3(intX + 1, intY + 1, intZ + 1));

    // Interpolate in the X, Y, Z directions
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

float worley3D(vec3 p) {
    // Tile space
    p *= 2.0;
    vec3 pInt = floor(p);
    vec3 pFract = fract(p);
    float minDist = 1.0; // Minimum distance

    // Iterate through neighboring cells to find closest point
    for(int z = -1; z <= 1; ++z) {
        for(int y = -1; y <= 1; ++y) {
            for(int x = -1; x <= 1; ++x) {
                vec3 neighbor = vec3(float(x), float(y), float(z)); 
                vec3 point = noise3Dv(pInt + neighbor); // Random point in neighboring cell
                
                // Distance between fragment and neighbor point
                vec3 diff = neighbor + point - pFract; 
                float dist = length(diff); 
                minDist = min(minDist, dist);
            }
        }
    }

    // Set pixel brightness to distance between pixel and closest point
    return minDist;
}

// X-Axis Rotation Matrix
mat4 rotateX3D(float angle)
{
    return mat4(1, 0, 0, 0,
                0, cos(angle), sin(angle), 0,
                0, -sin(angle), cos(angle), 0,
                0, 0, 0, 1);
}

// Y-Axis Rotation Matrix
mat4 rotateY3D(float angle)
{
    return mat4(cos(angle), 0, -sin(angle), 0,
                0, 1, 0, 0,
                sin(angle), 0, cos(angle), 0,
                0, 0, 0, 1);
}

// Z-Axis Rotation Matrix
mat4 rotateZ3D(float angle)
{
    return mat4(cos(angle), sin(angle), 0, 0,
                -sin(angle), cos(angle), 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1);
}

// Scale Matrix
mat4 scale3D(vec3 c)
{
    return mat4(c.x, 0, 0, 0,
                0, c.y, 0, 0,
                0, 0, c.z, 0,
                0, 0, 0, 1);
}

// Translation Matrix
mat4 translate3D(vec3 d)
{
    return mat4(1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                d.x, d.y, d.z, 1);
}

// Compute transformed vertex
vec4 transformVertex(vec4 v)
{
    vec4 tv = v.xyzw;

    // Rotation 
    mat4 rotX = rotateX3D(0.f);
    mat4 rotY = rotateY3D(float(u_Time) / 500.f);
    mat4 rotZ = rotateZ3D(0.f);
    mat4 rot = rotZ * rotY * rotX;

    // Scale
    mat4 scl = scale3D(vec3(1.0f, 1.0f, 1.0f));
    
    // Translate
    mat4 trans = translate3D(vec3(0.f, 0.f, 0.f));

    tv = (trans * rot * scl * tv);
    return tv;
}

void main()
{
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.

    float offsetX = (cos(float(u_Time) / 200.f) + 1.f);
    float offsetY = (sin(float(u_Time) / 200.f) + 1.f);
    float offsetZ = (-cos(float(u_Time) / 200.f) + 1.f);
    vec3 offset = vec3(offsetX, offsetY, offsetZ);

    // Get rotated/transformed point
    vec4 transformed_Pos = transformVertex(vs_Pos);

    // Calculate surface displacement noise values
    float noiseHigh = 0.5f * fbm3D(vec3(50.f * vs_Pos.xyz + offset));
    float noiseLow = 0.6f * pow(worley3D(3.f * vs_Pos.xyz + offset.xyz), 1.5f);
    float noise = noiseLow + noiseHigh;
    noise = 0.2 * smoothstep(0.1f, 0.8f, noise);
    noise = bias(0.4, noise);

    // Apply model matrix to transformed point
    transformed_Pos += u_NoiseScale * (1.f - noise) * transformVertex(vs_Nor);
    vec4 modelposition = u_Model * (transformed_Pos);   // Temporarily store the transformed vertex positions for use below
    fs_Pos = modelposition;

    // Distorted fbm
    float s = 0.5 * (sin(float(u_Time) / 100.f) + 1.f);
    vec3 p1 = vec3(fbm3D(fs_Pos.xyz), fbm3D(fs_Pos.xyz + vec3(1.3f, 3.5f, 4.5f)), fbm3D(fs_Pos.xyz + vec3(4.4f, 3.2f, 9.0f)));
    vec3 p2 = vec3(fbm3D(fs_Pos.xyz), fbm3D(fs_Pos.xyz + vec3(10.3f, 3.3f, 1.4f)), fbm3D(fs_Pos.xyz + vec3(5.6f, 45.2f, 2.0f)));
    float fbmDist = fbm3D(p1 + s * p2);

    // Pass noise as color to fragment shader
    fs_Col = vec4(noise, fbmDist, 1.0, 1.0);

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
