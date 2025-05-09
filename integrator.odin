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

// NOTE(matthew): need to rename this!
// This isn't actually a direct light integrator; it is still a recurisve integrator,
// except it only samples the light source. So kinda direct and also indirect, but
// indirect from previously scattered light paths.
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

	PDF := DistanceSquared / (LightCosine * LightArea)
	ScatteredRay := ray{Record.HitPoint, ToLight}
	CosAtten := Max(Dot(Record.SurfaceNormal, Normalize(ScatteredRay.Direction)), 0)

	ScatteredColor := CosAtten * ScatterRecord.Attenuation * DirectLightIntegrator(ScatteredRay, World, Depth - 1) / PDF

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

	PHOTON_SEARCH_RADIUS : f32 = 5
	Irradiance := IrradianceEstimate(World.PhotonMap, Record.HitPoint, Record.SurfaceNormal, PHOTON_SEARCH_RADIUS)
	SurfaceColor := ScatterRecord.Attenuation

	return Irradiance * SurfaceColor
}

ComputeDirectIllumination :: proc(Ray : ray, Record : hit_record, World : ^world) -> v3
{
	DirectIllumination : v3

	OnLight := v3{RandomFloat(213, 343), 554, RandomFloat(227, 332)}
	ToLight := OnLight - Record.HitPoint
	DistanceSquared := LengthSquared(ToLight)
	ToLight = Normalize(ToLight)

	LightArea : f32 = (343 - 213) * (332 - 227)
	LightCosine := Abs(ToLight.y)
	LightPDF := DistanceSquared / (LightCosine * LightArea)

	ShadowRay := ray{Record.HitPoint, ToLight}

	ShadowRecord : hit_record

	if GetIntersection(ShadowRay, World, &ShadowRecord)
	{
		SurfaceMaterial := World.Materials[ShadowRecord.MaterialIndex]
		LightScatterRecord := Scatter(SurfaceMaterial, Ray, Record)

		// We hit the light source without anything obstructing us
		if !LightScatterRecord.ScatterAgain
		{
			SurfaceMaterial = World.Materials[Record.MaterialIndex]
			SurfaceScatterRecord := ScatterLambertian(SurfaceMaterial.(lambertian), Ray, Record)

			Le := LightScatterRecord.EmittedColor
			BRDF := SurfaceScatterRecord.Attenuation
			CosAtten := Max(Dot(Record.SurfaceNormal, ShadowRay.Direction), 0)

			DirectIllumination = BRDF * CosAtten * Le / LightPDF
		}
	}

	return DirectIllumination
}

