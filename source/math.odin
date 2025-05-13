package main

import fmt		"core:fmt"
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
ACos			:: math.acos
ATan2			:: math.atan2
Tan				:: math.tan
Pow				:: math.pow_f32
Degs2Rads		:: math.to_radians_f32
Rads2Degs		:: math.to_degrees_f32

F32_MAX 		:: 3.402823466e+38
PI				: f32 : math.PI

hit_record :: struct
{
	t : f32,
	MaterialIndex  : u32,
	LightIndex  : u32,
	SurfaceNormal : v3,
	HitPoint : v3,
	IsFrontFace : bool,
	BestTriangleIndex : u32,
};

HasLight :: proc(Record : hit_record) -> bool
{
	return Record.LightIndex != 0
}

ray :: struct
{
	Origin : v3,
	Direction : v3,
};

sphere :: struct
{
	Center : v3,
	Radius : f32,
};

plane :: struct
{
	N : v3,
	d : f32,
};

quad :: struct
{
	Q : v3,
	u : v3,
	v : v3,
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

shape_type :: enum
{
	SPHERE,
	QUAD,
	PLANE,
	TRIANGLE,
	AABB,
}

shape :: struct
{
	Type : shape_type,

	Variant : union{ sphere, quad, plane, triangle, aabb },
}

primitive :: struct
{
	Shape : shape,

	MaterialIndex : u32,
	LightIndex : u32,
}

RandomUnilateral :: proc() -> f32
{
	return rand.float32()
}

RandomBilateral :: proc() -> f32
{
	Result := 2.0 * RandomUnilateral() - 1

	return Result
}

RandomFloat :: proc(Min, Max : f32) -> f32
{
	Rand := RandomUnilateral()
	Result := Min + (Max - Min) * Rand

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

RandomCosineDirection :: proc() -> v3
{
	Rand1 := RandomUnilateral()
    Rand2 := RandomUnilateral()

    Phi := 2 * PI * Rand1

	x := Cos(Phi) * SquareRoot(Rand2)
    y := Sin(Phi) * SquareRoot(Rand2)
    z := SquareRoot(1 - Rand2)

    return v3{x, y, z}
}

CreateQuad :: proc(Q, u, v : v3) -> quad
{
	Quad : quad

	Quad.Q = Q
	Quad.u = u
	Quad.v = v

	N := Cross(u, v)

	Quad.N = Normalize(N)
	Quad.d = Dot(Quad.N, Q)
	Quad.w = N / Dot(N, N)

	return Quad
}

CreateQuadTransformed :: proc(Q, u, v : v3, Translation : v3, Rotation : f32) -> quad
{
	Quad := CreateQuad(Q, u, v)

	Quad.Translation = Translation
	Quad.Rotation = Degs2Rads(Rotation)

	return Quad
}

// NOTE(matthew): don't really like this! Would be nicer if CreateBox just
// returned the primitive and then we add it explicitly...
CreateBox :: proc(A, B : v3, Translation : v3, Rotation : f32, MaterialIndex : u32, LightIndex : u32, Scene : ^scene)
{
	MinCoord := v3{Min(A.x, B.x), Min(A.y, B.y), Min(A.z, B.z)}
	MaxCoord := v3{Max(A.x, B.x), Max(A.y, B.y), Max(A.z, B.z)}

	DeltaX := v3{MaxCoord.x - MinCoord.x, 0, 0}
	DeltaY := v3{0, MaxCoord.y - MinCoord.y, 0}
	DeltaZ := v3{0, 0, MaxCoord.z - MinCoord.z}

    AddPrimitive(Scene, CreateQuadTransformed(v3{MinCoord.x, MinCoord.y, MaxCoord.z},  DeltaX,  DeltaY, Translation, Rotation), MaterialIndex, LightIndex) // front
    AddPrimitive(Scene, CreateQuadTransformed(v3{MaxCoord.x, MinCoord.y, MaxCoord.z}, -DeltaZ,  DeltaY, Translation, Rotation), MaterialIndex, LightIndex) // right
    AddPrimitive(Scene, CreateQuadTransformed(v3{MaxCoord.x, MinCoord.y, MinCoord.z}, -DeltaX,  DeltaY, Translation, Rotation), MaterialIndex, LightIndex) // back
    AddPrimitive(Scene, CreateQuadTransformed(v3{MinCoord.x, MinCoord.y, MinCoord.z},  DeltaZ,  DeltaY, Translation, Rotation), MaterialIndex, LightIndex) // left
    AddPrimitive(Scene, CreateQuadTransformed(v3{MinCoord.x, MaxCoord.y, MaxCoord.z},  DeltaX, -DeltaZ, Translation, Rotation), MaterialIndex, LightIndex) // top
    AddPrimitive(Scene, CreateQuadTransformed(v3{MinCoord.x, MinCoord.y, MinCoord.z},  DeltaX,  DeltaZ, Translation, Rotation), MaterialIndex, LightIndex) // bottom
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
RayIntersectTriangle :: proc(Ray : ray, Triangle : triangle) -> f32
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
			}
		}
	}

	return t
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

TransformRay :: proc(Ray : ray, Translation : v3, Rotation : f32) -> ray
{
	OffsetRay := Ray

	OffsetRay.Origin += Translation

	SinTheta := Sin(Rotation)
	CosTheta := Cos(Rotation)

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

	return RotatedRay
}

InvertRayTransform :: proc(Point, Normal : ^v3, Translation : v3, Rotation : f32)
{
	CosTheta := Cos(Rotation)
	SinTheta := Sin(Rotation)

	NewPoint := v3{
		(CosTheta * Point.x) + (SinTheta * Point.z),
		Point.y,
		(-SinTheta * Point.x) + (CosTheta * Point.z)
	}

	NewNormal := v3{
		(CosTheta * Normal.x) + (SinTheta * Normal.z),
		Normal.y,
		(-SinTheta * Normal.x) + (CosTheta * Normal.z)
	}

	NewPoint -= Translation

	Point^ = NewPoint
	Normal^ = NewNormal
}

GetIntersection :: proc(Ray : ray, Scene : ^scene, Record : ^hit_record) -> bool
{
	Record.t = F32_MAX

	HitDistance : f32 = F32_MAX
	HitSomething := false

	for Primitive in Scene.Primitives
	{
		if Primitive.Shape.Type == .QUAD
		{
			Quad := Primitive.Shape.Variant.(quad)
			RotatedRay := TransformRay(Ray, Quad.Translation, Quad.Rotation)

			Record.t = RayIntersectQuad(RotatedRay, Quad)
			if (Record.t > 0.0001 && Record.t < HitDistance)
			{
				HitSomething = true
				HitDistance = Record.t
				SetFaceNormal(RotatedRay, Quad.N, Record)
				Record.HitPoint = RotatedRay.Origin + HitDistance * RotatedRay.Direction

				InvertRayTransform(&Record.HitPoint, &Record.SurfaceNormal, Quad.Translation, Quad.Rotation)

				Record.MaterialIndex = Primitive.MaterialIndex
				Record.LightIndex = Primitive.LightIndex
			}
		}
		else if Primitive.Shape.Type == .PLANE
		{
			Plane := Primitive.Shape.Variant.(plane)
			Record.t = RayIntersectPlane(Ray, Plane)

			if Record.t > 0.0001 && Record.t < HitDistance
			{
				HitSomething = true
				HitDistance = Record.t
				SetFaceNormal(Ray, Plane.N, Record)
				Record.HitPoint = Ray.Origin + HitDistance * Ray.Direction

				Record.MaterialIndex = Primitive.MaterialIndex
				Record.LightIndex = Primitive.LightIndex
			}
		}
		else if Primitive.Shape.Type == .SPHERE
		{
			Sphere := Primitive.Shape.Variant.(sphere)
			Record.t = RayIntersectSphere(Ray, Sphere)

			if Record.t > 0.0001 && Record.t < HitDistance
			{
				HitSomething = true
				HitDistance = Record.t
				Record.HitPoint = Ray.Origin + HitDistance * Ray.Direction
				OutwardNormal := Normalize(Record.HitPoint - Sphere.Center)

				SetFaceNormal(Ray, OutwardNormal, Record)

				Record.MaterialIndex = Primitive.MaterialIndex
				Record.LightIndex = Primitive.LightIndex
			}
		}

		// for Triangle in Scene.Triangles
		// {
		// 	RayIntersectTriangle(Ray, &Record, Triangle)
		// 	if (Record.t > 0.0001 && Record.t < HitDistance)
		// 	{
		// 		HitSomething = true
		// 		HitDistance = Record.t
		// 		// Record.MaterialIndex = 1 // TODO(matthew): set this in the scene!
		// 		// Record.SurfaceNormal = v3{0, 0, 0} // TODO(matthew): set this!
		// 	}
		// }

		if Scene.BVH.NodesUsed != 0
		{
			RotatedRay := TransformRay(Ray, Scene.BVH.Translation, Scene.BVH.Rotation)

			TraverseBVH(RotatedRay, Record, Scene.BVH, Scene.BVH.RootNodeIndex)
			if Record.t > 0.0001 && Record.t < HitDistance
			{
				HitSomething = true
				HitDistance = Record.t

				// Compute surface normal from the best triangle intersection
				{
					Triangle := Scene.BVH.Triangles[Record.BestTriangleIndex]

					V0 := Triangle.Vertices[0]
					V1 := Triangle.Vertices[1]
					V2 := Triangle.Vertices[2]

					Record.SurfaceNormal = Normalize(Cross(V1 - V0, V2 - V0))
				}

				Record.MaterialIndex = Scene.BVH.MatIndex
				SetFaceNormal(RotatedRay, Record.SurfaceNormal, Record)
				Record.HitPoint = RotatedRay.Origin + HitDistance * RotatedRay.Direction

				InvertRayTransform(&Record.HitPoint, &Record.SurfaceNormal, Scene.BVH.Translation, Scene.BVH.Rotation)
			}
		}
	}

	return HitSomething
}

