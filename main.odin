package main

import fmt	"core:fmt"
import mem	"core:mem"

material :: struct
{
	Color : v3
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
	LookFrom := v3{0, 0, 2}
	LookAt := v3{0, 0, 0}
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

	World.Materials[0].Color = v3{1, 0, 0}
	World.Materials[1].Color = v3{0, 1, 0}
	World.Materials[2].Color = v3{0, 0, 1}
	World.MaterialCount = 3

	World.Spheres[0] = sphere{v3{0, 0, -1}, 0.5, 0}
	World.Spheres[1] = sphere{v3{0, 1, -2}, 0.5, 1}
	World.SphereCount = 2

	Out : ^u32 = Image.Pixels

	for Y := i32(0); Y < Image.Height; Y += 1
	{
		for X := i32(0); X < Image.Width; X += 1
		{
			PixelCenter := FirstPixel + (f32(X) * PixelDeltaU) + (f32(Y) * PixelDeltaV)

			Ray := ray{CameraCenter, PixelCenter - CameraCenter}

			Color := CastRay(Ray, &World)

			Red := u8(f32(255.999) * Color.r)
			Green := u8(f32(255.999) * Color.g)
			Blue := u8(f32(255.999) * Color.b)

			Out^ = PackRGBA(Red, Green, Blue, 0)
			Out = mem.ptr_offset(Out, 1)
		}
	}

	WriteImage(Image, string("test.bmp"))
}

RayIntersectSphere :: proc(Ray : ray, Sphere : sphere) -> f32
{
	t := f32(F32_MAX)
	OC := Sphere.Center - Ray.Origin
	a := Dot(Ray.Direction, Ray.Direction)
	b := -2.0 * Dot(Ray.Direction, OC)
	c := Dot(OC, OC) - Sphere.Radius * Sphere.Radius
	Discriminant := b * b - 4 * a * c

	if Discriminant >= 0
	{
		t = (-b - SquareRoot(Discriminant) / (2 * a))
	}

	return t
}

CastRay :: proc(Ray : ray, World : ^world) -> v3
{
	UnitDirection := Normalize(Ray.Direction)
	A := 0.5 * (UnitDirection.y + 1)
	Color := (1 - A) * v3{1, 1, 1} + A * v3{0.5, 0.7, 1}

	HitDistance : f32 = F32_MAX
	MatIndex : u32

	for SphereIndex : u32 = 0; SphereIndex < World.SphereCount; SphereIndex += 1
	{
		Sphere := World.Spheres[SphereIndex]

		ThisDistance := RayIntersectSphere(Ray, Sphere)
		if ThisDistance < HitDistance
		{
			HitDistance = ThisDistance
			MatIndex = Sphere.MatIndex
		}
	}

	if HitDistance < F32_MAX
	{
		Color = World.Materials[MatIndex].Color
	}

	return Color
}

