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
	// metal,
	light,
};

