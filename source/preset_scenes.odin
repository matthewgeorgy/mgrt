package main

import fmt		"core:fmt"
import win32	"core:sys/windows"

SCENE_NAMES :: []string {
	"CornellBunny",
	"GlassSuzanne",
	"SpheresMaterial",
	"BunnyPlaneLamp",
	"CornellBox",
	"CornellSphere",
	"FinalSceneRTW",
	"PlaneDragon",
	"CornellDragon",
	"CornellPLY",
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
	Scale : f32 = 200
	Mesh := LoadMesh(FileName)
	MeshTriangles := AssembleTrianglesFromMesh(Mesh, Scale)
	fmt.println("Loaded mesh:", FileName, "with", len(MeshTriangles), "triangles")

	BoundingBox := GetMeshBoundingBox(Mesh, Scale)
	fmt.println("Min:", BoundingBox.Min)
	fmt.println("Max:", BoundingBox.Max)

	win32.QueryPerformanceCounter(&StartCounter)

	BVH := BuildBVH(MeshTriangles)

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

	Background := AddMaterial(Scene, CreateLambertian(v3{0.0, 0.0, 0.0}))
	NullLight := AddLight(Scene, light{})

	Red := AddMaterial(Scene, CreateLambertian(v3{0.65, 0.05, 0.05}))
	Gray := AddMaterial(Scene, CreateLambertian(v3{0.73, 0.73, 0.73}))
	Green := AddMaterial(Scene, CreateLambertian(v3{0.12, 0.45, 0.15}))
	MERL := AddMaterial(Scene, CreateMERL(string("assets/merl/gold-metallic-paint.binary")))
	Diffuse := AddMaterial(Scene, CreateLambertian(v3{0.1, 0.1, 0.1}))

	OrenNayar := AddMaterial(Scene, CreateOrenNayar(v3{0.8, 0.6, 0.6}, 20))
	Pink := AddMaterial(Scene, CreateLambertian(v3{0.8, 0.6, 0.6}))
	Glass := AddMaterial(Scene, CreateDielectric(1.33))

	Light := AddLight(Scene, light{v3{15, 15, 15}})

	AddPrimitive(Scene, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, -555}), Red, 0) 		// right
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, -555}), Green, 0) 			// left
	AddPrimitive(Scene, CreateQuad(v3{343, 554, -332}, v3{0, 0, 105}, v3{-130, 0, 0}), 0, Light)	// light
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, -555}), Gray, 0) 			// bottom
	AddPrimitive(Scene, CreateQuad(v3{555, 555, -555}, v3{-555, 0, 0}, v3{0, 0, 555}), Gray, 0)	// top
	AddPrimitive(Scene, CreateQuad(v3{0, 0, -555}, v3{555, 0, 0}, v3{0, 555, 0}), Gray, 0)		// back

	BVH.Translation = v3{-300, 0, 300}
	BVH.MaterialIndex = OrenNayar

	Scene.BVH = BVH
}

GlassSuzanne :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	StartCounter, EndCounter, Frequency, ElapsedTime: win32.LARGE_INTEGER
	win32.QueryPerformanceFrequency(&Frequency)

	// Mesh
	Filename := string("assets/suzanne.obj")
	Mesh := LoadMesh(Filename)
	MeshTriangles := AssembleTrianglesFromMesh(Mesh)
	fmt.println("Loaded mesh:", Filename, "with", len(MeshTriangles), "triangles")

	win32.QueryPerformanceCounter(&StartCounter)

	BVH := BuildBVH(MeshTriangles)

	win32.QueryPerformanceCounter(&EndCounter)
	ElapsedTime = (EndCounter - StartCounter) * 1000
	fmt.println("BVH construction took", ElapsedTime / Frequency, "ms")

	AABB := aabb{v3{F32_MAX, F32_MAX, F32_MAX}, v3{-F32_MAX, -F32_MAX, -F32_MAX}}
	Centroid : v3

	for Triangle in MeshTriangles
	{
		AABB.Min = MinV3(AABB.Min, Triangle.Vertices[0])
		AABB.Min = MinV3(AABB.Min, Triangle.Vertices[1])
		AABB.Min = MinV3(AABB.Min, Triangle.Vertices[2])
		AABB.Max = MaxV3(AABB.Max, Triangle.Vertices[0])
		AABB.Max = MaxV3(AABB.Max, Triangle.Vertices[1])
		AABB.Max = MaxV3(AABB.Max, Triangle.Vertices[2])

		Centroid = Centroid + (Triangle.Vertices[0] + Triangle.Vertices[1] + Triangle.Vertices[2])
	}

	Centroid /= f32(len(MeshTriangles))

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
	Background := AddMaterial(Scene, CreateLambertian(v3{0.2, 0.2, 0.2}))
	NullLight := AddLight(Scene, light{})

	Floor := AddMaterial(Scene, CreateLambertian(v3{0.2, 0.6, 0.8}))
	Glass := AddMaterial(Scene, CreateDielectric(1.33))

	Light := AddLight(Scene, light{v3{1, 1, 1}})

	AddPrimitive(Scene, plane{v3{0, 1, 0}, -10 * AABB.Min.y}, Floor, 0)
	AddPrimitive(Scene, CreateQuad(AABB.Max / 2 + v3{0, 2, 0}, v3{2, 0, 0}, v3{0, 0, 2}), 0, Light)

	Scene.BVH = BVH
	Scene.BVH.MaterialIndex = Glass
	Scene.BVH.Rotation = Degs2Rads(45)
}

SpheresMaterial :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	Camera.LookFrom = v3{0, 0, -3}
	Camera.LookAt = v3{0, 0, 0}
	Camera.FOV = 90
	Camera.FocusDist = 1

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	Background := AddMaterial(Scene, CreateLambertian(v3{0.5, 0.7, 1.0}))
	Ground := AddMaterial(Scene, CreateLambertian(v3{0.8, 0.8, 0.0}))
    Center := AddMaterial(Scene, CreateLambertian(v3{0.1, 0.2, 0.5}))
    Left   := AddMaterial(Scene, CreateDielectric(1.5))
    Bubble   := AddMaterial(Scene, CreateDielectric(1.0 / 1.5))
    Right  := AddMaterial(Scene, CreateMetal(v3{0.8, 0.6, 0.2}, 1.0))

    AddPrimitive(Scene, sphere{v3{ 0.0, -100.5, -1.0}, 100.0}, Ground, 0)
    AddPrimitive(Scene, sphere{v3{ 0.0,    0.0, -1.2},   0.5}, Center, 0)
    AddPrimitive(Scene, sphere{v3{ 1.0,    0.0, -1.0},   0.5}, Left, 0)
    AddPrimitive(Scene, sphere{v3{ 1.0,    0.0, -1.0},   0.4}, Bubble, 0)
    AddPrimitive(Scene, sphere{v3{-1.0,    0.0, -1.0},   0.5}, Right, 0)
}

BunnyPlaneLamp :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	StartCounter, EndCounter, Frequency, ElapsedTime: win32.LARGE_INTEGER
	win32.QueryPerformanceFrequency(&Frequency)

	// Mesh
	Filename := string("assets/bunny.obj")
	Mesh := LoadMesh(Filename)
	MeshTriangles := AssembleTrianglesFromMesh(Mesh)
	fmt.println("Loaded mesh:", Filename, "with", len(MeshTriangles), "triangles")

	win32.QueryPerformanceCounter(&StartCounter)

	BVH := BuildBVH(MeshTriangles)

	win32.QueryPerformanceCounter(&EndCounter)

	ElapsedTime = (EndCounter - StartCounter) * 1000
	fmt.println("BVH construction took", ElapsedTime / Frequency, "ms")

	MinX : f32 = F32_MAX
	MaxY : f32 = -F32_MAX
	MaxZ : f32 = -F32_MAX
	for Triangle in MeshTriangles
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
	Background := AddMaterial(Scene, CreateLambertian(v3{0.2, 0.2, 0.2}))
	NullLight := AddLight(Scene, light{})
	Model := AddMaterial(Scene, CreateLambertian(v3{0.8, 0.2, 0.2}))
	Plane := AddMaterial(Scene, CreateLambertian(v3{0.2, 0.6, 0.8}))
	Light := AddLight(Scene, light{v3{1, 1, 1}})

	AddPrimitive(Scene, plane{v3{0, 1, 0}, 0}, Plane, 0)
	AddPrimitive(Scene, CreateQuad(v3{MinX, MaxY + 0.5, MaxZ}, v3{2, 0, 0}, v3{0, 0, 2}), 0, Light)

	Scene.BVH = BVH
	Scene.BVH.MaterialIndex = Model
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
	Background := AddMaterial(Scene, CreateLambertian(v3{0.0, 0.0, 0.0}))
	NullLight := AddLight(Scene, light{})

	Red := AddMaterial(Scene, CreateLambertian(v3{0.65, 0.05, 0.05}))
	Gray := AddMaterial(Scene, CreateLambertian(v3{0.73, 0.73, 0.73}))
	Green := AddMaterial(Scene, CreateLambertian(v3{0.12, 0.45, 0.15}))

	Light := AddLight(Scene, light{v3{15, 15, 15}})

	AddPrimitive(Scene, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}), Green, 0)
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}), Red, 0)
	AddPrimitive(Scene, CreateQuad(v3{343, 554, 332}, v3{-130, 0, 0}, v3{0, 0, -105}), 0, Light)
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, 555}), Gray, 0)
	AddPrimitive(Scene, CreateQuad(v3{555, 555, 555}, v3{-555, 0, 0}, v3{0, 0, -555}), Gray, 0)
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 555}, v3{555, 0, 0}, v3{0, 555, 0}), Gray, 0)

	CreateBox(v3{0, 0, 0}, v3{165, 330, 165}, -v3{265, 0, 295}, 15, Gray, 0, Scene)
	CreateBox(v3{0, 0, 0}, v3{165, 165, 165}, -v3{130, 0, 65}, -18, Gray, 0, Scene)
}

CornellSphere :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	// Camera
	Camera.LookFrom = v3{278, 278, -800}
	Camera.LookAt = v3{278, 278, 0}
	Camera.FocusDist = 10
	Camera.FOV = 40

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	// Scene setup
	Background := AddMaterial(Scene, CreateLambertian(v3{0.0, 0.0, 0.0}))
	NullLight := AddLight(Scene, light{})

	Red := AddMaterial(Scene, CreateLambertian(v3{0.65, 0.05, 0.05}))
	Gray := AddMaterial(Scene, CreateLambertian(v3{0.73, 0.73, 0.73}))
	Green := AddMaterial(Scene, CreateLambertian(v3{0.12, 0.45, 0.15}))

	OrenNayar := AddMaterial(Scene, CreateOrenNayar(v3{0.8, 0.6, 0.6}, 20))
	Pink := AddMaterial(Scene, CreateLambertian(v3{0.8, 0.6, 0.6}))

	Light := AddLight(Scene, light{v3{15, 15, 15}})

	AddPrimitive(Scene, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}), Green, 0) // right
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}), Red, 0) // left
	AddPrimitive(Scene, CreateQuad(v3{343, 554, 332}, v3{-130, 0, 0}, v3{0, 0, -105}), 0, Light) // light
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, 555}), Gray, 0) // bottom
	AddPrimitive(Scene, CreateQuad(v3{555, 555, 555}, v3{-555, 0, 0}, v3{0, 0, -555}), Gray, 0) // top
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 555}, v3{555, 0, 0}, v3{0, 555, 0}), Gray, 0) // back

	FloorCenter := 0.5 * v3{555, 0, 555}
	SphereRadius : f32 = 125
	SphereCenter := FloorCenter + v3{0, SphereRadius, 0}

	AddPrimitive(Scene, sphere{SphereCenter, SphereRadius}, OrenNayar, 0)
}

FinalSceneRTW :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	Camera.LookFrom = v3{13, 2, 3}
	Camera.LookAt = v3{0, 0, 0}
	Camera.FOV = 20
	Camera.FocusDist = 10

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	Background := AddMaterial(Scene, CreateLambertian(v3{0.5, 0.7, 1.0}))
	NullLight := AddLight(Scene, light{})

	// RTW uses a huge sphere instead since they don't have a flat primitive like a plane,
	// but we do!
	// Using a sphere is ok, but its curvature causes spheres that are far enough away to
	// look like they're floating.
	Floor := AddMaterial(Scene, CreateLambertian(v3{0.5, 0.5, 0.5}))
	AddPrimitive(Scene, CreateQuad(v3{50, 0, 50}, v3{-100, 0, 0}, v3{0, 0, -100}), Floor, 0)

	for a := -11; a < 11; a += 1
	{
		for b := -11; b < 11; b += 1
		{
			ChooseMaterial := RandomUnilateral()

			SphereCenter := v3{f32(a) + 0.9 * RandomUnilateral(),
							   0.2,
							   f32(b) + 0.9 * RandomUnilateral()}

			if Length(SphereCenter - v3{4, 0.2, 0}) > 0.9
			{
				if ChooseMaterial < 0.8
				{
					// Lambertian
					Albedo := RandomV3() * RandomV3()
					SphereMaterial := AddMaterial(Scene, CreateLambertian(Albedo))
					AddPrimitive(Scene, sphere{SphereCenter, 0.2}, SphereMaterial, 0)
				}
				else if ChooseMaterial < 0.95
				{
					// Metal
					Albedo := RandomV3(0.5, 1)
					Fuzz := RandomFloat(0.0, 0.5)
					SphereMaterial := AddMaterial(Scene, CreateMetal(Albedo, Fuzz))
					AddPrimitive(Scene, sphere{SphereCenter, 0.2}, SphereMaterial, 0)
				}
				else
				{
					// Glass
					SphereMaterial := AddMaterial(Scene, CreateDielectric(1.5))
					AddPrimitive(Scene, sphere{SphereCenter, 0.2}, SphereMaterial, 0)
				}
			}
		}
	}

	Material1 := AddMaterial(Scene, CreateDielectric(1.5))
	Material2 := AddMaterial(Scene, CreateLambertian(v3{0.4, 0.2, 0.1}))
	Material3 := AddMaterial(Scene, CreateMetal(v3{0.7, 0.6, 0.5}, 0))

	AddPrimitive(Scene, sphere{v3{0, 1, 0}, 1}, Material1, 0)
	AddPrimitive(Scene, sphere{v3{-4, 1, 0}, 1}, Material2, 0)
	AddPrimitive(Scene, sphere{v3{4, 1, 0}, 1}, Material3, 0)
}

PlaneDragon :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	StartCounter, EndCounter, Frequency, ElapsedTime: win32.LARGE_INTEGER
	win32.QueryPerformanceFrequency(&Frequency)

	// Mesh
	Filename := string("assets/dragon.obj")
	Mesh := LoadMesh(Filename)
	MeshTriangles := AssembleTrianglesFromMesh(Mesh)
	fmt.println("Loaded mesh:", Filename, "with", len(MeshTriangles), "triangles")

	BoundingBox := GetMeshBoundingBox(Mesh)

	fmt.println("Min:", BoundingBox.Min)
	fmt.println("Max:", BoundingBox.Max)

	win32.QueryPerformanceCounter(&StartCounter)

	BVH := BuildBVH(MeshTriangles)

	win32.QueryPerformanceCounter(&EndCounter)

	ElapsedTime = (EndCounter - StartCounter) * 1000
	fmt.println("BVH construction took", ElapsedTime / Frequency, "ms")

	// Camera
	Camera.LookFrom = v3{0, 0.25, 1}
	Camera.LookAt = v3{0, 0, 0}
	Camera.FocusDist = 1
	Camera.FOV = 90

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	// Scene
	Background := AddMaterial(Scene, CreateLambertian(v3{0.2, 0.2, 0.2}))
	NullLight := AddLight(Scene, light{})
	Model := AddMaterial(Scene, CreateLambertian(v3{0.8, 0.2, 0.2}))
	Plane := AddMaterial(Scene, CreateLambertian(v3{0.2, 0.6, 0.8}))

	AddPrimitive(Scene, plane{v3{0, 1, 0}, -BoundingBox.Min.y}, Plane, 0)

	Scene.BVH = BVH
	Scene.BVH.MaterialIndex = Model
	Scene.BVH.Rotation = Degs2Rads(120)
}

CornellDragon  :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	StartCounter, EndCounter, Frequency : win32.LARGE_INTEGER
	win32.QueryPerformanceFrequency(&Frequency)

	// Mesh
	FileName := string("assets/dragon.obj")
	Scale : f32 = 500
	Mesh := LoadMesh(FileName)
	MeshTriangles := AssembleTrianglesFromMesh(Mesh, Scale)
	fmt.println("Loaded mesh:", FileName, "with", len(MeshTriangles), "triangles")

	BoundingBox := GetMeshBoundingBox(Mesh, Scale)
	fmt.println("Min:", BoundingBox.Min)
	fmt.println("Max:", BoundingBox.Max)

	win32.QueryPerformanceCounter(&StartCounter)

	BVH := BuildBVH(MeshTriangles)

	win32.QueryPerformanceCounter(&EndCounter)
	ElapsedTime := (EndCounter - StartCounter) * 1000
	fmt.println("BVH construction took", ElapsedTime / Frequency, "ms")

	// Camera
	Camera.LookFrom = v3{278, 278, -800}
	Camera.LookAt = v3{278, 278, 0}
	Camera.FOV = 40
	Camera.FocusDist = 10

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	Background := AddMaterial(Scene, CreateLambertian(v3{0.0, 0.0, 0.0}))
	NullLight := AddLight(Scene, light{})

	Red := AddMaterial(Scene, CreateLambertian(v3{0.65, 0.05, 0.05}))
	Gray := AddMaterial(Scene, CreateLambertian(v3{0.73, 0.73, 0.73}))
	Green := AddMaterial(Scene, CreateLambertian(v3{0.12, 0.45, 0.15}))
	Diffuse := AddMaterial(Scene, CreateLambertian(v3{0.1, 0.1, 0.1}))
	Glass := AddMaterial(Scene, CreateDielectric(1.33))

	OrenNayar := AddMaterial(Scene, CreateOrenNayar(v3{0.8, 0.6, 0.6}, 20))
	Pink := AddMaterial(Scene, CreateLambertian(v3{0.8, 0.6, 0.6}))

	Light := AddLight(Scene, light{v3{15, 15, 15}})

	AddPrimitive(Scene, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}), Green, 0) // right
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}), Red, 0) // left
	AddPrimitive(Scene, CreateQuad(v3{343, 554, 332}, v3{-130, 0, 0}, v3{0, 0, -105}), 0, Light) // light
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, 555}), Gray, 0) // bottom
	AddPrimitive(Scene, CreateQuad(v3{555, 555, 555}, v3{-555, 0, 0}, v3{0, 0, -555}), Gray, 0) // top
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 555}, v3{555, 0, 0}, v3{0, 555, 0}), Gray, 0) // back

	BVH.MaterialIndex = OrenNayar

	// Bounding box transform

	AlignedBox : aabb

	AlignedBox.Min = v3{0, 0, 0}
	AlignedBox.Max = BoundingBox.Max - BoundingBox.Min
	fmt.println("Aligned min:", AlignedBox.Min)
	fmt.println("Aligned max:", AlignedBox.Max)

	TranslationToAlign := BoundingBox.Min

	FloorWidth : f32 = 555
	FloorDepth : f32 = 555

	OffsetX := Abs(FloorWidth - AlignedBox.Max.x) / 2
	OffsetZ := Abs(FloorDepth - AlignedBox.Max.z) / 2

	TranslationX := -v3{OffsetX, 0, 0}
	TranslationZ := v3{0, 0, -OffsetZ}

	BVH.Translation = TranslationToAlign + TranslationX + TranslationZ
	BVH.Rotation = Degs2Rads(-60)

	Scene.BVH = BVH
}

CornellPLY  :: proc(Scene : ^scene, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	StartCounter, EndCounter, Frequency : win32.LARGE_INTEGER
	win32.QueryPerformanceFrequency(&Frequency)

	// Mesh
	FileName := string("assets/ply/mesh_00054.ply")
	Scale : f32 = 50
	Mesh := LoadMesh(FileName)
	MeshTriangles := AssembleTrianglesFromMesh(Mesh, Scale)
	fmt.println("Loaded mesh:", FileName, "with", len(MeshTriangles), "triangles")

	BoundingBox := GetMeshBoundingBox(Mesh, Scale)
	fmt.println("Min:", BoundingBox.Min)
	fmt.println("Max:", BoundingBox.Max)

	win32.QueryPerformanceCounter(&StartCounter)

	BVH := BuildBVH(MeshTriangles)

	win32.QueryPerformanceCounter(&EndCounter)
	ElapsedTime := (EndCounter - StartCounter) * 1000
	fmt.println("BVH construction took", ElapsedTime / Frequency, "ms")

	// Camera
	Camera.LookFrom = v3{278, 278, -800}
	Camera.LookAt = v3{278, 278, 0}
	Camera.FOV = 40
	Camera.FocusDist = 10

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	Background := AddMaterial(Scene, CreateLambertian(v3{0.0, 0.0, 0.0}))
	NullLight := AddLight(Scene, light{})

	Red := AddMaterial(Scene, CreateLambertian(v3{0.65, 0.05, 0.05}))
	Gray := AddMaterial(Scene, CreateLambertian(v3{0.73, 0.73, 0.73}))
	Green := AddMaterial(Scene, CreateLambertian(v3{0.12, 0.45, 0.15}))
	Diffuse := AddMaterial(Scene, CreateLambertian(v3{0.1, 0.1, 0.1}))
	Glass := AddMaterial(Scene, CreateDielectric(1.33))

	OrenNayar := AddMaterial(Scene, CreateOrenNayar(v3{0.8, 0.6, 0.6}, 20))
	Pink := AddMaterial(Scene, CreateLambertian(v3{0.8, 0.6, 0.6}))

	Light := AddLight(Scene, light{v3{15, 15, 15}})

	AddPrimitive(Scene, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}), Green, 0) // right
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}), Red, 0) // left
	AddPrimitive(Scene, CreateQuad(v3{343, 554, 332}, v3{-130, 0, 0}, v3{0, 0, -105}), 0, Light) // light
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, 555}), Gray, 0) // bottom
	AddPrimitive(Scene, CreateQuad(v3{555, 555, 555}, v3{-555, 0, 0}, v3{0, 0, -555}), Gray, 0) // top
	AddPrimitive(Scene, CreateQuad(v3{0, 0, 555}, v3{555, 0, 0}, v3{0, 555, 0}), Gray, 0) // back

	BVH.MaterialIndex = OrenNayar

	// Bounding box transform

	AlignedBox : aabb

	AlignedBox.Min = v3{0, 0, 0}
	AlignedBox.Max = BoundingBox.Max - BoundingBox.Min
	fmt.println("Aligned min:", AlignedBox.Min)
	fmt.println("Aligned max:", AlignedBox.Max)

	TranslationToAlign := BoundingBox.Min

	FloorWidth : f32 = 555
	FloorDepth : f32 = 555

	OffsetX := Abs(FloorWidth - AlignedBox.Max.x) / 2
	OffsetZ := Abs(FloorDepth - AlignedBox.Max.z) / 2

	TranslationX := -v3{OffsetX, 0, 0}
	TranslationZ := v3{0, 0, -OffsetZ}

	BVH.Translation = TranslationToAlign + TranslationX + TranslationZ
	// BVH.Rotation = Degs2Rads(-60)

	Scene.BVH = BVH
}

