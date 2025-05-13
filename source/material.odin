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
material :: union
{
	lambertian,
	metal,
	dielectric,
}

AddMaterial :: proc{ AddLambertian, AddMetal, AddDielectric, }

AddLambertian :: proc(Scene : ^scene, Lambertian : lambertian) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	append(&Scene.Materials, Lambertian)

	return MaterialIndex
}

AddMetal :: proc(Scene : ^scene, Metal : metal) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	append(&Scene.Materials, Metal)

	return MaterialIndex
}

AddDielectric :: proc(Scene : ^scene, Dielectric : dielectric) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	append(&Scene.Materials, Dielectric)

	return MaterialIndex
}

AddLight :: proc(Scene : ^scene, Light : light) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Lights)

	append(&Scene.Lights, Light)

	return MaterialIndex
}

