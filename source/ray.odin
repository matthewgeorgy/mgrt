package main

ray :: struct
{
	Origin : v3,
	Direction : v3,
};

// Applies rotation and translation to a ray for instancing
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

// Inverts the hit point and surface normal we found using the inverse of the
// ray transform from above
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
