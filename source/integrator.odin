package main

// NOTE(matthew): for reference
PathTracingIntegrator :: proc(Ray : ray, Scene : ^scene, Depth : int) -> v3
{
	Record : hit_record

	if Depth <= 0
	{
		return v3{0, 0, 0}
	}

	if GetIntersection(Ray, Scene, &Record)
	{
		SurfaceMaterial := Scene.Materials[Record.MaterialIndex]

		if SurfaceMaterial.Type == .LIGHT
		{
			return SurfaceMaterial.Light.Le
		}

		SampleResult := SampleBxDF(SurfaceMaterial.BxDF, Ray.Direction, Record)

		f := SampleResult.f
		Dir := SampleResult.wi
		PDF := SampleResult.PDF

		CosAtten := Abs(Dot(Dir, Record.SurfaceNormal))

		ScatteredRay := ray{Record.HitPoint, Dir}

		return CosAtten * f * PathTracingIntegrator(ScatteredRay, Scene, Depth - 1) / PDF
	}
	else
	{
		return Scene.Materials[0].BxDF.Lambertian.Rho
	}
}

// // NOTE(matthew): need to rename this!
// // This isn't actually a direct light integrator; it is still a recurisve integrator,
// // except it only samples the light source. So kinda direct and also indirect, but
// // indirect from previously scattered light paths.
// DirectLightIntegrator :: proc(Ray : ray, Scene : ^scene, Depth : int) -> v3
// {
// 	Record : hit_record

// 	if Depth <= 0
// 	{
// 		return v3{0, 0, 0}
// 	}

// 	if GetIntersection(Ray, Scene, &Record)
// 	{
// 		SurfaceMaterial := Scene.Materials[Record.MaterialIndex]

// 		ScatterRecord := Scatter(SurfaceMaterial, Ray, Record)

// 		if !ScatterRecord.ScatterAgain
// 		{
// 			return ScatterRecord.EmittedColor
// 		}

// 		// Hard-coded direct light sampling
// 		OnLight := v3{RandomFloat(213, 343), 554, RandomFloat(227, 332)}
// 		ToLight := OnLight - Record.HitPoint
// 		DistanceSquared := LengthSquared(ToLight)
// 		ToLight = Normalize(ToLight)

// 		if Dot(ToLight, Record.SurfaceNormal) < 0
// 		{
// 			return ScatterRecord.EmittedColor
// 		}

// 		LightArea : f32 = (343 - 213) * (332 - 227)
// 		LightCosine := Abs(ToLight.y)
// 		if LightCosine < 0.0000001
// 		{
// 			return ScatterRecord.EmittedColor
// 		}

// 		PDF := DistanceSquared / (LightCosine * LightArea)
// 		ScatteredRay := ray{Record.HitPoint, ToLight}
// 		CosAtten := Max(Dot(Record.SurfaceNormal, Normalize(ScatteredRay.Direction)), 0)

// 		ScatteredColor := CosAtten * ScatterRecord.Attenuation * DirectLightIntegrator(ScatteredRay, Scene, Depth - 1) / PDF

// 		return ScatterRecord.EmittedColor + ScatteredColor
// 	}
// 	else
// 	{
// 		return Scene.Materials[0].(lambertian).Color
// 	}
// }


// PhotonMapVisualizer :: proc(Ray : ray, Scene : ^scene, Depth : int) -> v3
// {
// 	Record : hit_record

// 	if Depth <= 0
// 	{
// 		return v3{0, 0, 0}
// 	}

// 	if GetIntersection(Ray, Scene, &Record)
// 	{
// 		SurfaceMaterial := Scene.Materials[Record.MaterialIndex]

// 		ScatterRecord := Scatter(SurfaceMaterial, Ray, Record)

// 		if !ScatterRecord.ScatterAgain
// 		{
// 			// return ScatterRecord.EmittedColor
// 			return v3{0, 0, 0}
// 		}

// 		PHOTON_SEARCH_RADIUS : f32 = 5
// 		Irradiance := IrradianceEstimate(Scene.PhotonMap, Record.HitPoint, Record.SurfaceNormal, PHOTON_SEARCH_RADIUS)
// 		SurfaceColor := ScatterRecord.Attenuation

// 		return Irradiance * SurfaceColor
// 	}
// 	else
// 	{
// 		return Scene.Materials[0].(lambertian).Color
// 	}
// }

// ComputeDirectIllumination :: proc(Ray : ray, Record : hit_record, Scene : ^scene) -> v3
// {
// 	DirectIllumination : v3

// 	OnLight := v3{RandomFloat(213, 343), 554, RandomFloat(227, 332)}
// 	ToLight := Normalize(OnLight - Record.HitPoint)
// 	DistanceSquared := LengthSquared(OnLight - Record.HitPoint)

// 	LightArea : f32 = (343 - 213) * (332 - 227)
// 	LightCosine := Abs(ToLight.y)
// 	LightPDF := DistanceSquared / (LightCosine * LightArea)

// 	ShadowRay := ray{Record.HitPoint, ToLight}

// 	ShadowRecord : hit_record

// 	if GetIntersection(ShadowRay, Scene, &ShadowRecord)
// 	{
// 		SurfaceMaterial := Scene.Materials[ShadowRecord.MaterialIndex]
// 		LightScatterRecord := Scatter(SurfaceMaterial, Ray, ShadowRecord)

// 		// We hit the light source without anything obstructing us
// 		if !LightScatterRecord.ScatterAgain
// 		{
// 			SurfaceMaterial = Scene.Materials[Record.MaterialIndex]
// 			SurfaceScatterRecord := Scatter(SurfaceMaterial, Ray, Record)

// 			if SurfaceScatterRecord.ScatterAgain
// 			{
// 				Le := LightScatterRecord.EmittedColor
// 				BRDF := SurfaceScatterRecord.Attenuation
// 				CosAtten := Max(Dot(Record.SurfaceNormal, ShadowRay.Direction), 0)

// 				DirectIllumination = BRDF * CosAtten * Le / LightPDF
// 			}
// 		}
// 	}

// 	return DirectIllumination
// }

// ComputeIndirectIllumination :: proc(Scene : ^scene, RayDirection : v3, Record : ^hit_record) -> v3
// {
// 	Indirect : v3
// 	Map := Scene.PhotonMap

// 	CosinePDF := cosine_pdf{CreateBasis(Record.SurfaceNormal)}
// 	Dir := GeneratePDFDirection(CosinePDF)
// 	PDF := GeneratePDFValue(CosinePDF, Dir)
// 	CosAtten := Abs(Dot(Record.SurfaceNormal, Dir))

// 	// Single gathering ray (since we only have diffuse materials right now)
// 	FinalRecord : hit_record
// 	FinalRay := ray{Record.HitPoint, Dir}
// 	if GetIntersection(FinalRay, Scene, &FinalRecord)
// 	{
// 		SurfaceMaterial := Scene.Materials[FinalRecord.MaterialIndex]
// 		ScatterRecord := Scatter(SurfaceMaterial, FinalRay, FinalRecord)

// 		if ScatterRecord.ScatterAgain
// 		{
// 			PhotonSearchRadius : f32 = 2.5

// 			BRDF := ScatterRecord.Attenuation
// 			Irradiance := IrradianceEstimate(Map, FinalRecord.HitPoint, FinalRecord.SurfaceNormal, PhotonSearchRadius)

// 			Indirect = BRDF * CosAtten * Irradiance / PDF
// 		}
// 	}

// 	return Indirect
// }

// PhotonMapIntegrator :: proc(Ray : ray, Scene : ^scene, Depth : int) -> v3
// {
// 	Record : hit_record

// 	if Depth <= 0
// 	{
// 		return v3{0, 0, 0}
// 	}

// 	if GetIntersection(Ray, Scene, &Record)
// 	{
// 		SurfaceMaterial := Scene.Materials[Record.MaterialIndex]
// 		ScatterRecord := Scatter(SurfaceMaterial, Ray, Record)

// 		// Hit the light
// 		if !ScatterRecord.ScatterAgain
// 		{
// 			return ScatterRecord.EmittedColor
// 		}

// 		CosinePDF := cosine_pdf{CreateBasis(Record.SurfaceNormal)}
// 		ScatteredRay := ray{Record.HitPoint, GeneratePDFDirection(CosinePDF)}
// 		PDF := GeneratePDFValue(CosinePDF, ScatteredRay.Direction)
// 		CosAtten := Abs(Dot(Normalize(Record.SurfaceNormal), Normalize(ScatteredRay.Direction)))
// 		BRDF := ScatterRecord.Attenuation

// 		DirectIllumination := ComputeDirectIllumination(Ray, Record, Scene)
// 		IndirectIllumination := BRDF * CosAtten * ComputeIndirectIllumination(Scene, Ray.Direction, &Record) / PDF

// 		return DirectIllumination + IndirectIllumination
// 	}
// 	else
// 	{
// 		return Scene.Materials[0].(lambertian).Color
// 	}
// }

