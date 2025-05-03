package main

import fmt	"core:fmt"
import mem	"core:mem"

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

world :: struct
{
	Materials : [16]material,
	Spheres : [16]sphere,
	Planes : [16]plane,

	MaterialCount : u32,
	SphereCount : u32,
	PlaneCount : u32,
};

main :: proc()
{
	Image := AllocateImage(1280, 720)

	// TODO(matthew): Bulletproof this. Might still be having issues depending
	// on aspect ratios, etc, but it seems to be fine right now.
	// Camera
	FocalLength : f32 = 1.0
	ViewportHeight : f32 = 2
	ViewportWidth : f32 = 2//ViewportHeight * f32(Image.Width) / f32(Image.Height)
	LookFrom := v3{0, 0, 1}
	LookAt := v3{0, 0, -1}
	CameraCenter := LookFrom

	if (Image.Width > Image.Height)
	{
		ViewportHeight = ViewportWidth * f32(Image.Height) / f32(Image.Width)
	}
	else
	{
		ViewportWidth = ViewportHeight * f32(Image.Width) / f32(Image.Height)
	}

	CameraW := Normalize(LookFrom - LookAt)
	CameraU := Normalize(Cross(v3{0, 1, 0}, CameraW))
	CameraV := Normalize(Cross(CameraW, CameraU))

	// Viewport
	ViewportU := ViewportWidth * CameraU
	ViewportV := -ViewportHeight * CameraV

	// Pixel deltas
	PixelDeltaU := ViewportU / f32(Image.Width)
	PixelDeltaV := ViewportV / f32(Image.Height)

	// First pixel
	ViewportUpperLeft := CameraCenter - v3{0, 0, FocalLength} - (ViewportU / 2) - (ViewportV / 2)
	FirstPixel := ViewportUpperLeft + 0.5 * (PixelDeltaU + PixelDeltaV)

	// World setup
	World : world

	World.Materials[0].Color = v3{0.1, 0.1, 0.1}
	World.Materials[1].Color = v3{1, 0, 0}
	World.Materials[2].Color = v3{0.2, 0.3, 0.7}
	World.MaterialCount = 3

	World.Spheres[0] = sphere{v3{0, 0, -1}, 0.5, 1}
	World.Spheres[1] = sphere{v3{0, -100.5, -1}, 100, 2}
	World.SphereCount = 2

	Out : ^u32 = Image.Pixels

	for Y := i32(0); Y < Image.Height; Y += 1
	{
		for X := i32(0); X < Image.Width; X += 1
		{
			PixelColor : v3
			SamplesPerPixel : u32 = 8

			for Sample : u32 = 0; Sample < SamplesPerPixel; Sample += 1
			{
				Offset := v3{RandomUnilateral() - 0.5, RandomUnilateral() - 0.5, 0}
				PixelCenter := FirstPixel +
							   ((f32(X) + Offset.x) * PixelDeltaU) +
							   ((f32(Y) + Offset.y) * PixelDeltaV)
	
				Ray := ray{CameraCenter, PixelCenter - CameraCenter}
				PixelColor += CastRay(Ray, &World, 10)
			}

			Color := PixelColor / f32(SamplesPerPixel)
			
			Color.r = LinearTosRGB(Color.r)
			Color.g = LinearTosRGB(Color.g)
			Color.b = LinearTosRGB(Color.b)

			Red := u8(f32(255.999) * Color.r)
			Green := u8(f32(255.999) * Color.g)
			Blue := u8(f32(255.999) * Color.b)

			Out^ = PackRGBA(Red, Green, Blue, 0)
			Out = mem.ptr_offset(Out, 1)
		}
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

	// for PlaneIndex : u32 = 0; PlaneIndex < World.PlaneCount; PlaneIndex += 1
	// {
	// 	Plane := World.Planes[PlaneIndex]

	// 	Record.t = RayIntersectPlane(Ray, Plane)
	// 	if (Record.t > 0 && Record.t < HitDistance)
	// 	{
	// 		HitDistance = Record.t
	// 		Record.MaterialIndex = Plane.MatIndex
	// 	}
	// }

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

