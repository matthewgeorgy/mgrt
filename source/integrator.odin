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
		if HasLight(Record)
		{
			Light := Scene.Lights[Record.LightIndex]
			return Light.Le
		}

		SurfaceMaterial := Scene.Materials[Record.MaterialIndex]

		SampleResult := SampleBxDF(SurfaceMaterial, Ray.Direction, Record)

		f := SampleResult.f
		Dir := SampleResult.wi
		PDF := SampleResult.PDF

		CosAtten := Abs(Dot(Dir, Record.SurfaceNormal))

		ScatteredRay := ray{Record.HitPoint, Dir}

		return CosAtten * f * PathTracingIntegrator(ScatteredRay, Scene, Depth - 1) / PDF
	}
	else
	{
		return Scene.Materials[0].(lambertian).Rho
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

ComputeDirectIllumination :: proc(Ray : ray, Record : hit_record, Scene : ^scene) -> v3
{
	DirectIllumination : v3

	OnLight := v3{RandomFloat(213, 343), 554, RandomFloat(227, 332)}
	ToLight := Normalize(OnLight - Record.HitPoint)
	DistanceSquared := LengthSquared(OnLight - Record.HitPoint)

	LightArea : f32 = (343 - 213) * (332 - 227)
	LightCosine := Abs(ToLight.y)
	LightPDF := DistanceSquared / (LightCosine * LightArea)

	OriginalMaterial := Scene.Materials[Record.MaterialIndex]

	ShadowRay := ray{Record.HitPoint, ToLight}

	ShadowRecord : hit_record

	if GetIntersection(ShadowRay, Scene, &ShadowRecord)
	{

		// We hit the light source without anything obstructing us
		if HasLight(ShadowRecord)
		{
			HitLight := Scene.Lights[ShadowRecord.LightIndex]

			Le := HitLight.Le

			f := EvaluateBxDF(OriginalMaterial, Ray.Direction, ShadowRay.Direction)
			CosAtten := Abs(Dot(ShadowRay.Direction, Record.SurfaceNormal))

			DirectIllumination = f * CosAtten * Le / LightPDF
		}
	}

	return DirectIllumination
}

ComputeIndirectIllumination :: proc(Scene : ^scene, RayDirection : v3, Record : ^hit_record) -> v3
{
	Indirect : v3
	Map := Scene.PhotonMap

	SurfaceMaterial := Scene.Materials[Record.MaterialIndex]
	Sample := SampleBxDF(SurfaceMaterial, RayDirection, Record^)

	f := Sample.f
	CosAtten := Abs(Dot(Record.SurfaceNormal, Sample.wi))

	FinalRecord : hit_record
	FinalRay := ray{Record.HitPoint, Sample.wi}

	if GetIntersection(FinalRay, Scene, &FinalRecord)
	{
		if !HasLight(FinalRecord)
		{
			HitMaterial := Scene.Materials[FinalRecord.MaterialIndex]

			if _, ok := HitMaterial.(lambertian); ok
			{
				Indirect = f * CosAtten * ComputeRadianceWithPhotonMap(Scene, FinalRay.Direction, FinalRecord) / Sample.PDF
			}
		}
	}

	return Indirect
}

ComputeRadianceWithPhotonMap :: proc(Scene : ^scene, wo : v3, Record : hit_record) -> v3
{
	Radiance : v3
	Map := Scene.PhotonMap
	MaxPhotonDistance : f32 = 2.5

	NearestPhotons := LocatePhotons(Map, Record.HitPoint, MaxPhotonDistance)
	defer delete(NearestPhotons.PhotonsFound)

	if len(NearestPhotons.PhotonsFound) == 0
	{
		return v3{0, 0, 0}
	}

	SurfaceMaterial := Scene.Materials[Record.MaterialIndex]
	f := EvaluateBxDF(SurfaceMaterial, wo, wo)

	for Photon in NearestPhotons.PhotonsFound
	{
		if Dot(Photon.Dir, Record.SurfaceNormal) < 0
		{
			Radiance += f * Photon.Power
		}
	}

	AreaFactor := 1 / (PI * MaxPhotonDistance * MaxPhotonDistance)

	Radiance *= AreaFactor

	return Radiance
}

PhotonMapIntegrator :: proc(Ray : ray, Scene : ^scene, Depth : int) -> v3
{
	Record : hit_record

	if Depth <= 0
	{
		return v3{0, 0, 0}
	}

	if GetIntersection(Ray, Scene, &Record)
	{
		// Hit the light
		if HasLight(Record)
		{
			SurfaceLight := Scene.Lights[Record.LightIndex]

			return SurfaceLight.Le
		}

		DirectIllumination := ComputeDirectIllumination(Ray, Record, Scene)
		IndirectIllumination := ComputeIndirectIllumination(Scene, Ray.Direction, &Record)

		return DirectIllumination + IndirectIllumination
	}
	else
	{
		return Scene.Materials[0].(lambertian).Rho
	}
}

