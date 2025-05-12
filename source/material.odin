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

bxdf_type :: enum
{
	DIFFUSE = 1,
	METAL = 2,
	DIELECTRIC = 3,
}

bxdf :: struct
{
	Type : bxdf_type,

	using _ : struct #raw_union { Lambertian : lambertian, Metal : metal, }
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
		case bxdf_type.METAL:
		{
			f = EvaluateMetalBRDF(BxDF.Metal, wo, wi)
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
		case bxdf_type.METAL:
		{
			Sample = SampleMetalBRDF(BxDF.Metal, wo, Normal)
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

SampleLambertianBRDF :: proc(BRDF : lambertian, wo, Normal : v3) -> bxdf_sample
{
	Sample : bxdf_sample

	Basis := CreateBasis(Normal)
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

SampleMetalBRDF :: proc(BRDF : metal, wo, Normal : v3) -> bxdf_sample
{
	Sample : bxdf_sample

	Reflected := Reflect(wo, Normal)
	Sample.wi = Normalize(Reflected) + (BRDF.Fuzz * RandomUnitVector())

	Sample.f = BRDF.Color / Abs(Dot(Sample.wi, Normal)) // Cancel out CosAtten term
	Sample.PDF = 1

	return Sample
}

AddMaterial :: proc{ AddLambertian, AddLight, AddMetal, }

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

