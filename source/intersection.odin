package main

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

				SetFaceNormal(RotatedRay, Record.SurfaceNormal, Record)
				Record.HitPoint = RotatedRay.Origin + HitDistance * RotatedRay.Direction

				InvertRayTransform(&Record.HitPoint, &Record.SurfaceNormal, Scene.BVH.Translation, Scene.BVH.Rotation)

				Record.MaterialIndex = Scene.BVH.MaterialIndex
				Record.LightIndex = Scene.BVH.LightIndex
			}
		}
	}

	return HitSomething
}

