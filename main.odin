package main

import fmt	"core:fmt"

material :: struct
{
	Color : v3
};

hit_record :: struct
{
	t : f32,
	MaterialIndex  : u32,
	SurfaceNormal : v3,
};

camera :: struct
{
	Center : v3,
	FirstPixel : v3,
	PixelDeltaU : v3,
	PixelDeltaV : v3,

	LookFrom : v3,
	LookAt : v3,
};

world :: struct
{
	Materials : [16]material,
	Spheres : [16]sphere,
	Planes : [16]plane,
	Quads : [16]quad,

	MaterialCount : u32,
	SphereCount : u32,
	PlaneCount : u32,
	QuadCount : u32,
};

main :: proc()
{
	// Image
	Image := AllocateImage(1280, 720)

	// Camera
	Camera : camera

	Camera.LookFrom = v3{0, 0, 9}
	Camera.LookAt = v3{0, 0, 0}

	InitializeCamera(&Camera, Image.Width, Image.Height)

	// World setup
	World : world

	World.Materials[0].Color = v3{0.1, 0.1, 0.1}
	World.Materials[1].Color = v3{1.0, 0.2, 0.2}
	World.Materials[2].Color = v3{0.2, 1.0, 0.2}
	World.Materials[3].Color = v3{0.2, 0.2, 1.0}
	World.Materials[4].Color = v3{1.0, 0.5, 0.0}
	World.Materials[5].Color = v3{0.2, 0.8, 0.8}
	World.MaterialCount = 6

	World.Quads[0] = CreateQuad(v3{-3, -2, 5}, v3{0, 0, -4}, v3{0, 4,  0}, 1)
	World.Quads[1] = CreateQuad(v3{-2, -2, 0}, v3{4, 0,  0}, v3{0, 4,  0}, 2)
	World.Quads[2] = CreateQuad(v3{ 3, -2, 1}, v3{0, 0,  4}, v3{0, 4,  0}, 3)
	World.Quads[3] = CreateQuad(v3{-2,  3, 1}, v3{4, 0,  0}, v3{0, 0,  4}, 4)
	World.Quads[4] = CreateQuad(v3{-2, -3, 5}, v3{4, 0,  0}, v3{0, 0, -4}, 5)
	World.QuadCount = 5

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

	for I : u32 = 0; I < Queue.EntryCount; I += 1
	{
		Order := Queue.WorkOrders[I]
		fmt.println(Order)
		RenderTile(Order, &Camera, &World, &Image)
	}

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
	MatIndex : u32
	HitSomething := false

	if Depth <= 0
	{
		return v3{0, 0, 0}
	}

	for SphereIndex : u32 = 0; SphereIndex < World.SphereCount; SphereIndex += 1
	{
		Sphere := World.Spheres[SphereIndex]

		Record.t = RayIntersectSphere(Ray, Sphere)
		if (Record.t > 0.0001 && Record.t < HitDistance)
		{
			HitSomething = true
			HitDistance = Record.t
			Record.MaterialIndex = Sphere.MatIndex
			Record.SurfaceNormal = Normalize(Ray.Origin + Record.t * Ray.Direction - Sphere.Center)
		}
	}

	for PlaneIndex : u32 = 0; PlaneIndex < World.PlaneCount; PlaneIndex += 1
	{
		Plane := World.Planes[PlaneIndex]

		Record.t = RayIntersectPlane(Ray, Plane)
		if (Record.t > 0.0001 && Record.t < HitDistance)
		{
			HitSomething = true
			HitDistance = Record.t
			Record.MaterialIndex = Plane.MatIndex
			Record.SurfaceNormal = Normalize(Plane.N)
		}
	}

	for QuadIndex : u32 = 0; QuadIndex < World.QuadCount; QuadIndex += 1
	{
		Quad := World.Quads[QuadIndex]

		Record.t = RayIntersectQuad(Ray, Quad)
		if (Record.t > 0.0001 && Record.t < HitDistance)
		{
			HitSomething = true
			HitDistance = Record.t
			Record.MaterialIndex = Quad.MatIndex
			Record.SurfaceNormal = SetFaceNormal(Ray, Quad.N)
		}
	}

	if !HitSomething
	{
		return World.Materials[0].Color
	}

	NewRay : ray
	Color : v3
	Attenuation : v3

	NewRay.Origin = Ray.Origin + HitDistance * Ray.Direction
	NewRay.Direction = RandomOnHemisphere(Record.SurfaceNormal)

	Attenuation = World.Materials[Record.MaterialIndex].Color

	Color = Attenuation * CastRay(NewRay, World, Depth - 1)

	return Color
}

InitializeCamera :: proc(Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	// TODO(matthew): Bulletproof this. Might still be having issues depending
	// on aspect ratios, etc, but it seems to be fine right now.
	FocalLength : f32 = 1.0
	ViewportHeight : f32 = 2
	ViewportWidth : f32 = 2//ViewportHeight * f32(Image.Width) / f32(Image.Height)
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
	ViewportUpperLeft := Camera.Center - v3{0, 0, FocalLength} - (ViewportU / 2) - (ViewportV / 2)
	Camera.FirstPixel = ViewportUpperLeft + 0.5 * (Camera.PixelDeltaU + Camera.PixelDeltaV)
}

