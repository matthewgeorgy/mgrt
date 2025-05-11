package main

light :: struct
{
	Le : v3,
}

lambertian :: struct
{
	Rho : v3,
}

bxdf_type :: enum
{
	DIFFUSE = 1,
	SPECULAR = 2,
}

bxdf :: struct
{
	Type : bxdf_type,

	using _ : struct #raw_union { Lambertian : lambertian, }
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

	#partial switch Type
	{
		case bxdf_type.DIFFUSE:
		{
			f = EvaluateLambertianBRDF(BxDF.Lambertian, wo, wi)
		}
	}

	return f
}

SampleBxDF :: proc(BxDF : bxdf, wo, Normal : v3) -> bxdf_sample
{
	Sample : bxdf_sample

	Type := BxDF.Type

	#partial switch Type
	{
		case bxdf_type.DIFFUSE:
		{
			Sample = SampleLambertianBRDF(BxDF.Lambertian, wo, Normal)
		}
	}

	return Sample
}

EvaluateLambertianBRDF :: proc(BRDF : lambertian, wo, wi : v3) -> v3
{
	return BRDF.Rho / PI
}

SampleLambertianBRDF :: proc(BRDF : lambertian, wo, Normal : v3) -> bxdf_sample
{
	Sample : bxdf_sample

	Basis := CreateBasis(Normal)
	Sample.wi = BasisTransform(Basis, RandomCosineDirection())

	CosineTheta := Dot(Normalize(Sample.wi), Basis.w)
	Sample.PDF = Max(0, CosineTheta / PI)

	Sample.f = BRDF.Rho / PI

	return Sample
}

AddMaterial :: proc{ AddLambertian, AddLight }

AddLambertian :: proc(World : ^world, Lambertian : lambertian) -> u32
{
	MaterialIndex := cast(u32)len(World.Materials)

	Material : material

	Material.Type = material_type.BXDF
	Material.BxDF.Lambertian.Rho = Lambertian.Rho
	Material.BxDF.Type = bxdf_type.DIFFUSE

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

// lambertian :: struct
// {
// 	Color : v3,
// };

// metal :: struct
// {
// 	Color : v3,
// 	Fuzz : f32,
// };

// light :: struct
// {
// 	Color : v3,
// };

// dielectric :: struct
// {
// 	RefractionIndex : f32,
// };

// material :: union
// {
// 	lambertian,
// 	metal,
// 	dielectric,
// 	light,
// };

// scatter_record :: struct
// {
// 	NewRay : ray,
// 	EmittedColor : v3,
// 	Attenuation : v3,
// 	ScatterAgain : bool,
// 	PDFValue : f32,
// };

// Scatter :: proc(SurfaceMaterial : material, Ray : ray, Record : hit_record) -> scatter_record
// {
// 	SRecord : scatter_record

// 	switch Type in SurfaceMaterial
// 	{
// 		case lambertian:
// 		{
// 			SRecord = ScatterLambertian(SurfaceMaterial.(lambertian), Ray, Record)
// 		}
// 		case metal:
// 		{
// 			SRecord = ScatterMetal(SurfaceMaterial.(metal), Ray, Record)
// 		}
// 		case dielectric:
// 		{
// 			SRecord = ScatterDielectric(SurfaceMaterial.(dielectric), Ray, Record)
// 		}
// 		case light:
// 		{
// 			if Record.IsFrontFace
// 			{
// 				SRecord.EmittedColor = SurfaceMaterial.(light).Color
// 			}
// 			else
// 			{
// 				SRecord.EmittedColor = v3{0, 0, 0}
// 			}

// 			SRecord.ScatterAgain = false // no scattering, just emit color
// 		}
// 	}

// 	return SRecord
// }

// ScatterLambertian :: proc(Material : lambertian, Ray : ray, Record : hit_record) -> scatter_record
// {
// 	SRecord : scatter_record

// 	Basis := CreateBasis(Record.SurfaceNormal)
// 	ScatterDirection := BasisTransform(Basis, RandomCosineDirection())

// 	SRecord.Attenuation = Material.Color / PI
// 	SRecord.NewRay = ray{Record.HitPoint, ScatterDirection}
// 	SRecord.ScatterAgain = true

// 	return SRecord
// }

// ScatterMetal :: proc(Material : metal, Ray : ray, Record : hit_record) -> scatter_record
// {
// 	SRecord : scatter_record

// 	Reflected := Reflect(Ray.Direction, Record.SurfaceNormal)
// 	Reflected = Normalize(Reflected) + (Material.Fuzz * RandomUnitVector())
// 	SRecord.NewRay = ray{Record.HitPoint, Reflected}
// 	SRecord.Attenuation = Material.Color
// 	SRecord.ScatterAgain = Dot(SRecord.NewRay.Direction, Record.SurfaceNormal) > 0

// 	return SRecord
// }

// ScatterDielectric :: proc(Material : dielectric, Ray : ray, Record : hit_record) -> scatter_record
// {
// 	SRecord : scatter_record

// 	Ri := Record.IsFrontFace ? (1.0 / Material.RefractionIndex) : Material.RefractionIndex

// 	UnitDirection := Normalize(Ray.Direction)

// 	// For handling total internal reflection
// 	CosTheta := Min(Dot(-UnitDirection, Record.SurfaceNormal), 1)
// 	SinTheta := SquareRoot(1.0 - CosTheta * CosTheta)

// 	NewDirection : v3
// 	CannotRefract := Ri * SinTheta > 1.0

// 	if (CannotRefract || FresnelReflectance(CosTheta, Ri) > RandomUnilateral())
// 	{
// 		NewDirection = Reflect(UnitDirection, Record.SurfaceNormal)
// 	}
// 	else
// 	{
// 		NewDirection = Refract(UnitDirection, Record.SurfaceNormal, Ri)
// 	}

// 	SRecord.Attenuation = v3{1, 1, 1}
// 	SRecord.NewRay = ray{Record.HitPoint, NewDirection}
// 	SRecord.ScatterAgain = true

// 	return SRecord
// }

// primitive :: struct
// {
// 	Surface : union{ sphere, plane, quad, triangle },
// 	MaterialIndex : u32,
// }

