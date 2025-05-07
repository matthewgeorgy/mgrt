package main

import fmt		"core:fmt"
import win32	"core:sys/windows"

CornellBunny  :: proc(World : ^world, Camera : ^camera, ImageWidth, ImageHeight : i32)
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

	// World setup
	// TODO(matthew): do this with a proper bounding box so that we can get
	// other models in here!
	BVH.Translation = v3{-300, 0, 300}
	BVH.MatIndex = 5

	World.BVH = BVH

	append(&World.Materials, lambertian{v3{0.0, 0.0, 0.0}})
	append(&World.Materials, lambertian{v3{0.65, 0.05, 0.05}})
	append(&World.Materials, lambertian{v3{0.73, 0.73, 0.73}})
	append(&World.Materials, lambertian{v3{0.12, 0.45, 0.15}})
	append(&World.Materials, light{v3{15, 15, 15}})
	append(&World.Materials, lambertian{v3{0.05, 0.05, 0.85}})

	append(&World.Quads, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, -555}, 1)) 		// right
	append(&World.Quads, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, -555}, 3)) 			// left
	append(&World.Quads, CreateQuad(v3{343, 554, -332}, v3{0, 0, 105}, v3{-130, 0, 0}, 4))	// light
	append(&World.Quads, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, -555}, 2)) 			// bottom
	append(&World.Quads, CreateQuad(v3{555, 555, -555}, v3{-555, 0, 0}, v3{0, 0, 555}, 2))	// top
	append(&World.Quads, CreateQuad(v3{0, 0, -555}, v3{555, 0, 0}, v3{0, 555, 0}, 2))		// back

	World.SamplesPerPixel = 50
	World.MaxDepth = 10
}

GlassSuzanne :: proc(World : ^world, Camera : ^camera, ImageWidth, ImageHeight : i32)
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

	// World
	append(&World.Materials, lambertian{v3{0.2, 0.2, 0.2}})
	append(&World.Materials, lambertian{v3{0.8, 0.2, 0.2}})
	append(&World.Materials, lambertian{v3{0.2, 0.6, 0.8}})
	append(&World.Materials, light{v3{1, 1, 1}})
	append(&World.Materials, dielectric{1.33})
	append(&World.Planes, plane{v3{0, 1, 0}, -10 * AABB.Min.y, 2})
	append(&World.Quads, CreateQuad(AABB.Max / 2 + v3{0, 2, 0}, v3{2, 0, 0}, v3{0, 0, 2}, 3))

	World.Triangles = Mesh.Triangles
	World.BVH = BVH
	World.BVH.MatIndex = 4
	// World.BVH.Translation = -Centroid;
	World.BVH.Rotation = 45

	World.SamplesPerPixel = 10
	World.MaxDepth = 10
}

SpheresMaterial :: proc(World : ^world, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	Camera.LookFrom = v3{0, 0, -3}
	Camera.LookAt = v3{0, 0, 0}
	Camera.FOV = 90
	Camera.FocusDist = 1

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	append(&World.Materials, lambertian{v3{0.5, 0.7, 1.0}})
	append(&World.Materials, lambertian{v3{0.8, 0.8, 0.0}})
    append(&World.Materials, lambertian{v3{0.1, 0.2, 0.5}})
    append(&World.Materials, dielectric{1.5})
    append(&World.Materials, dielectric{1.0 / 1.5})
    append(&World.Materials, metal{v3{0.8, 0.6, 0.2}, 1.0})

    append(&World.Spheres, sphere{v3{ 0.0, -100.5, -1.0}, 100.0, 1})
    append(&World.Spheres, sphere{v3{ 0.0,    0.0, -1.2},   0.5, 2})
    append(&World.Spheres, sphere{v3{-1.0,    0.0, -1.0},   0.5, 3})
    append(&World.Spheres, sphere{v3{-1.0,    0.0, -1.0},   0.4, 4})
    append(&World.Spheres, sphere{v3{ 1.0,    0.0, -1.0},   0.5, 5})

	World.SamplesPerPixel = 100
	World.MaxDepth = 50
}

BunnyPlaneLamp :: proc(World : ^world, Camera : ^camera, ImageWidth, ImageHeight : i32)
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

	// World
	append(&World.Materials, lambertian{v3{0.2, 0.2, 0.2}})
	append(&World.Materials, lambertian{v3{0.8, 0.2, 0.2}})
	append(&World.Materials, lambertian{v3{0.2, 0.6, 0.8}})
	append(&World.Materials, light{v3{1, 1, 1}})
	append(&World.Planes, plane{v3{0, 1, 0}, 0, 2})
	append(&World.Quads, CreateQuad(v3{MinX, MaxY + 0.5, MaxZ}, v3{2, 0, 0}, v3{0, 0, 2}, 3))

	World.Triangles = Mesh.Triangles
	World.BVH = BVH
	World.BVH.MatIndex = 1

	World.SamplesPerPixel = 10
	World.MaxDepth = 10
}

CornellBox :: proc(World : ^world, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	// Camera
	Camera.LookFrom = v3{278, 278, -800}
	Camera.LookAt = v3{278, 278, 0}
	Camera.FocusDist = 10
	Camera.FOV = 40

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	// World setup
	append(&World.Materials, lambertian{v3{0.0, 0.0, 0.0}})
	append(&World.Materials, lambertian{v3{0.65, 0.05, 0.05}})
	append(&World.Materials, lambertian{v3{0.73, 0.73, 0.73}})
	append(&World.Materials, lambertian{v3{0.12, 0.45, 0.15}})
	append(&World.Materials, light{v3{15, 15, 15}})

	append(&World.Quads, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}, 3))
	append(&World.Quads, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}, 1))
	append(&World.Quads, CreateQuad(v3{343, 554, 332}, v3{-130, 0, 0}, v3{0, 0, -105}, 4))
	append(&World.Quads, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, 555}, 2))
	append(&World.Quads, CreateQuad(v3{555, 555, 555}, v3{-555, 0, 0}, v3{0, 0, -555}, 2))
	append(&World.Quads, CreateQuad(v3{0, 0, 555}, v3{555, 0, 0}, v3{0, 555, 0}, 2))

	CreateBox(v3{0, 0, 0}, v3{165, 330, 165}, 2, v3{265, 0, 295}, 15, World)
	CreateBox(v3{0, 0, 0}, v3{165, 165, 165}, 2, v3{130, 0, 65}, -18, World)

	World.SamplesPerPixel = 1
	World.MaxDepth = 10
}
