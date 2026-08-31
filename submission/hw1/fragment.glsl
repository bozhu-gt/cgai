/////////////////////////////////////////////////////
//// CS 8803/4803 CGAI: Computer Graphics in AI Era
//// Assignment 1: Ray Tracing
/////////////////////////////////////////////////////

varying vec2 vUv; // UV (screen) coordinates in [0,1]^2


uniform vec2 iResolution;
uniform float iTime;
uniform int iFrame;

uniform sampler2D floorTex;

#define M_PI 3.1415925585
#define Epsilon 1e-6
vec3 sampleDiffuse(int matId, vec3 p);

//============================================================================
// Primitive data types.
//============================================================================

struct Camera 
{
    vec3 origin;
    vec3 lookAt;
    vec3 up;
    vec3 right;
    float aspectRatio;
};

struct Ray 
{
    vec3 ori;
    vec3 dir;
};

struct Plane 
{
    vec3 n;
    vec3 p;
    int matId;
};

struct Sphere 
{
    vec3 ori;
    float r;
    int matId;
};

struct Box 
{
    vec3 ori;
    vec3 halfWidth;
    mat3 rot;
    int matId;
};

struct Light 
{
    vec3 position;
    vec3 Ia;
    vec3 Id;
    vec3 Is;
};

struct Hit 
{
    float t;
    vec3 p;
    vec3 normal;
    int matId;
};

struct Material 
{
    vec3 ka;   // Ambient coefficient.
    vec3 kd;   // Diffuse coefficient.
    vec3 ks;   // Reflected specular coefficient.
    float shininess; // Shininess of the material.

    vec3 kr;   // Reflected coefficient.
};

//============================================================================
// Global scene data.
//============================================================================
Camera camera;
Light lights[2];
Material materials[9];

Sphere spheres[4];
Box boxes[12];
Plane planes[1];
//////////// Random functions ///////////
float g_seed = 0.;

vec3 gamma2(vec3 col) {
    return vec3(sqrt(col.r), sqrt(col.g), sqrt(col.b));
}

float deg2rad(float deg) 
{
    return deg * M_PI / 180.0;
}

uint base_hash(uvec2 p) 
{
    p = 1103515245U * ((p >> 1U) ^ (p.yx));
    uint h32 = 1103515245U * ((p.x) ^ (p.y >> 3U));
    return h32 ^ (h32 >> 16);
}

void initRand(in vec2 frag_coord, in float time) 
{
    g_seed = float(base_hash(floatBitsToUint(frag_coord))) / float(0xffffffffU) + time;
}

vec2 rand2(inout float seed) 
{
    uint n = base_hash(floatBitsToUint(vec2(seed += .1, seed += .1)));
    uvec2 rz = uvec2(n, n * 48271U);
    return vec2(rz.xy & uvec2(0x7fffffffU)) / float(0x7fffffff);
}

/////////////////////////////////////////
const Hit noHit = Hit(
                 /* time or distance */ -1.0, 
                 /* hit position */     vec3(0), 
                 /* hit normal */       vec3(0), 
                 /* hit material id*/   -1);

Hit hitPlane(const Ray r, const Plane pl) 
{
    Hit hit = noHit;
	
    float t = dot(pl.p - r.ori, pl.n) / dot(r.dir, pl.n);

    if (t <= 0.0)
        return noHit;

    vec3 hitP = r.ori + t * r.dir;
    hit = Hit(t, hitP, pl.n, pl.matId);
    
	return hit;
}

// TODO Step 1.1: Implement the sphere intersection
Hit hitSphere(const Ray r, const Sphere s) 
{
    Hit hit = noHit;
	
    /* your implementation starts */
    vec3 oc = r.ori - s.ori;
    float a = dot(r.dir, r.dir);
    float b = 2.0 * dot(oc, r.dir);
    float c = dot(oc, oc) - s.r * s.r;
    float discriminant = b * b - 4.0 * a * c;

    if(discriminant < 0.0)
        return noHit;

    float sqrtD = sqrt(discriminant);
    float t0 = (-b - sqrtD) / (2.0 * a);
    float t1 = (-b + sqrtD) / (2.0 * a);
    float t = t0 > Epsilon ? t0 : t1;

    if(t <= Epsilon)
        return noHit;

    vec3 hitP = r.ori + t * r.dir;
    vec3 normal = normalize(hitP - s.ori);
    hit = Hit(t, hitP, normal, s.matId);
	/* your implementation ends */
    
	return hit;
}

// TODO Step 1.2: Implement the box intersection
Hit hitBox(const Ray r, const Box b) 
{
    Hit hit = noHit;
	
    /* your implementation starts */
    mat3 invRot = transpose(b.rot);
    vec3 localOri = invRot * (r.ori - b.ori);
    vec3 localDir = invRot * r.dir;
    vec3 safeDir = localDir;
    if(abs(safeDir.x) < Epsilon) safeDir.x = safeDir.x < 0.0 ? -Epsilon : Epsilon;
    if(abs(safeDir.y) < Epsilon) safeDir.y = safeDir.y < 0.0 ? -Epsilon : Epsilon;
    if(abs(safeDir.z) < Epsilon) safeDir.z = safeDir.z < 0.0 ? -Epsilon : Epsilon;

    vec3 invDir = 1.0 / safeDir;
    vec3 tMin = (-b.halfWidth - localOri) * invDir;
    vec3 tMax = ( b.halfWidth - localOri) * invDir;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);

    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);

    if(tNear > tFar || tFar <= Epsilon)
        return noHit;

    float t = tNear > Epsilon ? tNear : tFar;
    vec3 localHitP = localOri + t * localDir;
    vec3 localNormal = vec3(0.0);
    float bias = 1e-4;

    if(abs(abs(localHitP.x) - b.halfWidth.x) < bias) {
        localNormal = vec3(sign(localHitP.x), 0.0, 0.0);
    } else if(abs(abs(localHitP.y) - b.halfWidth.y) < bias) {
        localNormal = vec3(0.0, sign(localHitP.y), 0.0);
    } else {
        localNormal = vec3(0.0, 0.0, sign(localHitP.z));
    }

    vec3 hitP = r.ori + t * r.dir;
    vec3 normal = normalize(b.rot * localNormal);
    hit = Hit(t, hitP, normal, b.matId);

	/* your implementation ends */
    
	return hit;
}

Hit findHit(Ray r) 
{
    Hit h = noHit;
    
	for(int i = 0; i < spheres.length(); i++) {
        Hit tempH = hitSphere(r, spheres[i]);
        if(tempH.t > Epsilon && (h.t < 0. || h.t > tempH.t))
            h = tempH;
    }
	
    for(int i = 0; i < planes.length(); i++) {
        Hit tempH = hitPlane(r, planes[i]);
        if(tempH.t > Epsilon && (h.t < 0. || h.t > tempH.t))
            h = tempH;
    }

    for(int i = 0; i < boxes.length(); i++) {
        Hit tempH = hitBox(r, boxes[i]);
        if(tempH.t > Epsilon && (h.t < 0. || h.t > tempH.t))
            h = tempH;
    }

    return h;
}

// TODO Step 2: Implement the Phong shading model
vec3 shading_phong(Light light, int matId, vec3 e, vec3 p, vec3 s, vec3 n) 
{
	//// default color: return dark red for the ground and dark blue for spheres
    vec3 color = matId == 0 ? vec3(0.2, 0, 0) : vec3(0, 0, 0.3);
	
    /* your implementation starts */
    Material mat = materials[matId];
    vec3 l = normalize(s - p);
    vec3 v = normalize(e - p);
    vec3 r = reflect(-l, normalize(n));
    float ndotl = max(dot(normalize(n), l), 0.0);

    vec3 ambient = mat.ka * light.Ia;
    vec3 diffuse = sampleDiffuse(matId, p) * light.Id * ndotl;
    vec3 specular = ndotl > 0.0 ? mat.ks * light.Is * pow(max(dot(v, r), 0.0), mat.shininess) : vec3(0.0);

    color = ambient + diffuse + specular;
	/* your implementation ends */
    
	return color;
}

// TODO Step 3: Implement the shadow test 
bool isShadowed(Light light, Hit h) 
{
    bool shadowed = false;
	
    /* your implementation starts */
    vec3 toLight = light.position - h.p;
    float lightDist = length(toLight);
    Ray shadowRay = Ray(h.p + h.normal * Epsilon * 10.0, normalize(toLight));
    Hit blocker = findHit(shadowRay);

    shadowed = blocker.t > Epsilon && blocker.t < lightDist - Epsilon;
	/* your implementation ends */
    
	return shadowed;
}

// TODO Step 4: Implement the texture mapping
vec3 sampleDiffuse(int matId, vec3 p) 
{
    if(matId == 0) {
        vec3 color = materials[matId].kd;
		
        /* your implementation starts */
        vec2 uv = fract(p.xz * 0.5);
        color *= texture(floorTex, uv).rgb;
		/* your implementation ends */
        
		return color;
    }
    return materials[matId].kd;
}

vec3 rayTrace(in Ray r, out Hit hit) 
{
    vec3 col = vec3(0);
    Hit h = findHit(r);
    hit = h;
    if(h.t > 0. && h.t < 1e8) {
        // shading
        for(int i = 0; i < lights.length(); i++) {
            if(isShadowed(lights[i], h)) {
                col += materials[h.matId].ka * lights[i].Ia;
            } else {
                vec3 e = camera.origin;
                vec3 p = h.p;
                vec3 s = lights[i].position;
                vec3 n = h.normal;
                col += shading_phong(lights[i], h.matId, e, p, s, n);
            }
        }
    }
    return col;
}

Ray getPrimaryRay(vec2 uv) 
{
    return Ray(camera.origin, 
               normalize(camera.lookAt + 
                        (uv.x - 0.5) * camera.right * camera.aspectRatio + 
                        (uv.y - 0.5) * camera.up));
}

mat3 getRotXYZ(float pitch, float yaw, float roll) 
{
    
    mat3 rotX = mat3(
        vec3(1, 0, 0),
        vec3(0, cos(pitch), sin(pitch)),
        vec3(0, -sin(pitch), cos(pitch))
    );
    mat3 rotY = mat3(
        vec3(cos(yaw), 0, -sin(yaw)),
        vec3(0, 1, 0),
        vec3(sin(yaw), 0, cos(yaw))
    );
    mat3 rotZ = mat3(
        vec3(cos(roll), sin(roll), 0),
        vec3(-sin(roll), cos(roll), 0),
        vec3(0, 0, 1)
    );
    
    return rotZ * rotY * rotX;
}

void initScene() 
{
    float aspectRatio = iResolution.x / iResolution.y;
    vec3 origin = vec3(0., 2.15, 4.8);
    vec3 lookAt = normalize(vec3(0.,0.32,0.25) - origin);
    vec3 up = vec3(0, 1, 0);
    vec3 right = normalize(cross(lookAt, up));
    up = normalize(cross(right, lookAt));
    camera = Camera(origin, lookAt, up, right, aspectRatio);

    // Floor Material 
    materials[0].ka = vec3(0.05);
    materials[0].kd = vec3(0.5);
    materials[0].ks = vec3(0.35);
    materials[0].shininess = 18.0;
    materials[0].kr = 0.12 * materials[0].ks;

    materials[1].ka = vec3(0.0);
    materials[1].kd = vec3(0.0);
    materials[1].ks = vec3(0.95);
    materials[1].shininess = 512.;
    materials[1].kr = 0.8 * materials[1].ks;

    materials[2].ka = vec3(0.0);
    materials[2].kd = vec3(0.92);
    materials[2].ks = vec3(0.45);
    materials[2].shininess = 128.;
    materials[2].kr = 0.5 * materials[2].ks;

    materials[3].ka = vec3(0.0);
    materials[3].kd = vec3(20, 24, 30) / 255.;
    materials[3].ks = vec3(0.65);
    materials[3].shininess = 128.;
    materials[3].kr = 0.45 * materials[3].ks;

    materials[4].ka = vec3(0.0);
    materials[4].kd = vec3(168, 172, 174) / 255.;
    materials[4].ks = vec3(0.75);
    materials[4].shininess = 128.;
    materials[4].kr = 0.45 * materials[4].ks;

    materials[5].ka = vec3(0.0);
    materials[5].kd = vec3(235, 235, 225) / 255.;
    materials[5].ks = vec3(0.35);
    materials[5].shininess = 128.;
    materials[5].kr = 0.15 * materials[5].ks;

    materials[6].ka = vec3(0.02);
    materials[6].kd = vec3(250, 188, 96) / 255.;
    materials[6].ks = vec3(0.55);
    materials[6].shininess = 96.;
    materials[6].kr = 0.2 * materials[6].ks;

    materials[7].ka = vec3(0.02);
    materials[7].kd = vec3(59, 133, 77) / 255.;
    materials[7].ks = vec3(0.18);
    materials[7].shininess = 64.;
    materials[7].kr = 0.08 * materials[7].ks;

    materials[8].ka = vec3(0.02);
    materials[8].kd = vec3(117, 78, 48) / 255.;
    materials[8].ks = vec3(0.2);
    materials[8].shininess = 64.;
    materials[8].kr = 0.12 * materials[8].ks;

    lights[0] = Light(vec3(-1.55, 2.65, 1.2),
                            /*Ia*/ vec3(0.16, 0.13, 0.1),
                            /*Id*/ vec3(0.78, 0.62, 0.4),
                            /*Is*/ vec3(0.55, 0.45, 0.32));
    lights[1] = Light(vec3(1.7, 3.2, 1.5),
                            /*Ia*/ vec3(0.08, 0.09, 0.1),
                            /*Id*/ vec3(0.28, 0.32, 0.38),
                            /*Is*/ vec3(0.25, 0.28, 0.34));
    planes[0] = Plane(vec3(0., 1., 0.), vec3(0., 0., 0.), 0);

    spheres[0] = Sphere(vec3(1.02, 0.64, -0.04), 0.21, 7);
    spheres[1] = Sphere(vec3(1.24, 0.68, 0.04), 0.18, 7);
    spheres[2] = Sphere(vec3(1.12, 0.86, -0.02), 0.16, 7);
    spheres[3] = Sphere(vec3(-1.42, 1.38, 0.68), 0.11, 6);

    boxes[0] = Box(vec3(0.0, 1.02, -0.85), vec3(1.0, 0.58, 0.04), getRotXYZ(0., 0., 0.), 3);
    boxes[1] = Box(vec3(0.0, 0.38, -0.78), vec3(0.08, 0.34, 0.05), getRotXYZ(0., 0., 0.), 4);
    boxes[2] = Box(vec3(0.0, 0.08, -0.52), vec3(0.48, 0.06, 0.22), getRotXYZ(0., 0., 0.), 4);
    boxes[3] = Box(vec3(0.0, 0.08, 0.62), vec3(0.82, 0.05, 0.24), getRotXYZ(0., 0., 0.), 5);
    boxes[4] = Box(vec3(-0.28, 0.145, 0.48), vec3(0.44, 0.012, 0.018), getRotXYZ(0., 0., 0.), 3);
    boxes[5] = Box(vec3(0.0, 0.145, 0.62), vec3(0.62, 0.012, 0.018), getRotXYZ(0., 0., 0.), 3);
    boxes[6] = Box(vec3(0.22, 0.145, 0.76), vec3(0.46, 0.012, 0.018), getRotXYZ(0., 0., 0.), 3);
    boxes[7] = Box(vec3(0.98, 0.07, 0.68), vec3(0.18, 0.04, 0.25), getRotXYZ(0., 0., 0.), 5);
    boxes[8] = Box(vec3(-1.45, 0.07, 0.55), vec3(0.25, 0.05, 0.25), getRotXYZ(0., 0., 0.), 4);
    boxes[9] = Box(vec3(-1.45, 0.68, 0.55), vec3(0.04, 0.6, 0.04), getRotXYZ(0., 0., 0.), 4);
    boxes[10] = Box(vec3(-1.3, 1.28, 0.55), vec3(0.34, 0.14, 0.22), getRotXYZ(0., 0., 0.), 6);
    boxes[11] = Box(vec3(1.12, 0.18, -0.02), vec3(0.28, 0.18, 0.28), getRotXYZ(0., 0., 0.), 8);
}

// TODO Step 5: Change the value of numberOfSampling to 50

/* your implementation starts */

const int numberOfSampling = 50;

/* your implementation ends */

void main() 
{
    initScene();
    initRand(gl_FragCoord.xy, iTime); 
    vec2 uv = gl_FragCoord.xy / iResolution.xy;

    vec3 resultCol = vec3(0.);
    vec3 compounded_kr = vec3(1.0); // cumulative reflection coefficient

    Ray recursive_ray = getPrimaryRay(uv + rand2(g_seed) / iResolution.xy);
    for(int i = 0; i < numberOfSampling; i++) {
        Hit hit;
        vec3 col = rayTrace(recursive_ray, hit);

        resultCol += compounded_kr * col;

        if(hit.t < 0.0 || hit.t > 1e8 || length(compounded_kr) < 0.001)
            break;

        compounded_kr *= materials[hit.matId].kr;
		
        // TODO Step 5: Define the reflected ray and assign this ray to recursive_ray
        
		/* your implementation starts */
        vec3 reflectedDir = normalize(reflect(recursive_ray.dir, hit.normal));
        recursive_ray = Ray(hit.p + hit.normal * Epsilon * 10.0, reflectedDir);
		/* your implementation ends */
    }

    resultCol = gamma2(resultCol);
    gl_FragColor = vec4(resultCol, 1.);
}
