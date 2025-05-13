package main

light :: struct
{
	Le : v3,
}

lambertian :: struct
{
	Rho : v3,
}

metal :: struct
{
	Color : v3,
	Fuzz : f32,
}

dielectric :: struct
{
	RefractionIndex : f32,
}

material_type :: enum
{
	DIFFUSE = 1,
	METAL = 2,
	DIELECTRIC = 3,
}

material :: struct
{
	Type : material_type,

	using _ : struct #raw_union { Lambertian : lambertian, Metal : metal, Dielectric : dielectric }
}

AddMaterial :: proc{ AddLambertian, AddMetal, AddDielectric, }

AddLambertian :: proc(Scene : ^scene, Lambertian : lambertian) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	Material : material

	Material.Type = material_type.DIFFUSE
	Material.Lambertian = Lambertian

	append(&Scene.Materials, Material)

	return MaterialIndex
}

AddMetal :: proc(Scene : ^scene, Metal : metal) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	Material : material

	Material.Type = material_type.METAL
	Material.Metal = Metal

	append(&Scene.Materials, Material)

	return MaterialIndex
}

AddDielectric :: proc(Scene : ^scene, Dielectric : dielectric) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	Material : material

	Material.Type = material_type.DIELECTRIC
	Material.Dielectric = Dielectric

	append(&Scene.Materials, Material)

	return MaterialIndex
}

AddLight :: proc(Scene : ^scene, Light : light) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Lights)

	append(&Scene.Lights, Light)

	return MaterialIndex
}

