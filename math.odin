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
Pow				:: math.pow_f32
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

	Translation : v3,
	Rotation : f32,
};

triangle :: struct
{
	Vertices : [3]v3,
};

aabb :: struct
{
	Min, Max : v3
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

CreateQuadTransformed :: proc(Q, u, v : v3, MatIndex : u32, Translation : v3, Rotation : f32) -> quad
{
	Quad := CreateQuad(Q, u, v, MatIndex)

	Quad.Translation = Translation
	Quad.Rotation = Degs2Rads(Rotation)

	return Quad
}

CreateBox :: proc(A, B : v3, MaterialIndex : u32, Translation : v3, Rotation : f32, World : ^world)
{
	MinCoord := v3{Min(A.x, B.x), Min(A.y, B.y), Min(A.z, B.z)}
	MaxCoord := v3{Max(A.x, B.x), Max(A.y, B.y), Max(A.z, B.z)}

	DeltaX := v3{MaxCoord.x - MinCoord.x, 0, 0}
	DeltaY := v3{0, MaxCoord.y - MinCoord.y, 0}
	DeltaZ := v3{0, 0, MaxCoord.z - MinCoord.z}

    append(&World.Quads, CreateQuadTransformed(v3{MinCoord.x, MinCoord.y, MaxCoord.z},  DeltaX,  DeltaY, MaterialIndex, Translation, Rotation)) // front
    append(&World.Quads, CreateQuadTransformed(v3{MaxCoord.x, MinCoord.y, MaxCoord.z}, -DeltaZ,  DeltaY, MaterialIndex, Translation, Rotation)) // right
    append(&World.Quads, CreateQuadTransformed(v3{MaxCoord.x, MinCoord.y, MinCoord.z}, -DeltaX,  DeltaY, MaterialIndex, Translation, Rotation)) // back
    append(&World.Quads, CreateQuadTransformed(v3{MinCoord.x, MinCoord.y, MinCoord.z},  DeltaZ,  DeltaY, MaterialIndex, Translation, Rotation)) // left
    append(&World.Quads, CreateQuadTransformed(v3{MinCoord.x, MaxCoord.y, MaxCoord.z},  DeltaX, -DeltaZ, MaterialIndex, Translation, Rotation)) // top
    append(&World.Quads, CreateQuadTransformed(v3{MinCoord.x, MinCoord.y, MinCoord.z},  DeltaX,  DeltaZ, MaterialIndex, Translation, Rotation)) // bottom
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

SetFaceNormal :: proc(Ray : ray, Normal : v3, Record : ^hit_record)
{
	Record.IsFrontFace = Dot(Ray.Direction, Normal) < 0
	Record.SurfaceNormal = Record.IsFrontFace ? Normal : -Normal
}

Reflect :: proc(Vector, Normal : v3) -> v3
{
	return Vector - 2 * Dot(Vector, Normal) * Normal
}

Refract :: proc(UV, Normal : v3, AngleRatio : f32) -> v3
{
	CosTheta := Min(Dot(-UV, Normal), 1)
	Perpendicular := AngleRatio * (UV + CosTheta * Normal)
	Parallel := -SquareRoot(Abs(1 - LengthSquared(Perpendicular))) * Normal

	return Perpendicular + Parallel
}

// Shlick approximation
FresnelReflectance :: proc(Cosine, RefractionIndex : f32) -> f32
{
	r0 := (1 - RefractionIndex) / (1 + RefractionIndex)
	r0 = r0 * r0

	return r0 + (1 - r0) * Pow(1 - Cosine, 5)
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

// Moller-Trumbore interesection algorithm
RayIntersectTriangle :: proc(Ray : ray, Record : ^hit_record, Triangle : triangle)
{
	t : f32 = F32_MAX
	Tol : f32 = 1e-8

	V0 := Triangle.Vertices[0]
	V1 := Triangle.Vertices[1]
	V2 := Triangle.Vertices[2]

	Edge1 := V1 - V0
	Edge2 := V2 - V0
	h := Cross(Ray.Direction, Edge2)
	a := Dot(Edge1, h)

	if Abs(a) > Tol
	{
		f : f32 = 1 / a
		S := Ray.Origin - V0
		u : f32 = f * Dot(S, h)

		if !(u < 0 || u > 1)
		{
			Q := Cross(S, Edge1)
			v : f32 = f * Dot(Ray.Direction, Q)

			if !(v < 0 || u + v > 1)
			{
				t = f * Dot(Edge2, Q)

				if t > 0.0001 && t < Record.t
				{
					Record.t = t
					Record.SurfaceNormal = Normalize(Cross(Edge1, Edge2))
				}
			}
		}
	}
}

RayIntersectAABB :: proc(Ray : ray, Record : ^hit_record, AABB : aabb) -> b32
{
	BoxMin := AABB.Min
	BoxMax := AABB.Max

	tx1 := (BoxMin.x - Ray.Origin.x) / Ray.Direction.x
	tx2 := (BoxMax.x - Ray.Origin.x) / Ray.Direction.x

	tMin := Min(tx1, tx2)
	tMax := Max(tx1, tx2)

	ty1 := (BoxMin.y - Ray.Origin.y) / Ray.Direction.y
	ty2 := (BoxMax.y - Ray.Origin.y) / Ray.Direction.y

	tMin = Max(tMin, Min(ty1, ty2))
	tMax = Min(tMax, Max(ty1, ty2))

	tz1 := (BoxMin.z - Ray.Origin.z) / Ray.Direction.z
	tz2 := (BoxMax.z - Ray.Origin.z) / Ray.Direction.z

	tMin = Max(tMin, Min(tz1, tz2))
	tMax = Min(tMax, Max(tz1, tz2))

	return (tMax >= tMin) && (tMin < Record.t) && (tMax > 0)
}

