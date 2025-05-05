package main

NaiveIntegrator :: proc(Ray : ray, World : ^world, Depth : int) -> v3
{
	Record : hit_record

	if Depth <= 0
	{
		return v3{0, 0, 0}
	}

	HitSomething := GetIntersection(Ray, World, &Record)

	if !HitSomething
	{
		return World.Materials[0].(lambertian).Color
	}

	NewRay : ray
	ScatteredColor : v3
	EmittedColor : v3
	Attenuation : v3
	SurfaceMaterial := World.Materials[Record.MaterialIndex]

	ScatterRecord := Scatter(SurfaceMaterial, Ray, Record)

	if !ScatterRecord.ScatterAgain
	{
		return v3{0, 0, 0}
	}

	ScatteredColor = ScatterRecord.Attenuation * NaiveIntegrator(ScatterRecord.NewRay, World, Depth - 1)

	return ScatterRecord.EmittedColor + ScatteredColor
}

RTWIntegrator :: proc(Ray : ray, World : ^world, Depth : int) -> v3
{
	Record : hit_record

	if Depth <= 0
	{
		return v3{0, 0, 0}
	}

	HitSomething := GetIntersection(Ray, World, &Record)

	if !HitSomething
	{
		return World.Materials[0].(lambertian).Color
	}

	SurfaceMaterial := World.Materials[Record.MaterialIndex]

	ScatterRecord := Scatter(SurfaceMaterial, Ray, Record)

	if !ScatterRecord.ScatterAgain
	{
		return ScatterRecord.EmittedColor
	}

	PDF := ScatteringPDF(SurfaceMaterial, Ray, ScatterRecord.NewRay, Record)
	PDFValue := PDF

	ScatteredColor := (PDF / PDFValue) * ScatterRecord.Attenuation * RTWIntegrator(ScatterRecord.NewRay, World, Depth - 1)

	return ScatterRecord.EmittedColor + ScatteredColor
}

