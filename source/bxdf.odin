package main

bxdf_sample :: struct
{
	wi : v3,
	PDF : f32,
	f : v3,
}

EvaluateBxDF :: proc(Material : material, wo, wi : v3) -> v3
{
	f : v3

	Type := Material.Type

	switch Type
	{
		case material_type.DIFFUSE:
		{
			f = EvaluateLambertianBRDF(Material.Lambertian, wo, wi)
		}
		case material_type.METAL:
		{
			f = EvaluateMetalBRDF(Material.Metal, wo, wi)
		}
		case material_type.DIELECTRIC:
		{
			f = EvaluateDielectricBRDF(Material.Dielectric, wo, wi)
		}
	}

	return f
}

SampleBxDF :: proc(Material : material, wo : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Type := Material.Type

	switch Type
	{
		case material_type.DIFFUSE:
		{
			Sample = SampleLambertianBRDF(Material.Lambertian, wo, Record)
		}
		case material_type.METAL:
		{
			Sample = SampleMetalBRDF(Material.Metal, wo, Record)
		}
		case material_type.DIELECTRIC:
		{
			Sample = SampleDielectricBRDF(Material.Dielectric, wo, Record)
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
EvaluateLambertianBRDF :: proc(Material : lambertian, wo, wi : v3) -> v3
{
	return Material.Rho / PI
}

SampleLambertianBRDF :: proc(Material : lambertian, wo : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Basis := CreateBasis(Record.SurfaceNormal)
	Sample.wi = BasisTransform(Basis, RandomCosineDirection())

	CosineTheta := Dot(Normalize(Sample.wi), Basis.w)
	Sample.PDF = CosineTheta / PI

	Sample.f = EvaluateLambertianBRDF(Material, wo, Sample.wi)

	return Sample
}

EvaluateMetalBRDF :: proc(Material : metal, wo, wi : v3) -> v3
{
	// NOTE(matthew): delta function
	return v3{0, 0, 0}
}

SampleMetalBRDF :: proc(Material : metal, wo : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Reflected := Reflect(wo, Record.SurfaceNormal)
	Sample.wi = Normalize(Reflected) + (Material.Fuzz * RandomUnitVector())

	Sample.f = Material.Color / Abs(Dot(Sample.wi, Record.SurfaceNormal)) // Cancel out CosAtten term
	Sample.PDF = 1

	return Sample
}

EvaluateDielectricBRDF :: proc(Material : dielectric, wo, wi : v3) -> v3
{
	// NOTE(matthew): delta function
	return v3{0, 0, 0}
}

SampleDielectricBRDF :: proc(Material : dielectric, wo : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Attenuation := v3{1, 1, 1}
	Ri := Record.IsFrontFace ? (1.0 / Material.RefractionIndex) : Material.RefractionIndex

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

