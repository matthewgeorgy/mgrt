package main

lambertian :: struct
{
	Color : v3,
};

metal :: struct
{
	Color : v3,
	Fuzz : f32,
};

light :: struct
{
	Color : v3,
};

dielectric :: struct
{
	RefractionIndex : f32,
};

material :: union
{
	lambertian,
	metal,
	dielectric,
	light,
};

scatter_record :: struct
{
	NewRay : ray,
	EmittedColor : v3,
	Attenuation : v3,
	ScatterAgain : bool,
	PDFValue : f32,
};

Scatter :: proc(SurfaceMaterial : material, Ray : ray, Record : hit_record) -> scatter_record
{
	SRecord : scatter_record

	switch Type in SurfaceMaterial
	{
		case lambertian:
		{
			SRecord = ScatterLambertian(SurfaceMaterial.(lambertian), Ray, Record)
		}
		case metal:
		{
			SRecord = ScatterMetal(SurfaceMaterial.(metal), Ray, Record)
		}
		case dielectric:
		{
			SRecord = ScatterDielectric(SurfaceMaterial.(dielectric), Ray, Record)
		}
		case light:
		{
			SRecord.EmittedColor = SurfaceMaterial.(light).Color
			SRecord.NewRay.Origin = Record.HitPoint
			SRecord.NewRay.Direction = Record.SurfaceNormal + RandomUnitVector()//RandomOnHemisphere(Record.SurfaceNormal)
			SRecord.ScatterAgain = false // no scattering, just emit color
		}
	}

	return SRecord
}

ScatterLambertian :: proc(Material : lambertian, Ray : ray, Record : hit_record) -> scatter_record
{
	SRecord : scatter_record

	Basis := CreateBasis(Record.SurfaceNormal)
	ScatterDirection := BasisTransform(Basis, RandomCosineDirection())

	SRecord.Attenuation = Material.Color
	SRecord.NewRay = ray{Record.HitPoint, ScatterDirection}
	SRecord.ScatterAgain = true

	return SRecord
}

ScatterMetal :: proc(Material : metal, Ray : ray, Record : hit_record) -> scatter_record
{
	SRecord : scatter_record

	Reflected := Reflect(Ray.Direction, Record.SurfaceNormal)
	Reflected = Normalize(Reflected) + (Material.Fuzz * RandomUnitVector())
	SRecord.NewRay = ray{Record.HitPoint, Reflected}
	SRecord.Attenuation = Material.Color
	SRecord.ScatterAgain = Dot(SRecord.NewRay.Direction, Record.SurfaceNormal) > 0

	return SRecord
}

ScatterDielectric :: proc(Material : dielectric, Ray : ray, Record : hit_record) -> scatter_record
{
	SRecord : scatter_record

	Ri := Record.IsFrontFace ? (1.0 / Material.RefractionIndex) : Material.RefractionIndex

	UnitDirection := Normalize(Ray.Direction)

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

	SRecord.Attenuation = v3{1, 1, 1}
	SRecord.NewRay = ray{Record.HitPoint, NewDirection}
	SRecord.ScatterAgain = true

	return SRecord
}

ScatteringPDF :: proc(SurfaceMaterial : material, InputRay, ScatteredRay : ray, Record : hit_record) -> f32
{
	PDF : f32

	switch Type in SurfaceMaterial
	{
		case lambertian:
		{
			PDF = LambertianPDF(SurfaceMaterial.(lambertian), InputRay, ScatteredRay, Record)
		}
		case light:
		case dielectric:
		case metal:
		{
			PDF = 0
		}
	}

	return PDF
}

LambertianPDF :: proc(Material : lambertian, InputRay, ScatteredRay : ray, Record : hit_record) -> f32
{
	Basis := CreateBasis(Record.SurfaceNormal)

	return Dot(Basis.w, ScatteredRay.Direction) / PI
}

