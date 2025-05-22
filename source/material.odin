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

CreateLambertian :: proc(R : v3) -> lambertian
{
	Material : lambertian

	Material.Rho = R

	return Material
}

CreateMetal :: proc(Color : v3, Fuzz : f32) -> metal
{
	Material : metal

	Material.Color = Color
	Material.Fuzz = Fuzz

	return Material
}

CreateDielectric :: proc(RefractionIndex : f32) -> dielectric
{
	Material : dielectric

	Material.RefractionIndex = RefractionIndex

	return Material
}

CreateMERL :: proc(Filename : string) -> merl
{
	Material : merl

	Table := new(merl_table)
	LoadMERL(Filename, Table)

	Material.Table = Table

	return Material
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

