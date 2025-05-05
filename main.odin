package main

import fmt		"core:fmt"
import thread	"core:thread"
import win32	"core:sys/windows"
import libc		"core:c/libc"
import strings	"core:strings"

hit_record :: struct
{
	t : f32,
	MaterialIndex  : u32,
	SurfaceNormal : v3,
	HitPoint : v3,
	IsFrontFace : bool,
	BestTriangleIndex : u32,
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
	FOV : f32,
};

world :: struct
{
	Materials : [dynamic]material,
	Spheres : [dynamic]sphere,
	Planes : [dynamic]plane,
	Quads : [dynamic]quad,
	Triangles : [dynamic]triangle,
	BVH : bvh,

	SamplesPerPixel : u32,
	MaxDepth : int,
};

SCR_WIDTH :: 800
SCR_HEIGHT :: 800

main :: proc()
{
	// Image
	Image := AllocateImage(640, 640)

	// World & camera
	World : world
	Camera : camera

	CornellBox(&World, &Camera, Image.Width, Image.Height)

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

	// Counters
	StartCounter, EndCounter, Frequency, ElapsedTime: win32.LARGE_INTEGER

	win32.QueryPerformanceFrequency(&Frequency)

	// Threading
	THREADCOUNT :: 8
	ThreadData : thread_data
	Threads : [THREADCOUNT]^thread.Thread

	ThreadData.Queue = &Queue
	ThreadData.Camera = &Camera
	ThreadData.World = &World
	ThreadData.Image = &Image

	libc.printf("Resolution: %dx%d\n", Image.Width, Image.Height)
	libc.printf("%d cores with %d %dx%d (%dk/tile) tiles\n", THREADCOUNT, Queue.EntryCount, TileWidth, TileHeight, TileWidth * TileHeight * 4 / 1024)
	libc.printf("Quality: %u samples/pixel, %d bounces (max) per ray\n", World.SamplesPerPixel, World.MaxDepth)

	win32.QueryPerformanceCounter(&StartCounter)

	for I := 0; I < THREADCOUNT; I += 1
	{
		Threads[I] = thread.create_and_start_with_data(&ThreadData, Render)
	}

	thread.join_multiple(..Threads[:])

	win32.QueryPerformanceCounter(&EndCounter)

	ElapsedTime = (EndCounter - StartCounter) * 1000

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

GetIntersection :: proc(Ray : ray, World : ^world, Record : ^hit_record) -> bool
{
	Record.t = F32_MAX

	HitDistance : f32 = F32_MAX
	HitSomething := false

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
			SetFaceNormal(RotatedRay, Quad.N, Record)
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

	if World.BVH.NodesUsed != 0
	{
		TranslatedRay := Ray

		TranslatedRay.Origin += World.BVH.Translation

		SinTheta := Sin(Degs2Rads(World.BVH.Rotation))
		CosTheta := Cos(Degs2Rads(World.BVH.Rotation))

		RotatedRay := TranslatedRay

		RotatedRay.Origin = v3{
            (CosTheta * TranslatedRay.Origin.x) - (SinTheta * TranslatedRay.Origin.z),
            TranslatedRay.Origin.y,
            (SinTheta * TranslatedRay.Origin.x) + (CosTheta * TranslatedRay.Origin.z)
        }

		RotatedRay.Direction = v3{
			(CosTheta * TranslatedRay.Direction.x) - (SinTheta * TranslatedRay.Direction.z),
            TranslatedRay.Direction.y,
            (SinTheta * TranslatedRay.Direction.x) + (CosTheta * TranslatedRay.Direction.z)
		}

		TraverseBVH(RotatedRay, Record, World.BVH, World.BVH.RootNodeIndex)
		if Record.t > 0.0001 && Record.t < HitDistance
		{
			HitSomething = true
			HitDistance = Record.t

			// Compute surface normal from the best triangle intersection
			{
				Triangle := World.BVH.Triangles[Record.BestTriangleIndex]

				V0 := Triangle.Vertices[0]
				V1 := Triangle.Vertices[1]
				V2 := Triangle.Vertices[2]

				Record.SurfaceNormal = Normalize(Cross(V1 - V0, V2 - V0))
			}

			Record.MaterialIndex = World.BVH.MatIndex
			SetFaceNormal(RotatedRay, Record.SurfaceNormal, Record)
			Record.HitPoint = RotatedRay.Origin + HitDistance * RotatedRay.Direction

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

			Record.HitPoint -= World.BVH.Translation
		}
	}

	for Plane in World.Planes
	{
		Record.t = RayIntersectPlane(Ray, Plane)

		if Record.t > 0.0001 && Record.t < HitDistance
		{
			HitSomething = true
			HitDistance = Record.t
			Record.MaterialIndex = Plane.MatIndex
			SetFaceNormal(Ray, Plane.N, Record)
			Record.HitPoint = Ray.Origin + HitDistance * Ray.Direction
		}
	}

	for Sphere in World.Spheres
	{
		Record.t = RayIntersectSphere(Ray, Sphere)

		if Record.t > 0.0001 && Record.t < HitDistance
		{
			HitSomething = true
			HitDistance = Record.t
			Record.MaterialIndex = Sphere.MatIndex
			Record.HitPoint = Ray.Origin + HitDistance * Ray.Direction
			OutwardNormal := Normalize(Record.HitPoint - Sphere.Center)

			SetFaceNormal(Ray, OutwardNormal, Record)
		}
	}

	// for Triangle in World.Triangles
	// {
	// 	RayIntersectTriangle(Ray, &Record, Triangle)
	// 	if (Record.t > 0.0001 && Record.t < HitDistance)
	// 	{
	// 		HitSomething = true
	// 		HitDistance = Record.t
	// 		// Record.MaterialIndex = 1 // TODO(matthew): set this in the world!
	// 		// Record.SurfaceNormal = v3{0, 0, 0} // TODO(matthew): set this!
	// 	}
	// }

	return HitSomething
}

InitializeCamera :: proc(Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	// TODO(matthew): Bulletproof this. Might still be having issues depending
	// on aspect ratios, etc, but it seems to be fine right now.
	Theta : f32 = Degs2Rads(Camera.FOV)
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

