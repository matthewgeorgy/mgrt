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

