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

ScatterMetal :: proc(Metal : metal, Ray : ray, Record : hit_record) -> (ray, v3, bool)
{
	Reflected := Reflect(Ray.Direction, Record.SurfaceNormal)
	Reflected = Normalize(Reflected) + (Metal.Fuzz * RandomUnitVector())
	NewRay := ray{Record.HitPoint, Reflected}
	Attenuation := Metal.Color
	ScatterAgain := Dot(NewRay.Direction, Record.SurfaceNormal) > 0

	return NewRay, Attenuation, ScatterAgain
}

ScatterDielectric :: proc(Material : dielectric, Ray : ray, Record : hit_record) -> (ray, v3, bool)
{
	Attenuation := v3{1, 1, 1}
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

	NewRay := ray{Record.HitPoint, NewDirection}

	return NewRay, Attenuation, true
}

