package main

import math		"core:math"
import linalg	"core:math/linalg"
import rand		"core:math/rand"

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
Sin				:: math.sin
Cos				:: math.cos
Tan				:: math.tan
Degs2Rads		:: math.to_radians_f32
Rads2Degs		:: math.to_degrees_f32

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

quad :: struct
{
	Q : v3,
	u : v3,
	v : v3,
	MatIndex : u32,
	N : v3,
	d : f32,
	w : v3,
};

RandomUnilateral :: proc() -> f32
{
	return rand.float32()
}

RandomBilateral :: proc() -> f32
{
	Result := 2.0 * RandomUnilateral() - 1

	return Result
}

RandomUnitVector :: proc() -> v3
{
	for
	{
		P := v3{RandomBilateral(), RandomBilateral(), RandomBilateral()}
		L := LengthSquared(P)

		if (1e-20 < L && L <= 1)
		{
			return P / SquareRoot(L)
		}
	}
}

RandomOnHemisphere :: proc(Normal : v3) -> v3
{
	OnUnitSphere := RandomUnitVector()

	if Dot(OnUnitSphere, Normal) > 0
	{
		return OnUnitSphere
	}
	else
	{
		return -OnUnitSphere
	}
}

CreateQuad :: proc(Q, u, v : v3, MatIndex : u32) -> quad
{
	Quad : quad

	Quad.Q = Q
	Quad.u = u
	Quad.v = v
	Quad.MatIndex = MatIndex

	N := Cross(u, v)

	Quad.N = Normalize(N)
	Quad.d = Dot(Quad.N, Q)
	Quad.w = N / Dot(N, N)

	return Quad
}

RayIntersectQuad :: proc(Ray : ray, Quad : quad) -> f32
{
	t : f32 = F32_MAX
	Tol : f32 = 1e-8
	Denom : f32 = Dot(Quad.N, Ray.Direction)

	if Abs(Denom) > Tol
	{
		t = (Quad.d - Dot(Quad.N, Ray.Origin)) / Denom

		Intersection := Ray.Origin + t * Ray.Direction
		PlanarHitPointVector := Intersection - Quad.Q

		Alpha : f32 = Dot(Quad.w, Cross(PlanarHitPointVector, Quad.v))
		Beta : f32 = Dot(Quad.w, Cross(Quad.u, PlanarHitPointVector))

		if !(Alpha >= 0 && Alpha <= 1) || !(Beta >= 0 && Beta <= 1)
		{
			t = F32_MAX
		}
	}

	return t
}

SetFaceNormal :: proc(Ray : ray, Normal : v3) -> v3
{
	IsFrontFace := Dot(Ray.Direction, Normal) < 0

	return IsFrontFace ? Normal : -Normal
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
		// Take the closer intersection
		tp := (-b + SquareRoot(Discriminant)) / (2 * a)
		tn := (-b - SquareRoot(Discriminant)) / (2 * a)
		t = tp
		
		if tn > 0.0001 && tn < tp
		{
			t = tn
		}
	}

	if t < 0
	{
		t = F32_MAX
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

