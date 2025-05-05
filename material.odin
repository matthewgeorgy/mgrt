package main

lambertian :: struct
{
	Color : v3,
};

metal :: struct
{
	Color : v3,
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

ScatterMetal :: proc(Metal : metal, Ray : ray, Record : hit_record) -> (ray, v3)
{
	Reflected := Reflect(Ray.Direction, Record.SurfaceNormal)
	NewRay := ray{Record.HitPoint, Reflected}
	Attenuation := Metal.Color

	return NewRay, Attenuation
}

