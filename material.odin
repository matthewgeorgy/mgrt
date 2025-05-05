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

material :: union
{
	lambertian,
	metal,
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

