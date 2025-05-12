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

bxdf_type :: enum
{
	DIFFUSE = 1,
	METAL = 2,
	DIELECTRIC = 3,
}

bxdf :: struct
{
	Type : bxdf_type,

	using _ : struct #raw_union { Lambertian : lambertian, Metal : metal, Dielectric : dielectric }
}

material_type :: enum
{
	BXDF = 1,
	LIGHT = 2,
}

material :: struct
{
	Type : material_type,

	using _ : struct #raw_union { BxDF : bxdf, Light : light, }
}

bxdf_sample :: struct
{
	wi : v3,
	PDF : f32,
	f : v3,
}

EvaluateBxDF :: proc(BxDF : bxdf, wo, wi : v3) -> v3
{
	f : v3

	Type := BxDF.Type

	switch Type
	{
		case bxdf_type.DIFFUSE:
		{
			f = EvaluateLambertianBRDF(BxDF.Lambertian, wo, wi)
		}
		case bxdf_type.METAL:
		{
			f = EvaluateMetalBRDF(BxDF.Metal, wo, wi)
		}
		case bxdf_type.DIELECTRIC:
		{
			f = EvaluateDielectricBRDF(BxDF.Dielectric, wo, wi)
		}
	}

	return f
}

SampleBxDF :: proc(BxDF : bxdf, wo : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Type := BxDF.Type

	switch Type
	{
		case bxdf_type.DIFFUSE:
		{
			Sample = SampleLambertianBRDF(BxDF.Lambertian, wo, Record)
		}
		case bxdf_type.METAL:
		{
			Sample = SampleMetalBRDF(BxDF.Metal, wo, Record)
		}
		case bxdf_type.DIELECTRIC:
		{
			Sample = SampleDielectricBRDF(BxDF.Dielectric, wo, Record)
		}
	}

	return Sample
}

// TODO(matthew): need to correct this and Sample function, as the PDF should just be
// CosineTheta / PI. However, we also need to check for valid angles when computing
// the BRDF, since the case where the PDF is "0" is when wo and wi are under the surface.
// Can do this by converting wo and wi to local coordinate system, checking their cosine
// (which is just the z-component), and then returning either Rho / PI or 0 accordingly.
// NOTE(matthew): this technically shouldn't be necessary, but I guess for completeness
// I should add it...?
EvaluateLambertianBRDF :: proc(BRDF : lambertian, wo, wi : v3) -> v3
{
	return BRDF.Rho / PI
}

SampleLambertianBRDF :: proc(BRDF : lambertian, wo : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Basis := CreateBasis(Record.SurfaceNormal)
	Sample.wi = BasisTransform(Basis, RandomCosineDirection())

	CosineTheta := Dot(Normalize(Sample.wi), Basis.w)
	Sample.PDF = CosineTheta / PI

	Sample.f = EvaluateLambertianBRDF(BRDF, wo, Sample.wi)

	return Sample
}

EvaluateMetalBRDF :: proc(BRDF : metal, wo, wi : v3) -> v3
{
	// NOTE(matthew): delta function
	return v3{0, 0, 0}
}

SampleMetalBRDF :: proc(BRDF : metal, wo : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Reflected := Reflect(wo, Record.SurfaceNormal)
	Sample.wi = Normalize(Reflected) + (BRDF.Fuzz * RandomUnitVector())

	Sample.f = BRDF.Color / Abs(Dot(Sample.wi, Record.SurfaceNormal)) // Cancel out CosAtten term
	Sample.PDF = 1

	return Sample
}

EvaluateDielectricBRDF :: proc(BRDF : dielectric, wo, wi : v3) -> v3
{
	// NOTE(matthew): delta function
	return v3{0, 0, 0}
}

SampleDielectricBRDF :: proc(BRDF : dielectric, wo : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Attenuation := v3{1, 1, 1}
	Ri := Record.IsFrontFace ? (1.0 / BRDF.RefractionIndex) : BRDF.RefractionIndex

	UnitDirection := Normalize(wo)

	// For handling total internal reflection
	CosTheta := Min(Dot(-UnitDirection, Record.SurfaceNormal), 1)
	SinTheta := SquareRoot(1.0 - CosTheta * CosTheta)

	NewDirection : v3
	CannotRefract := Ri * SinTheta > 1.0

	if (CannotRefract || FresnelReflectance(CosTheta, Ri) > RandomUnilateral())
	{
		NewDirection = Reflect(UnitDirection, Record.SurfaceNormal)
	}
	else
	{
		NewDirection = Refract(UnitDirection, Record.SurfaceNormal, Ri)
	}

	Sample.f = Attenuation / Abs(Dot(NewDirection, Record.SurfaceNormal))
	Sample.PDF = 1
	Sample.wi = NewDirection

	return Sample
}

AddMaterial :: proc{ AddLambertian, AddLight, AddMetal, AddDielectric, }

AddLambertian :: proc(World : ^world, Lambertian : lambertian) -> u32
{
	MaterialIndex := cast(u32)len(World.Materials)

	Material : material

	Material.Type = material_type.BXDF
	Material.BxDF.Type = bxdf_type.DIFFUSE
	Material.BxDF.Lambertian = Lambertian

	append(&World.Materials, Material)

	return MaterialIndex
}

AddMetal :: proc(World : ^world, Metal : metal) -> u32
{
	MaterialIndex := cast(u32)len(World.Materials)

	Material : material

	Material.Type = material_type.BXDF
	Material.BxDF.Type = bxdf_type.METAL
	Material.BxDF.Metal = Metal

	append(&World.Materials, Material)

	return MaterialIndex
}

AddDielectric :: proc(World : ^world, Dielectric : dielectric) -> u32
{
	MaterialIndex := cast(u32)len(World.Materials)

	Material : material

	Material.Type = material_type.BXDF
	Material.BxDF.Type = bxdf_type.DIELECTRIC
	Material.BxDF.Dielectric = Dielectric

	append(&World.Materials, Material)

	return MaterialIndex
}

AddLight :: proc(World : ^world, Light : light) -> u32
{
	MaterialIndex := cast(u32)len(World.Materials)

	Material : material

	Material.Type = material_type.LIGHT
	Material.Light.Le = Light.Le

	append(&World.Materials, Material)

	return MaterialIndex
}

