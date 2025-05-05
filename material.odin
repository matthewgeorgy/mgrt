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
};

Scatter :: proc(SurfaceMaterial : material, Ray : ray, Record : hit_record) -> scatter_record
{
	SRecord : scatter_record

	switch Type in SurfaceMaterial
	{
		case lambertian:
		{
			SRecord.Attenuation = SurfaceMaterial.(lambertian).Color
			SRecord.NewRay.Origin = Record.HitPoint
			SRecord.NewRay.Direction = Record.SurfaceNormal + RandomUnitVector()//RandomOnHemisphere(Record.SurfaceNormal)
			SRecord.ScatterAgain = true
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
			SRecord.ScatterAgain = true
		}
	}

	return SRecord
}

ScatterMetal :: proc(Metal : metal, Ray : ray, Record : hit_record) -> scatter_record
{
	SRecord : scatter_record

	Reflected := Reflect(Ray.Direction, Record.SurfaceNormal)
	Reflected = Normalize(Reflected) + (Metal.Fuzz * RandomUnitVector())
	SRecord.NewRay = ray{Record.HitPoint, Reflected}
	SRecord.Attenuation = Metal.Color
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

