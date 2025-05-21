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

		SampleResult := SampleBxDF(SurfaceMaterial, -Ray.Direction, Record)

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

	OnLight, _, LightAreaInv := SampleRandomLight(Scene)
	ToLight := Normalize(OnLight - Record.HitPoint)
	DistanceSquared := LengthSquared(OnLight - Record.HitPoint)

	LightArea := 1.0 / LightAreaInv
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

			f := EvaluateBxDF(OriginalMaterial, -Ray.Direction, ShadowRay.Direction, Record)
			CosAtten := Abs(Dot(ShadowRay.Direction, Record.SurfaceNormal))

			DirectIllumination = f * CosAtten * Le / LightPDF
		}
	}

	return DirectIllumination
}

ComputeIndirectIllumination :: proc(Scene : ^scene, RayDirection : v3, Record : ^hit_record) -> v3
{
	return ComputeIndirectIlluminationRecursive(Scene, RayDirection, Record, Scene.MaxDepth)
}

ComputeIndirectIlluminationRecursive :: proc(Scene : ^scene, RayDirection : v3, Record : ^hit_record, Depth : int) -> v3
{
	Indirect : v3

	if Depth <= 0
	{
		return v3{0, 0, 0}
	}

	SurfaceMaterial := Scene.Materials[Record.MaterialIndex]
	Sample := SampleBxDF(SurfaceMaterial, -RayDirection, Record^)

	f := Sample.f
	CosAtten := Abs(Dot(Record.SurfaceNormal, Sample.wi))

	FinalRecord : hit_record
	FinalRay := ray{Record.HitPoint, Sample.wi}

	if GetIntersection(FinalRay, Scene, &FinalRecord)
	{
		if !HasLight(FinalRecord)
		{
			HitMaterial := Scene.Materials[FinalRecord.MaterialIndex]
			MaterialType := GetMaterialType(HitMaterial)

			if MaterialType == .DIFFUSE
			{
				Query := photon_map_query{ HitMaterial, FinalRecord, -FinalRay.Direction, 10 }

				Indirect = f * CosAtten * RadianceEstimate(Scene.GlobalPhotonMap, Query) / Sample.PDF
			}
			else if MaterialType == .SPECULAR
			{
				Indirect = f * CosAtten * ComputeIndirectIlluminationRecursive(Scene, -FinalRay.Direction, &FinalRecord, Depth - 1) / Sample.PDF
			}
		}
	}

	return Indirect
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

		SurfaceMaterial := Scene.Materials[Record.MaterialIndex]
		MaterialType := GetMaterialType(SurfaceMaterial)

		if MaterialType == .DIFFUSE
		{
			DirectIllumination := ComputeDirectIllumination(Ray, Record, Scene)

			IndirectIllumination := ComputeIndirectIllumination(Scene, Ray.Direction, &Record)

			CausticsQuery := photon_map_query{ SurfaceMaterial, Record, -Ray.Direction, 10 }
			Caustics := RadianceEstimate(Scene.CausticPhotonMap, CausticsQuery)

			return DirectIllumination + IndirectIllumination + Caustics
		}
		else if MaterialType == .SPECULAR
		{
			Sample := SampleBxDF(SurfaceMaterial, -Ray.Direction, Record)

			f := Sample.f
			PDF := Sample.PDF
			wi := Sample.wi

			CosAtten := Abs(Dot(wi, Record.SurfaceNormal))
			NewRay := ray{Record.HitPoint, wi}

			return f * CosAtten * PhotonMapIntegrator(NewRay, Scene, Depth - 1) / PDF
		}
		else
		{
			return v3{0, 0, 0}
		}
	}
	else
	{
		return Scene.Materials[0].(lambertian).Rho
	}
}

