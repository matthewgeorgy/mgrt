package main

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

