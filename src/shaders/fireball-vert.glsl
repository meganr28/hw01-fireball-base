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
uniform float u_NoiseScale;   // The amount of influence the noise value will have on the vertex displacement.

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

float noise3D(vec3 p) 
{
    return fract(sin((dot(p, vec3(127.1, 311.7, 191.999)))) * 43758.5453);
}

vec3 random3( vec3 p ) {
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

float worley3D(vec3 p) {
    p *= 2.0; // Now the space is 10x10 instead of 1x1. Change this to any number you want.
    vec3 pInt = floor(p);
    vec3 pFract = fract(p);
    float minDist = 1.0; // Minimum distance initialized to max.
    for(int z = -1; z <= 1; ++z) {
        for(int y = -1; y <= 1; ++y) {
            for(int x = -1; x <= 1; ++x) {
                vec3 neighbor = vec3(float(x), float(y), float(z)); // Direction in which neighbor cell lies
                vec3 point = random3(pInt + neighbor); // Get the Voronoi centerpoint for the neighboring cell
                vec3 diff = neighbor + point - pFract; // Distance between fragment coord and neighbor’s Voronoi point
                float dist = length(diff);
                minDist = min(minDist, dist);
            }
        }
    }
    return minDist;
}

float surflet(vec3 p, vec3 gridPoint) {
    // Compute the distance between p and the grid point along each axis, and warp it with a
    // quintic function so we can smooth our cells
    vec3 t2 = abs(p - gridPoint);
    vec3 t = vec3(1.f) - 6.f * pow(t2, vec3(5.f)) + 15.f * pow(t2, vec3(4.f)) - 10.f * pow(t2, vec3(3.f));
    // Get the random vector for the grid point (assume we wrote a function random2
    // that returns a vec2 in the range [0, 1])
    vec3 gradient = random3(gridPoint) * 2. - vec3(1., 1., 1.);
    // Get the vector from the grid point to P
    vec3 diff = p - gridPoint;
    // Get the value of our height field by dotting grid->P with our gradient
    float height = dot(diff, gradient);
    // Scale our height field (i.e. reduce it) by our polynomial falloff function
    return height * t.x * t.y * t.z;
}


float perlinNoise3D(vec3 p) {
	float surfletSum = 0.f;
	// Iterate over the four integer corners surrounding uv
	for(int dx = 0; dx <= 1; ++dx) {
		for(int dy = 0; dy <= 1; ++dy) {
			for(int dz = 0; dz <= 1; ++dz) {
				surfletSum += surflet(p, floor(p) + vec3(dx, dy, dz));
			}
		}
	}
	return surfletSum;
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

        total += amp * abs(perlinNoise3D(p));
    }

    return total;
}

vec3 curl3D(vec3 p)
{
    float e = 0.0001;
    vec3 curl = vec3(0.f);

    // Rate of change - YZ plane
    float n1 = interpolateNoise3D(p.x, p.y + e, p.z);
    float n2 = interpolateNoise3D(p.x, p.y + e, p.z);
    float a = (n1 - n2) / (2.f * e);
    float n3 = interpolateNoise3D(p.x, p.y, p.z + e);
    float n4 = interpolateNoise3D(p.x, p.y, p.z - e);
    float b = (n3 - n4) / (2.f * e);
    curl.x = a - b;

    // Rate of chnage - XZ plane
    n1 = interpolateNoise3D(p.x, p.y, p.z + e);
    n2 = interpolateNoise3D(p.x, p.y, p.z - e);
    a = (n1 - n2) / (2.f * e);
    n3 = interpolateNoise3D(p.x + e, p.y, p.z);
    n4 = interpolateNoise3D(p.x - e, p.y, p.z);
    b = (n3 - n4) / (2.f * e);
    curl.y = a - b;

    // Rate of change - XY plane
    n1 = interpolateNoise3D(p.x + e, p.y, p.z);
    n2 = interpolateNoise3D(p.x - e, p.y, p.z);
    a = (n1 - n2) / (2.f * e);
    n3 = interpolateNoise3D(p.x, p.y + e, p.z + e);
    n4 = interpolateNoise3D(p.x, p.y - e, p.z - e);
    b = (n3 - n4) / (2.f * e);
    curl.z = a - b;

    return curl;
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

    float offsetX = 0.5 * (cos(float(u_Time) / 500.f) + 1.f);
    float offsetY = 0.5 * (sin(float(u_Time) / 500.f) + 1.f);
    float offsetZ = 0.5 * (-cos(float(u_Time) / 500.f) + 1.f);
    vec3 offset = vec3(offsetX, offsetY, offsetZ);

    // Get rotated/transformed point
    vec4 transformed_Pos = transformVertex(vs_Pos);

    //float noiseLow = 2.0f * fbm3D(0.05f * vec3(vs_Pos.x, vs_Pos.y, vs_Pos.z));
    //float noiseHigh = 0.5f * fbm3D(vec3(5.f * vs_Pos.x + time, 5.f * vs_Pos.y + time, 5.f * vs_Pos.z + time));
    //float noise = noiseHigh + noiseLow;
    float noise = 0.5f * worley3D(2.f * vs_Pos.xyz + offset.xyz);
    noise = 0.2 * smoothstep(0.1f, 0.6f, noise);
    //noise += noiseLow + noiseHigh;

    // Pass noise as color to fragment shader
    fs_Col = vec4(vec3(noise), 1.0);

    // Apply model matrix to transformed point
    transformed_Pos += u_NoiseScale * (1.f - noise) * transformVertex(vs_Nor);
    vec4 modelposition = u_Model * (transformed_Pos);   // Temporarily store the transformed vertex positions for use below
    fs_Pos = modelposition;

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
