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

merl :: struct
{
	Table : ^merl_table,
}

oren_nayar :: struct
{
	R : v3,
	A, B : f32,
}

material_type :: enum
{
	DIFFUSE,
	SPECULAR,
}

material :: union
{
	lambertian,
	metal,
	dielectric,
	merl,
	oren_nayar,
}

GetMaterialType :: proc(Material : material) -> material_type
{
	MaterialType : material_type

	switch Type in Material
	{
		case lambertian, merl, oren_nayar:
		{
			MaterialType = .DIFFUSE
		}

		case metal, dielectric:
		{
			MaterialType = .SPECULAR
		}
	}

	return MaterialType
}

AddMaterial :: proc{ AddLambertian, AddMetal, AddDielectric, AddMERL, AddOrenNayar, }

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

AddMERL :: proc(Scene : ^scene, Table : merl) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	append(&Scene.Materials, Table)

	return MaterialIndex
}

AddOrenNayar :: proc(Scene : ^scene, OrenNayar : oren_nayar) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Materials)

	append(&Scene.Materials, OrenNayar)

	return MaterialIndex
}

CreateOrenNayar :: proc(R : v3, Sigma : f32) -> oren_nayar
{
	Material : oren_nayar

	SigmaRads := Degs2Rads(Sigma)
	Sigma2 := SigmaRads * SigmaRads

	Material.A = 1 - 0.5 * (Sigma2 / (Sigma2 + 0.33))
	Material.B = 0.45 * Sigma2 / (Sigma2 + 0.09)
	Material.R = R

	return Material
}

AddLight :: proc(Scene : ^scene, Light : light) -> u32
{
	MaterialIndex := cast(u32)len(Scene.Lights)

	append(&Scene.Lights, Light)

	return MaterialIndex
}

