package main

import fmt		"core:fmt"
import thread	"core:thread"
import win32	"core:sys/windows"
import libc		"core:c/libc"
import os		"core:os"
import strings	"core:strings"

material_type :: enum
{
	COLOR,
	LIGHT
};

material :: struct
{
	Type : material_type,
	Color : v3,
};

hit_record :: struct
{
	t : f32,
	MaterialIndex  : u32,
	SurfaceNormal : v3,
	HitPoint : v3,
};

camera :: struct
{
	Center : v3,
	FirstPixel : v3,
	PixelDeltaU : v3,
	PixelDeltaV : v3,

	LookFrom : v3,
	LookAt : v3,
	FocusDist : f32,
};

world :: struct
{
	Materials : [dynamic]material,
	Spheres : [dynamic]sphere,
	Planes : [dynamic]plane,
	Quads : [dynamic]quad,
	Triangles : [dynamic]triangle,

	SamplesPerPixel : u32,
	MaxDepth : int,
};

main :: proc()
{
	// Image
	Image := AllocateImage(640, 640)

	// Triangles
	Filename := string("assets/cube.obj")
	File, ok := os.read_entire_file(Filename)
	if !ok
	{
		fmt.println("Failed to load", Filename)
		return
	}

	StringFile := string(File)
	Vertices : [dynamic]v3
	Normals : [dynamic]v3
	Faces : [dynamic]v3i
	Triangles : [dynamic]triangle

	for Line in strings.split_lines_iterator(&StringFile)
	{
		Tokens := strings.split(Line, " ")

		Header := Tokens[0]
		Components := Tokens[1 : len(Tokens)]

		if strings.compare(Header, "v") == 0 // Vertex
		{
			V0 := f32(libc.atof(strings.clone_to_cstring(Components[0])))
			V1 := f32(libc.atof(strings.clone_to_cstring(Components[1])))
			V2 := f32(libc.atof(strings.clone_to_cstring(Components[2])))

			append(&Vertices, v3{V0, V1, V2})
		}
		else if strings.compare(Header, "vn") == 0 // Normal
		{
			N0 := f32(libc.atof(strings.clone_to_cstring(Components[0])))
			N1 := f32(libc.atof(strings.clone_to_cstring(Components[1])))
			N2 := f32(libc.atof(strings.clone_to_cstring(Components[2])))

			append(&Normals, v3{N0, N1, N2})
		}
		else if strings.compare(Header, "f") == 0 // Face
		{
			Point0 := strings.split(Components[0], "/")
			Point1 := strings.split(Components[1], "/")
			Point2 := strings.split(Components[2], "/")

			I0 := libc.atoi(strings.clone_to_cstring(Point0[0]))
			I1 := libc.atoi(strings.clone_to_cstring(Point1[0]))
			I2 := libc.atoi(strings.clone_to_cstring(Point2[0]))

			append(&Faces, v3i{I0, I1, I2})
		}
	}

	for Face in Faces
	{
		V0 := Vertices[Face.x - 1]
		V1 := Vertices[Face.y - 1]
		V2 := Vertices[Face.z - 1]

		Triangle := triangle{ Vertices = {V0, V1, V2}}

		append(&Triangles, Triangle)
	}

	// Camera
	Camera : camera

	Camera.LookFrom = v3{0, 2, 5}
	Camera.LookAt = v3{0, 0, 0}
	Camera.FocusDist = 1

	InitializeCamera(&Camera, Image.Width, Image.Height)

	// World
	World : world

	append(&World.Materials, material{material_type.COLOR, v3{0.8, 0.8, 0.8}})
	append(&World.Materials, material{material_type.COLOR, v3{0.8, 0.4, 0.2}})

	World.Triangles = Triangles

	World.SamplesPerPixel = 10
	World.MaxDepth = 10

	// Work queue
	Queue : work_queue

	TilesX : u32 = 16
	TilesY : u32 = 16
	TileWidth : u32 = u32(Image.Width) / TilesX
	TileHeight : u32 = u32(Image.Height) / TilesY

	for X : u32 = 0; X < TilesX; X += 1
	{
		for Y : u32 = 0; Y < TilesY; Y += 1
		{
			Top := TileHeight * Y
			Left := TileWidth * X
			Bottom := TileHeight * (Y + 1)
			Right := TileWidth * (X + 1)

			PushWorkOrder(&Queue, Top, Left, Bottom, Right)
		}
	}

	// Threading
	THREADCOUNT :: 8
	ThreadData : thread_data
	Threads : [THREADCOUNT]^thread.Thread
	StartCounter, EndCounter, Frequency : win32.LARGE_INTEGER

	ThreadData.Queue = &Queue
	ThreadData.Camera = &Camera
	ThreadData.World = &World
	ThreadData.Image = &Image

	libc.printf("Resolution: %dx%d\n", Image.Width, Image.Height)
	libc.printf("%d cores with %d %dx%d (%dk/tile) tiles\n", THREADCOUNT, Queue.EntryCount, TileWidth, TileHeight, TileWidth * TileHeight * 4 / 1024)
	libc.printf("Quality: %u samples/pixel, %d bounces (max) per ray\n", World.SamplesPerPixel, World.MaxDepth)

	win32.QueryPerformanceFrequency(&Frequency)
	win32.QueryPerformanceCounter(&StartCounter)

	for I := 0; I < THREADCOUNT; I += 1
	{
		Threads[I] = thread.create_and_start_with_data(&ThreadData, Render)
	}

	thread.join_multiple(..Threads[:])

	win32.QueryPerformanceCounter(&EndCounter)

	ElapsedTime := (EndCounter - StartCounter) * 1000

	fmt.println("Render took", ElapsedTime / Frequency, "ms")

	WriteImage(Image, string("test.bmp"))
}

LinearTosRGB :: proc (LinearValue : f32) -> f32
{
	if LinearValue > 0
	{
		return SquareRoot(LinearValue)
	}

	return 0
}

CastRay :: proc(Ray : ray, World : ^world, Depth : int) -> v3
{
	Record : hit_record

	HitDistance : f32 = F32_MAX
	HitSomething := false

	if Depth <= 0
	{
		return v3{0, 0, 0}
	}

	for Quad in World.Quads
	{
		OffsetRay := Ray
		OffsetRay.Origin -= Quad.Translation

		SinTheta := Sin(Quad.Rotation)
		CosTheta := Cos(Quad.Rotation)

		RotatedRay := OffsetRay

		RotatedRay.Origin = v3{
            (CosTheta * OffsetRay.Origin.x) - (SinTheta * OffsetRay.Origin.z),
            OffsetRay.Origin.y,
            (SinTheta * OffsetRay.Origin.x) + (CosTheta * OffsetRay.Origin.z)
        }

		RotatedRay.Direction = v3{
			(CosTheta * OffsetRay.Direction.x) - (SinTheta * OffsetRay.Direction.z),
            OffsetRay.Direction.y,
            (SinTheta * OffsetRay.Direction.x) + (CosTheta * OffsetRay.Direction.z)
		}

		Record.t = RayIntersectQuad(RotatedRay, Quad)
		if (Record.t > 0.0001 && Record.t < HitDistance)
		{
			HitSomething = true
			HitDistance = Record.t
			Record.MaterialIndex = Quad.MatIndex
			Record.SurfaceNormal = SetFaceNormal(RotatedRay, Quad.N)
			Record.HitPoint = RotatedRay.Origin + HitDistance * RotatedRay.Direction

			if (Quad.Rotation != 0)
			{
				Record.HitPoint = v3{
					(CosTheta * Record.HitPoint.x) + (SinTheta * Record.HitPoint.z),
					Record.HitPoint.y,
					(-SinTheta * Record.HitPoint.x) + (CosTheta * Record.HitPoint.z)
				}

				Record.SurfaceNormal = v3{
					(CosTheta * Record.SurfaceNormal.x) + (SinTheta * Record.SurfaceNormal.z),
					Record.SurfaceNormal.y,
					(-SinTheta * Record.SurfaceNormal.x) + (CosTheta * Record.SurfaceNormal.z)
				}
			}

			if (Quad.Translation != v3{0, 0, 0})
			{
				Record.HitPoint += Quad.Translation
			}
		}
	}

	for Triangle in World.Triangles
	{
		Record.t = RayIntersectTriangle(Ray, Triangle)
		if (Record.t > 0.0001 && Record.t < HitDistance)
		{
			HitSomething = true
			HitDistance = Record.t
			Record.MaterialIndex = 1 // TODO(matthew): set this in the world!
			Record.SurfaceNormal = v3{0, 0, 0} // TODO(matthew): set this!
		}
	}

	if HitSomething
	{
		return World.Materials[1].Color
	}
	else
	{
		return World.Materials[0].Color
	}
	// if !HitSomething
	// {
	// 	return World.Materials[0].Color
	// }

	// NewRay : ray
	// ScatteredColor : v3
	// EmittedColor : v3
	// Attenuation : v3
	// SurfaceMaterial := World.Materials[Record.MaterialIndex]

	// if SurfaceMaterial.Type == material_type.LIGHT
	// {
	// 	EmittedColor = SurfaceMaterial.Color
	// }
	// else
	// {
	// 	Attenuation = SurfaceMaterial.Color
	// }

	// NewRay.Origin = Record.HitPoint
	// NewRay.Direction = Record.SurfaceNormal + RandomUnitVector()//RandomOnHemisphere(Record.SurfaceNormal)

	// ScatteredColor = Attenuation * CastRay(NewRay, World, Depth - 1)

	// return EmittedColor + ScatteredColor
}

InitializeCamera :: proc(Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	// TODO(matthew): Bulletproof this. Might still be having issues depending
	// on aspect ratios, etc, but it seems to be fine right now.
	Theta : f32 = Degs2Rads(40)
	h : f32 = Tan(Theta / 2)
	ViewportHeight : f32 = 2 * h * Camera.FocusDist
	ViewportWidth : f32 = ViewportHeight * f32(ImageWidth) / f32(ImageHeight)
	Camera.Center = Camera.LookFrom

	if (ImageWidth > ImageHeight)
	{
		ViewportHeight = ViewportWidth * f32(ImageHeight) / f32(ImageWidth)
	}
	else
	{
		ViewportWidth = ViewportHeight * f32(ImageWidth) / f32(ImageHeight)
	}

	CameraW := Normalize(Camera.LookFrom - Camera.LookAt)
	CameraU := Normalize(Cross(v3{0, 1, 0}, CameraW))
	CameraV := Normalize(Cross(CameraW, CameraU))

	// Viewport
	ViewportU := ViewportWidth * CameraU
	ViewportV := -ViewportHeight * CameraV

	// Pixel deltas
	Camera.PixelDeltaU = ViewportU / f32(ImageWidth)
	Camera.PixelDeltaV = ViewportV / f32(ImageHeight)

	// First pixel
	ViewportUpperLeft := Camera.Center - (Camera.FocusDist * CameraW) - (ViewportU / 2) - (ViewportV / 2)
	Camera.FirstPixel = ViewportUpperLeft + 0.5 * (Camera.PixelDeltaU + Camera.PixelDeltaV)
}

CornellBoxScene :: proc(World : ^world, Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	// Camera
	Camera.LookFrom = v3{278, 278, -800}
	Camera.LookAt = v3{278, 278, 0}
	Camera.FocusDist = 10

	InitializeCamera(Camera, ImageWidth, ImageHeight)

	// World setup
	append(&World.Materials, material{material_type.COLOR, v3{0.0, 0.0, 0.0}})
	append(&World.Materials, material{material_type.COLOR, v3{0.65, 0.05, 0.05}})
	append(&World.Materials, material{material_type.COLOR, v3{0.73, 0.73, 0.73}})
	append(&World.Materials, material{material_type.COLOR, v3{0.12, 0.45, 0.15}})
	append(&World.Materials, material{material_type.LIGHT, v3{15, 15, 15}})

	append(&World.Quads, CreateQuad(v3{555, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}, 3))
	append(&World.Quads, CreateQuad(v3{0, 0, 0}, v3{0, 555, 0}, v3{0, 0, 555}, 1))
	append(&World.Quads, CreateQuad(v3{343, 554, 332}, v3{-130, 0, 0}, v3{0, 0, -105}, 4))
	append(&World.Quads, CreateQuad(v3{0, 0, 0}, v3{555, 0, 0}, v3{0, 0, 555}, 2))
	append(&World.Quads, CreateQuad(v3{555, 555, 555}, v3{-555, 0, 0}, v3{0, 0, -555}, 2))
	append(&World.Quads, CreateQuad(v3{0, 0, 555}, v3{555, 0, 0}, v3{0, 555, 0}, 2))

	CreateBox(v3{0, 0, 0}, v3{165, 330, 165}, 2, v3{265, 0, 295}, 15, World)
	CreateBox(v3{0, 0, 0}, v3{165, 165, 165}, 2, v3{130, 0, 65}, -18, World)

	World.SamplesPerPixel = 200
	World.MaxDepth = 50
}

