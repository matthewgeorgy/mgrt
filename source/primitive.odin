package main

primitive :: struct
{
	Shape : shape,

	MaterialIndex : u32,
	LightIndex : u32,
}

AddPrimitive :: proc{ AddSphere, AddQuad, AddPlane, AddTriangle, AddAABB }

AddSphere :: proc(Scene : ^scene, Sphere : sphere, MaterialIndex : u32, LightIndex : u32) -> u32
{
	PrimitiveIdx := u32(len(Scene.Primitives))

	Primitive : primitive

	Primitive.Shape.Type = .SPHERE
	Primitive.Shape.Variant = Sphere
	Primitive.MaterialIndex = MaterialIndex
	Primitive.LightIndex = LightIndex

	append(&Scene.Primitives, Primitive)

	return PrimitiveIdx
}

AddQuad :: proc(Scene : ^scene, Quad : quad, MaterialIndex : u32, LightIndex : u32) -> u32
{
	PrimitiveIdx := u32(len(Scene.Primitives))

	Primitive : primitive

	Primitive.Shape.Type = .QUAD
	Primitive.Shape.Variant = Quad
	Primitive.MaterialIndex = MaterialIndex
	Primitive.LightIndex = LightIndex

	append(&Scene.Primitives, Primitive)

	return PrimitiveIdx
}

AddPlane :: proc(Scene : ^scene, Plane : plane, MaterialIndex : u32, LightIndex : u32) -> u32
{
	PrimitiveIdx := u32(len(Scene.Primitives))

	Primitive : primitive

	Primitive.Shape.Type = .PLANE
	Primitive.Shape.Variant = Plane
	Primitive.MaterialIndex = MaterialIndex
	Primitive.LightIndex = LightIndex

	append(&Scene.Primitives, Primitive)

	return PrimitiveIdx
}

AddTriangle :: proc(Scene : ^scene, Triangle : triangle, MaterialIndex : u32, LightIndex : u32) -> u32
{
	PrimitiveIdx := u32(len(Scene.Primitives))

	Primitive : primitive

	Primitive.Shape.Type = .TRIANGLE
	Primitive.Shape.Variant = Triangle
	Primitive.MaterialIndex = MaterialIndex
	Primitive.LightIndex = LightIndex

	append(&Scene.Primitives, Primitive)

	return PrimitiveIdx
}

AddAABB :: proc(Scene : ^scene, AABB : aabb, MaterialIndex : u32, LightIndex : u32) -> u32
{
	PrimitiveIdx := u32(len(Scene.Primitives))

	Primitive : primitive

	Primitive.Shape.Type = .AABB
	Primitive.Shape.Variant = AABB
	Primitive.MaterialIndex = MaterialIndex
	Primitive.LightIndex = LightIndex

	append(&Scene.Primitives, Primitive)

	return PrimitiveIdx
}

