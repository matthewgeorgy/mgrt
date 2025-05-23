package main

import fmt "core:fmt"

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

light_surface :: struct
{
	Point : v3,
	Normal : v3,
	Color : v3,
	PDF : f32,
}

// TODO(matthew): When we come back to update this to support more than one
// light, we need to choose them at random and correct by the PDF in doing so.
SampleRandomLight :: proc(Scene : ^scene) -> light_surface
{
	LightSurface : light_surface

	if len(Scene.LightIndices) == 0
	{
		fmt.println("no lights!")
		return LightSurface
	}

	PrimitiveIndex := Scene.LightIndices[0]
	Primitive := Scene.Primitives[PrimitiveIndex]
	Shape := Primitive.Shape

	LightIndex := Primitive.LightIndex
	LightColor := Scene.Lights[LightIndex].Le

	Area := GetArea(Shape)

	if _, ok := Shape.(quad); ok
	{
		LightSurface.Normal = Shape.(quad).N
	}

	LightSurface.Point = SamplePoint(Shape)
	LightSurface.Color = LightColor
	LightSurface.PDF = 1.0 / Area

	return LightSurface
}

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

