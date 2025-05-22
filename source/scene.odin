package main

scene :: struct
{
	Materials : [dynamic]material,
	Lights : [dynamic]light,

	Primitives : [dynamic]primitive,
	LightIndices : [dynamic]u32,

	BVH : bvh,
	GlobalPhotonMap : ^photon_map,
	CausticPhotonMap : ^photon_map,

	SamplesPerPixel : u32,
	MaxDepth : int,
};

GatherLightIndices :: proc(Scene : ^scene)
{
	if len(Scene.Lights) != 0
	{
		for Primitive, Index in Scene.Primitives
		{
			if Primitive.LightIndex != 0
			{
				append(&Scene.LightIndices, u32(Index))
			}
		}
	}
}

AddMaterial :: proc{
	AddMaterial_Lambertian,
	AddMaterial_Metal,
	AddMaterial_Dielectric,
	AddMaterial_MERL,
	AddMaterial_OrenNayar,
}

AddLight :: proc(Scene : ^scene, Light : light) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Lights)

	append(&Scene.Lights, Light)

	return MaterialIndex
}

AddMaterial_Lambertian :: proc(Scene : ^scene, Lambertian : lambertian) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	append(&Scene.Materials, Lambertian)

	return MaterialIndex
}

AddMaterial_Metal :: proc(Scene : ^scene, Metal : metal) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	append(&Scene.Materials, Metal)

	return MaterialIndex
}

AddMaterial_Dielectric :: proc(Scene : ^scene, Dielectric : dielectric) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	append(&Scene.Materials, Dielectric)

	return MaterialIndex
}

AddMaterial_MERL :: proc(Scene : ^scene, Table : merl) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	append(&Scene.Materials, Table)

	return MaterialIndex
}

AddMaterial_OrenNayar :: proc(Scene : ^scene, OrenNayar : oren_nayar) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	append(&Scene.Materials, OrenNayar)

	return MaterialIndex
}

