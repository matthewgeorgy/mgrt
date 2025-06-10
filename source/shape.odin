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

CreateBox :: proc(A, B : v3, Translation : v3, Rotation : f32) -> []quad
{
	Box := make([]quad, 6)

	MinCoord := v3{Min(A.x, B.x), Min(A.y, B.y), Min(A.z, B.z)}
	MaxCoord := v3{Max(A.x, B.x), Max(A.y, B.y), Max(A.z, B.z)}

	DeltaX := v3{MaxCoord.x - MinCoord.x, 0, 0}
	DeltaY := v3{0, MaxCoord.y - MinCoord.y, 0}
	DeltaZ := v3{0, 0, MaxCoord.z - MinCoord.z}

    Box[0] = CreateQuadTransformed(v3{MinCoord.x, MinCoord.y, MaxCoord.z},  DeltaX,  DeltaY, Translation, Rotation) // front
    Box[1] = CreateQuadTransformed(v3{MaxCoord.x, MinCoord.y, MaxCoord.z}, -DeltaZ,  DeltaY, Translation, Rotation) // right
    Box[2] = CreateQuadTransformed(v3{MaxCoord.x, MinCoord.y, MinCoord.z}, -DeltaX,  DeltaY, Translation, Rotation) // back
    Box[3] = CreateQuadTransformed(v3{MinCoord.x, MinCoord.y, MinCoord.z},  DeltaZ,  DeltaY, Translation, Rotation) // left
    Box[4] = CreateQuadTransformed(v3{MinCoord.x, MaxCoord.y, MaxCoord.z},  DeltaX, -DeltaZ, Translation, Rotation) // top
    Box[5] = CreateQuadTransformed(v3{MinCoord.x, MinCoord.y, MinCoord.z},  DeltaX,  DeltaZ, Translation, Rotation) // bottom

	return Box
}

GetArea :: proc(Shape : shape) -> f32
{
	Area : f32

	#partial switch Type in Shape
	{
		case sphere:
		{
			Area = GetArea_Sphere(Shape.(sphere))
		}

		case quad:
		{
			Area = GetArea_Quad(Shape.(quad))
		}

		case triangle:
		{
			Area = GetArea_Triangle(Shape.(triangle))
		}
	}

	return Area
}

GetArea_Sphere :: proc(Sphere : sphere) -> f32
{
	return 4 * PI * Sphere.Radius * Sphere.Radius
}

GetArea_Quad :: proc(Quad : quad) -> f32
{
	V0 := Quad.Q
	V1 := Quad.Q + Quad.u
	V2 := Quad.Q + Quad.v

	Edge1 := V1 - V0
	Edge2 := V2 - V0

	Area := Length(Cross(Edge1, Edge2))

	return Area
}

GetArea_Triangle :: proc(Triangle : triangle) -> f32
{
	Edge1 := Triangle.Vertices[1] - Triangle.Vertices[0]
	Edge2 := Triangle.Vertices[2] - Triangle.Vertices[0]

	Area := 0.5 * Length(Cross(Edge1, Edge2))

	return Area
}

SamplePoint :: proc(Shape : shape) -> v3
{
	Point : v3

	#partial switch Type in Shape
	{
		case quad:
		{
			Point = SamplePoint_Quad(Shape.(quad))
		}

		case triangle:
		{
			Point = SamplePoint_Triangle(Shape.(triangle))
		}
	}

	return Point
}

SamplePoint_Triangle :: proc(Triangle : triangle) -> v3
{
	uv := v2{RandomUnilateral(), RandomUnilateral()}
	su0 := SquareRoot(uv[0])

	Barycentric := v2{1 - su0, uv[1] * su0}

	Point := (1 - Barycentric[0] - Barycentric[1]) * Triangle.Vertices[0] +
			 (Barycentric[0] * Triangle.Vertices[1]) +
			 (Barycentric[1] * Triangle.Vertices[2])

	return Point
}

SamplePoint_Quad :: proc(Quad : quad) -> v3
{
	u := RandomUnilateral()
	v := RandomUnilateral()

	Point := Quad.Q + (u * Quad.u) + (v * Quad.v)

	return Point
}

