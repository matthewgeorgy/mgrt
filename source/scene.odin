package main

import fmt		"core:fmt"
import win32	"core:sys/windows"

scene :: struct
{
	Primitives : [dynamic]primitive,
	Materials : [dynamic]material,
	Lights : [dynamic]light,
	BVH : bvh,
	PhotonMap : ^photon_map,

	SamplesPerPixel : u32,
	MaxDepth : int,
};

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

	Background := AddMaterial(Scene, lambertian{v3{0.0, 0.0, 0.0}})
	NullLight := AddLight(Scene, light{})

	Red := AddMaterial(Scene, lambertian{v3{0.65, 0.05, 0.05}})
	Gray := AddMaterial(Scene, lambertian{v3{0.73, 0.73, 0.73}})
	Green := AddMaterial(Scene, lambertian{v3{0.12, 0.45, 0.15}})
	Light := AddLight(Scene, light{v3{15, 15, 15}})
	Blue := AddMaterial(Scene, lambertian{v3{0.05, 0.05, 0.85}})

	AddPrimitive(Scene, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, -555}), Red, 0) 		// right
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, -555}), Green, 0) 			// left
	AddPrimitive(Scene, CreateQuad(v3{343, 554, -332}, v3{0, 0, 105}, v3{-130, 0, 0}), 0, Light)	// light
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, -555}), Gray, 0) 			// bottom
	AddPrimitive(Scene, CreateQuad(v3{555, 555, -555}, v3{-555, 0, 0}, v3{0, 0, 555}), Gray, 0)	// top
	AddPrimitive(Scene, CreateQuad(v3{0, 0, -555}, v3{555, 0, 0}, v3{0, 555, 0}), Gray, 0)		// back

	BVH.Translation = v3{-300, 0, 300}
	BVH.MaterialIndex = Blue

	Scene.BVH = BVH

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

	fmt.println("AABB:", AABB)
	fmt.println("Extents:", Extents)
	fmt.println("Centroid:", Centroid)

	// Camera
	Camera.LookFrom = Centroid
	Camera.LookAt = v3{0, 0, 0}
	Camera.FocusDist = 1
	Camera.FOV = 90

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	// Scene
	Background := AddMaterial(Scene, lambertian{v3{0.2, 0.2, 0.2}})
	NullLight := AddLight(Scene, light{})

	Floor := AddMaterial(Scene, lambertian{v3{0.2, 0.6, 0.8}})
	Glass := AddMaterial(Scene, dielectric{1.33})

	Light :=AddLight(Scene, light{v3{1, 1, 1}})

	AddPrimitive(Scene, plane{v3{0, 1, 0}, -10 * AABB.Min.y}, Floor, 0)
	AddPrimitive(Scene, CreateQuad(AABB.Max / 2 + v3{0, 2, 0}, v3{2, 0, 0}, v3{0, 0, 2}), 0, Light)

	Scene.BVH = BVH
	Scene.BVH.MaterialIndex = Glass
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

    AddPrimitive(Scene, sphere{v3{ 0.0, -100.5, -1.0}, 100.0}, Ground, 0)
    AddPrimitive(Scene, sphere{v3{ 0.0,    0.0, -1.2},   0.5}, Center, 0)
    AddPrimitive(Scene, sphere{v3{ 1.0,    0.0, -1.0},   0.5}, Left, 0)
    AddPrimitive(Scene, sphere{v3{ 1.0,    0.0, -1.0},   0.4}, Bubble, 0)
    AddPrimitive(Scene, sphere{v3{-1.0,    0.0, -1.0},   0.5}, Right, 0)

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
	Background := AddMaterial(Scene, lambertian{v3{0.2, 0.2, 0.2}})
	NullLight := AddLight(Scene, light{})
	Model := AddMaterial(Scene, lambertian{v3{0.8, 0.2, 0.2}})
	Plane := AddMaterial(Scene, lambertian{v3{0.2, 0.6, 0.8}})
	Light := AddLight(Scene, light{v3{1, 1, 1}})

	AddPrimitive(Scene, plane{v3{0, 1, 0}, 0}, Plane, 0)
	AddPrimitive(Scene, CreateQuad(v3{MinX, MaxY + 0.5, MaxZ}, v3{2, 0, 0}, v3{0, 0, 2}), 0, Light)

	Scene.BVH = BVH
	Scene.BVH.MaterialIndex = Model

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
	NullLight := AddLight(Scene, light{})

	Red := AddMaterial(Scene, lambertian{v3{0.65, 0.05, 0.05}})
	Gray := AddMaterial(Scene, lambertian{v3{0.73, 0.73, 0.73}})
	Green := AddMaterial(Scene, lambertian{v3{0.12, 0.45, 0.15}})
	Light := AddLight(Scene, light{v3{15, 15, 15}})
	Aluminum := AddMaterial(Scene, metal{v3{0.8, 0.85, 0.88}, 0})

	AddPrimitive(Scene, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}), Green, 0)
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}), Red, 0)
	AddPrimitive(Scene, CreateQuad(v3{343, 554, 332}, v3{-130, 0, 0}, v3{0, 0, -105}), 0, Light)
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, 555}), Gray, 0)
	AddPrimitive(Scene, CreateQuad(v3{555, 555, 555}, v3{-555, 0, 0}, v3{0, 0, -555}), Gray, 0)
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 555}, v3{555, 0, 0}, v3{0, 555, 0}), Gray, 0)

	CreateBox(v3{0, 0, 0}, v3{165, 330, 165}, -v3{265, 0, 295}, 15, Gray, 0, Scene)
	CreateBox(v3{0, 0, 0}, v3{165, 165, 165}, -v3{130, 0, 65}, -18, Gray, 0, Scene)

	Scene.SamplesPerPixel = 10
	Scene.MaxDepth = 50
}

