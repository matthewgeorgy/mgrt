package main

import fmt		"core:fmt"
import win32	"core:sys/windows"

scene :: struct
{
	Materials : [dynamic]material,
	Spheres : [dynamic]sphere,
	Planes : [dynamic]plane,
	Quads : [dynamic]quad,
	Triangles : [dynamic]triangle,
	BVH : bvh,
	PhotonMap : ^photon_map,

	SamplesPerPixel : u32,
	MaxDepth : int,
};

AddMaterial :: proc{ AddLambertian, AddLight, AddMetal, AddDielectric, }

AddLambertian :: proc(Scene : ^scene, Lambertian : lambertian) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	Material : material

	Material.Type = material_type.BXDF
	Material.BxDF.Type = bxdf_type.DIFFUSE
	Material.BxDF.Lambertian = Lambertian

	append(&Scene.Materials, Material)

	return MaterialIndex
}

AddMetal :: proc(Scene : ^scene, Metal : metal) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	Material : material

	Material.Type = material_type.BXDF
	Material.BxDF.Type = bxdf_type.METAL
	Material.BxDF.Metal = Metal

	append(&Scene.Materials, Material)

	return MaterialIndex
}

AddDielectric :: proc(Scene : ^scene, Dielectric : dielectric) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	Material : material

	Material.Type = material_type.BXDF
	Material.BxDF.Type = bxdf_type.DIELECTRIC
	Material.BxDF.Dielectric = Dielectric

	append(&Scene.Materials, Material)

	return MaterialIndex
}

AddLight :: proc(Scene : ^scene, Light : light) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	Material : material

	Material.Type = material_type.LIGHT
	Material.Light.Le = Light.Le

	append(&Scene.Materials, Material)

	return MaterialIndex
}

///////////////////////////////////////
// Preset scenes
///////////////////////////////////////

CornellBunny  :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	StartCounter, EndCounter, Frequency : win32.LARGE_INTEGER
	win32.QueryPerformanceFrequency(&Frequency)

	// Mesh
	FileName := string("assets/bunny.obj")
	Mesh := LoadMesh(FileName, 200)
	fmt.println("Loaded mesh:", FileName, "with", len(Mesh.Triangles), "triangles")

	win32.QueryPerformanceCounter(&StartCounter)

	BVH := BuildBVH(Mesh.Triangles)

	win32.QueryPerformanceCounter(&EndCounter)
	ElapsedTime := (EndCounter - StartCounter) * 1000
	fmt.println("BVH construction took", ElapsedTime / Frequency, "ms")

	// Camera
	Camera.LookFrom = v3{278, 278, 800}
	Camera.LookAt = v3{278, 278, 0}
	Camera.FOV = 40
	Camera.FocusDist = 10

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	// Scene setup
	// TODO(matthew): do this with a proper bounding box so that we can get
	// other models in here!
	BVH.Translation = v3{-300, 0, 300}
	BVH.MatIndex = 5

	Scene.BVH = BVH

	AddMaterial(Scene, lambertian{v3{0.0, 0.0, 0.0}})
	AddMaterial(Scene, lambertian{v3{0.65, 0.05, 0.05}})
	AddMaterial(Scene, lambertian{v3{0.73, 0.73, 0.73}})
	AddMaterial(Scene, lambertian{v3{0.12, 0.45, 0.15}})
	AddMaterial(Scene, light{v3{15, 15, 15}})
	AddMaterial(Scene, lambertian{v3{0.05, 0.05, 0.85}})

	append(&Scene.Quads, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, -555}, 1)) 		// right
	append(&Scene.Quads, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, -555}, 3)) 			// left
	append(&Scene.Quads, CreateQuad(v3{343, 554, -332}, v3{0, 0, 105}, v3{-130, 0, 0}, 4))	// light
	append(&Scene.Quads, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, -555}, 2)) 			// bottom
	append(&Scene.Quads, CreateQuad(v3{555, 555, -555}, v3{-555, 0, 0}, v3{0, 0, 555}, 2))	// top
	append(&Scene.Quads, CreateQuad(v3{0, 0, -555}, v3{555, 0, 0}, v3{0, 555, 0}, 2))		// back

	Scene.SamplesPerPixel = 50
	Scene.MaxDepth = 10
}

GlassSuzanne :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	StartCounter, EndCounter, Frequency, ElapsedTime: win32.LARGE_INTEGER
	win32.QueryPerformanceFrequency(&Frequency)

	// Mesh
	Filename := string("assets/suzanne.obj")
	Mesh := LoadMesh(Filename)
	fmt.println("Loaded mesh:", Filename, "with", len(Mesh.Triangles), "triangles")

	win32.QueryPerformanceCounter(&StartCounter)

	BVH := BuildBVH(Mesh.Triangles)

	win32.QueryPerformanceCounter(&EndCounter)
	ElapsedTime = (EndCounter - StartCounter) * 1000
	fmt.println("BVH construction took", ElapsedTime / Frequency, "ms")

	AABB := aabb{v3{F32_MAX, F32_MAX, F32_MAX}, v3{-F32_MAX, -F32_MAX, -F32_MAX}}
	Centroid : v3

	for Triangle in Mesh.Triangles
	{
		AABB.Min = MinV3(AABB.Min, Triangle.Vertices[0])
		AABB.Min = MinV3(AABB.Min, Triangle.Vertices[1])
		AABB.Min = MinV3(AABB.Min, Triangle.Vertices[2])
		AABB.Max = MaxV3(AABB.Max, Triangle.Vertices[0])
		AABB.Max = MaxV3(AABB.Max, Triangle.Vertices[1])
		AABB.Max = MaxV3(AABB.Max, Triangle.Vertices[2])

		Centroid = Centroid + (Triangle.Vertices[0] + Triangle.Vertices[1] + Triangle.Vertices[2])
	}

	Centroid /= f32(len(Mesh.Triangles))

	Extents := AABB.Max - AABB.Min

	// for &Triangle in Mesh.Triangles
	// {
	// 	Triangle.Vertices[0] -= AABB.Min
	// 	Triangle.Vertices[1] -= AABB.Min
	// 	Triangle.Vertices[2] -= AABB.Min
	// }

	fmt.println("AABB:", AABB)
	fmt.println("Extents:", Extents)
	fmt.println("Centroid:", Centroid)

	// Camera
	Camera.LookFrom = Centroid//v3{4, 0, -3}
	Camera.LookAt = v3{0, 0, 0}
	Camera.FocusDist = 1
	Camera.FOV = 90

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	// Scene
	AddMaterial(Scene, lambertian{v3{0.2, 0.2, 0.2}})
	AddMaterial(Scene, lambertian{v3{0.8, 0.2, 0.2}})
	AddMaterial(Scene, lambertian{v3{0.2, 0.6, 0.8}})
	AddMaterial(Scene, light{v3{1, 1, 1}})
	AddMaterial(Scene, dielectric{1.33})

	append(&Scene.Planes, plane{v3{0, 1, 0}, -10 * AABB.Min.y, 2})
	append(&Scene.Quads, CreateQuad(AABB.Max / 2 + v3{0, 2, 0}, v3{2, 0, 0}, v3{0, 0, 2}, 3))

	Scene.Triangles = Mesh.Triangles
	Scene.BVH = BVH
	Scene.BVH.MatIndex = 4
	// Scene.BVH.Translation = -Centroid;
	Scene.BVH.Rotation = Degs2Rads(45)

	Scene.SamplesPerPixel = 10
	Scene.MaxDepth = 10
}

SpheresMaterial :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	Camera.LookFrom = v3{0, 0, -3}
	Camera.LookAt = v3{0, 0, 0}
	Camera.FOV = 90
	Camera.FocusDist = 1

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	Background := AddMaterial(Scene, lambertian{v3{0.5, 0.7, 1.0}})
	Ground := AddMaterial(Scene, lambertian{v3{0.8, 0.8, 0.0}});
    Center := AddMaterial(Scene, lambertian{v3{0.1, 0.2, 0.5}});
    Left   := AddMaterial(Scene, dielectric{1.5})
    Bubble   := AddMaterial(Scene, dielectric{1.0 / 1.5})
    Right  := AddMaterial(Scene, metal{v3{0.8, 0.6, 0.2}, 1.0});

    append(&Scene.Spheres, sphere{v3{ 0.0, -100.5, -1.0}, 100.0, Ground});
    append(&Scene.Spheres, sphere{v3{ 0.0,    0.0, -1.2},   0.5, Center});
    append(&Scene.Spheres, sphere{v3{ 1.0,    0.0, -1.0},   0.5, Left});
    append(&Scene.Spheres, sphere{v3{ 1.0,    0.0, -1.0},   0.4, Bubble});
    append(&Scene.Spheres, sphere{v3{-1.0,    0.0, -1.0},   0.5, Right});

	Scene.SamplesPerPixel = 100
	Scene.MaxDepth = 50
}

BunnyPlaneLamp :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	StartCounter, EndCounter, Frequency, ElapsedTime: win32.LARGE_INTEGER
	win32.QueryPerformanceFrequency(&Frequency)

	// Mesh
	Filename := string("assets/bunny.obj")
	Mesh := LoadMesh(Filename)
	fmt.println("Loaded mesh:", Filename, "with", len(Mesh.Triangles), "triangles")

	win32.QueryPerformanceCounter(&StartCounter)

	BVH := BuildBVH(Mesh.Triangles)

	win32.QueryPerformanceCounter(&EndCounter)

	ElapsedTime = (EndCounter - StartCounter) * 1000
	fmt.println("BVH construction took", ElapsedTime / Frequency, "ms")

	MinX : f32 = F32_MAX
	MaxY : f32 = -F32_MAX
	MaxZ : f32 = -F32_MAX
	for Triangle in Mesh.Triangles
	{
		MinX = Min(MinX, Triangle.Vertices[0].x)
		MinX = Min(MinX, Triangle.Vertices[1].x)
		MinX = Min(MinX, Triangle.Vertices[2].x)

		MaxY = Max(MaxY, Triangle.Vertices[0].y)
		MaxY = Max(MaxY, Triangle.Vertices[1].y)
		MaxY = Max(MaxY, Triangle.Vertices[2].y)

		MaxZ = Max(MaxZ, Triangle.Vertices[0].z)
		MaxZ = Max(MaxZ, Triangle.Vertices[1].z)
		MaxZ = Max(MaxZ, Triangle.Vertices[2].z)
	}

	// Camera
	Camera.LookFrom = v3{0, 1, 4}
	Camera.LookAt = v3{0, 0, 0}
	Camera.FocusDist = 1
	Camera.FOV = 90

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	// Scene
	AddMaterial(Scene, lambertian{v3{0.2, 0.2, 0.2}})
	AddMaterial(Scene, lambertian{v3{0.8, 0.2, 0.2}})
	AddMaterial(Scene, lambertian{v3{0.2, 0.6, 0.8}})
	AddMaterial(Scene, light{v3{1, 1, 1}})

	append(&Scene.Planes, plane{v3{0, 1, 0}, 0, 2})
	append(&Scene.Quads, CreateQuad(v3{MinX, MaxY + 0.5, MaxZ}, v3{2, 0, 0}, v3{0, 0, 2}, 3))

	Scene.Triangles = Mesh.Triangles
	Scene.BVH = BVH
	Scene.BVH.MatIndex = 1

	Scene.SamplesPerPixel = 10
	Scene.MaxDepth = 10
}

CornellBox :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	// Camera
	Camera.LookFrom = v3{278, 278, -800}
	Camera.LookAt = v3{278, 278, 0}
	Camera.FocusDist = 10
	Camera.FOV = 40

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	// Scene setup
	Background := AddMaterial(Scene, lambertian{v3{0.0, 0.0, 0.0}})
	Red := AddMaterial(Scene, lambertian{v3{0.65, 0.05, 0.05}})
	Gray := AddMaterial(Scene, lambertian{v3{0.73, 0.73, 0.73}})
	Green := AddMaterial(Scene, lambertian{v3{0.12, 0.45, 0.15}})
	Light := AddMaterial(Scene, light{v3{15, 15, 15}})
	Aluminum := AddMaterial(Scene, metal{v3{0.8, 0.85, 0.88}, 0})

	append(&Scene.Quads, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}, Green))
	append(&Scene.Quads, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}, Red))
	append(&Scene.Quads, CreateQuad(v3{343, 554, 332}, v3{-130, 0, 0}, v3{0, 0, -105}, Light))
	append(&Scene.Quads, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, 555}, Gray))
	append(&Scene.Quads, CreateQuad(v3{555, 555, 555}, v3{-555, 0, 0}, v3{0, 0, -555}, Gray))
	append(&Scene.Quads, CreateQuad(v3{0, 0, 555}, v3{555, 0, 0}, v3{0, 555, 0}, Gray))

	CreateBox(v3{0, 0, 0}, v3{165, 330, 165}, Gray, -v3{265, 0, 295}, 15, Scene)
	CreateBox(v3{0, 0, 0}, v3{165, 165, 165}, Gray, -v3{130, 0, 65}, -18, Scene)

	Scene.SamplesPerPixel = 10
	Scene.MaxDepth = 50
}
