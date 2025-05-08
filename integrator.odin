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

DirectLightIntegrator :: proc(Ray : ray, World : ^world, Depth : int) -> v3
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

	// Hard-coded direct light sampling
	OnLight := v3{RandomFloat(213, 343), 554, RandomFloat(227, 332)}
	ToLight := OnLight - Record.HitPoint
	DistanceSquared := LengthSquared(ToLight)
	ToLight = Normalize(ToLight)

	if Dot(ToLight, Record.SurfaceNormal) < 0
	{
		return ScatterRecord.EmittedColor
	}

	LightArea : f32 = (343 - 213) * (332 - 227)
	LightCosine := Abs(ToLight.y)
	if LightCosine < 0.0000001
	{
		return ScatterRecord.EmittedColor
	}

	PDFValue := DistanceSquared / (LightCosine * LightArea)
	ScatteredRay := ray{Record.HitPoint, ToLight}
	ScatteringPDF := ScatteringPDF(SurfaceMaterial, Ray, ScatteredRay, Record)

	ScatteredColor := (ScatteringPDF / PDFValue) * ScatterRecord.Attenuation * DirectLightIntegrator(ScatteredRay, World, Depth - 1)

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

	CosinePDF := cosine_pdf{CreateBasis(Record.SurfaceNormal)}
	ScatteredRay := ray{Record.HitPoint, GeneratePDFDirection(CosinePDF)}
	PDF := GeneratePDFValue(CosinePDF, ScatteredRay.Direction)
	CosAtten := Max(Dot(Normalize(Record.SurfaceNormal), Normalize(ScatteredRay.Direction)), 0)

	ScatteredColor := ScatterRecord.Attenuation * CosAtten * RTWIntegrator(ScatteredRay, World, Depth - 1) / PDF

	return ScatterRecord.EmittedColor + ScatteredColor
}

PhotonMapIntegrator :: proc(Ray : ray, World : ^world, Depth : int) -> v3
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
		// return ScatterRecord.EmittedColor
		return v3{0, 0, 0}
	}

	Irradiance : v3
	Indirect : v3
	PHOTON_SEARCH_RADIUS : f32 = 2.5
	AreaFactor := 1 / (PI * PHOTON_SEARCH_RADIUS * PHOTON_SEARCH_RADIUS)

	NearestPhotons := LocatePhotons(World.PhotonMap, Record.HitPoint, PHOTON_SEARCH_RADIUS)

	for Photon in NearestPhotons.PhotonsFound
	{
		Weight := Max(Dot(-Photon.Dir, Record.SurfaceNormal), 0)
		Indirect += Photon.Power * Weight
	}

	Irradiance = AreaFactor * ScatterRecord.Attenuation * Indirect

	return Irradiance
}

