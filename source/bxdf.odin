package main

/* NOTE(matthew):
When evaluating BxDFs, we use the same geometric setting as PBRT:
	- s: tangent vector in x-axis
	- t: bitangent vector in y-axis
	- n: normal vector in z-axis
The input vectors wo and wi are always transformed with respect to this
coordinate system and assumed normalized before any BxDFs are actually evaluated.

We also use the standard convention that both wo and wi are OUTWARD pointing.
In particular, this means that code calling into BxDF functions need to negate
wo as the ray direction:
		SampleBxDF(Material, -Ray.Direction, Record)
		EvaluateBxDF(Material, -Outgoing, Incoming)
rather than
		SampleBxDF(Material, Ray.Direction, Record)
		EvaluateBxDF(Material, Outgoing, Incoming)

The real, internal EvaluateBxDF functions (eg, EvaluateLambertianBRDF) assume
this convention is being adhered to. Therefore, the generic SampleBxDF and
EvaluateBxDF functions will do the coordinate-system conversion internally before
calling into any of the real BxDF functions.

Furthermore, the sampled direction wi in the bxdf_sample will always be returned
in global coordinates, so no additional remapping from the caller is necessary.
*/

BXDF_TANGENT 	:: v3{1, 0, 0} // s
BXDF_BITANGENT	:: v3{0, 1, 0} // t
BXDF_NORMAL 	:: v3{0, 0, 1} // n

bxdf_sample :: struct
{
	wi : v3,
	PDF : f32,
	f : v3,
}

EvaluateBxDF :: proc(Material : material, Outgoing, Incoming : v3, Record : hit_record) -> v3
{
	f : v3

	Basis := CreateBasis(Record.SurfaceNormal)
	wo := GlobalToLocalNormalized(Basis, Outgoing)
	wi := GlobalToLocalNormalized(Basis, Incoming)

	switch Type in Material
	{
		case lambertian:
		{
			f = EvaluateLambertianBRDF(Material.(lambertian), wo, wi)
		}
		case metal:
		{
			f = EvaluateMetalBRDF(Material.(metal), wo, wi)
		}
		case dielectric:
		{
			f = EvaluateDielectricBRDF(Material.(dielectric), wo, wi)
		}
		case merl:
		{
			f = EvaluateMERLBRDF(Material.(merl), wo, wi)
		}
	}

	return f
}

SampleBxDF :: proc(Material : material, Outgoing : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Basis := CreateBasis(Record.SurfaceNormal)
	wo := GlobalToLocalNormalized(Basis, Outgoing)

	switch Type in Material
	{
		case lambertian:
		{
			Sample = SampleLambertianBRDF(Material.(lambertian), wo, Record)
		}
		case metal:
		{
			Sample = SampleMetalBRDF(Material.(metal), wo, Record)
		}
		case dielectric:
		{
			Sample = SampleDielectricBRDF(Material.(dielectric), wo, Record)
		}
		case merl:
		{
			Sample = SampleMERLBRDF(Material.(merl), wo, Record)
		}
	}

	return Sample
}

EvaluateLambertianBRDF :: proc(Material : lambertian, wo, wi : v3) -> v3
{
	CosThetaO := wo.z
	CosThetaI := wi.z

	if (CosThetaO < 0) || (CosThetaI < 0)
	{
		return v3{0, 0, 0}
	}

	return Material.Rho / PI
}

SampleLambertianBRDF :: proc(Material : lambertian, wo : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Basis := CreateBasis(Record.SurfaceNormal)

	wi := RandomCosineDirection()
	CosineTheta := wi.z

	Sample.wi = LocalToGlobal(Basis, wi)
	Sample.PDF = CosineTheta / PI
	Sample.f = EvaluateLambertianBRDF(Material, wo, wi)

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

	Basis := CreateBasis(Record.SurfaceNormal)

	Reflected := Reflect(-wo, BXDF_NORMAL)
	Reflected = Normalize(Reflected) + (Material.Fuzz * RandomUnitVector())

	Sample.wi = LocalToGlobal(Basis, Reflected)
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

	Basis := CreateBasis(Record.SurfaceNormal)

	Attenuation := v3{1, 1, 1}
	Ri := Record.IsFrontFace ? (1.0 / Material.RefractionIndex) : Material.RefractionIndex

	// UnitDirection := Normalize(wo)
	UnitDirection := -wo

	// For handling total internal reflection
	CosTheta := Min(Dot(wo, BXDF_NORMAL), 1)
	SinTheta := SquareRoot(1.0 - CosTheta * CosTheta)

	NewDirection : v3
	CannotRefract := Ri * SinTheta > 1.0

	if (CannotRefract || FresnelReflectance(CosTheta, Ri) > RandomUnilateral())
	{
		NewDirection = Reflect(UnitDirection, BXDF_NORMAL)
	}
	else
	{
		NewDirection = Refract(UnitDirection, BXDF_NORMAL, Ri)
	}

	Sample.f = Attenuation / Abs(NewDirection.z) // Divide by CosAtten
	Sample.PDF = 1
	Sample.wi = LocalToGlobal(Basis, NewDirection)

	return Sample
}

EvaluateMERLBRDF :: proc(Material : merl, wo, wi : v3) -> v3
{
	return BRDFLookup(Material.Table, wo, wi)
}

SampleMERLBRDF :: proc(Material : merl, wo : v3, Record : hit_record) -> bxdf_sample
{
	Sample : bxdf_sample

	Basis := CreateBasis(Record.SurfaceNormal)

	wi := RandomOnHemisphere(BXDF_NORMAL)

	CosAtten := Abs(wi.z)

	Sample.PDF = 1 / (2 * PI * CosAtten)
	Sample.wi = LocalToGlobal(Basis, wi)
	Sample.f = EvaluateMERLBRDF(Material, wo, wi)

	return Sample
}

