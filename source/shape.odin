package main

import fmt "core:fmt"

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

shape :: union
{
	sphere,
	quad,
	plane,
	triangle,
	aabb,
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

// TODO(matthew): Still quite hardcoded for now, as it assumes that the quads
// are perfectly flat (lie in the xz-plane), as is the case with the cornell
// lights.
// Will need to extend this in the future to handle arbitrary orientations, as
// well as a wider variety of shapes to sample points from.
QuadArea :: proc(Quad : quad) -> f32
{
	MinPoint := Quad.Q
	MaxPoint := Quad.Q + Quad.u + Quad.v

	Area := Abs(MaxPoint.x - MinPoint.x) * Abs(MaxPoint.z - MinPoint.z)

	return Area
}

SamplePoint :: proc{ SampleQuad }

SampleQuad :: proc(Quad : quad) -> v3
{
	StartPoint := Quad.Q
	EndPoint := Quad.Q + Quad.u + Quad.v

	MinPoint := MinV3(StartPoint, EndPoint)
	MaxPoint := MaxV3(StartPoint, EndPoint)

	Point : v3

	Point.x = RandomFloat(MinPoint.x, MaxPoint.x)
	Point.y = MinPoint.y
	Point.z = RandomFloat(MinPoint.z, MaxPoint.z)

	return Point
}

// TODO(matthew): When we come back to update this to support more than one
// light, we need to choose them at random and correct by the PDF in doing so.
SampleRandomLight :: proc(Scene : ^scene) -> (v3, v3, f32)
{
	if len(Scene.LightIndices) == 0
	{
		fmt.println("no lights!")
		return v3{0, 0, 0}, v3{0, 0, 0}, 1
	}

	QuadIndex := Scene.LightIndices[0]
	Quad := Scene.Primitives[QuadIndex].Shape.(quad)
	LightIndex := Scene.Primitives[QuadIndex].LightIndex
	LightColor := Scene.Lights[LightIndex].Le

	Point := SamplePoint(Quad)
	Area := QuadArea(Quad)
	PDF := 1.0 / Area

	return Point, LightColor, PDF
}

