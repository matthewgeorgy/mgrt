package main

import "core:math/linalg"

v3f	:: [3]f32
v3i :: [3]i32
v3u :: [3]u32
v3 	:: v3f

Cross 			:: linalg.cross
Dot 			:: linalg.dot
Normalize 		:: linalg.normalize
Length 			:: linalg.length
LengthSquared	:: linalg.length2
SquareRoot 		:: linalg.sqrt
Abs 			:: abs
Min 			:: min
Max 			:: max

F32_MAX 		:: 3.402823466e+38

ray :: struct
{
	Origin : v3,
	Direction : v3,
};

sphere :: struct
{
	Center : v3,
	Radius : f32,
	MatIndex : u32,
};

plane :: struct
{
	N : v3,
	d : f32,
	MatIndex : u32,
};

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

RayIntersectPlane :: proc(Ray : ray, Plane : plane) -> f32
{
	t : f32 = F32_MAX
	Tol : f32 = 0.0001
	Denom : f32 = Dot(Plane.N, Ray.Direction)

	if Abs(Denom) > Tol
	{
		t = (-Plane.d - Dot(Plane.N, Ray.Origin)) / Denom
	}
	
	return t
}

