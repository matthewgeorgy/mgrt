package main

import fmt "core:fmt"

// NaiveIntegrator :: proc(Ray : ray, World : ^world, Depth : int) -> v3
// {
// 	Record : hit_record

// 	if Depth <= 0
// 	{
// 		return v3{0, 0, 0}
// 	}

// 	if GetIntersection(Ray, World, &Record)
// 	{
// 		NewRay : ray
// 		ScatteredColor : v3
// 		EmittedColor : v3
// 		Attenuation : v3
// 		SurfaceMaterial := World.Materials[Record.MaterialIndex]

// 		ScatterRecord := Scatter(SurfaceMaterial, Ray, Record)

// 		if !ScatterRecord.ScatterAgain
// 		{
// 			return v3{0, 0, 0}
// 		}

// 		ScatteredColor = ScatterRecord.Attenuation * NaiveIntegrator(ScatterRecord.NewRay, World, Depth - 1)

// 		return ScatterRecord.EmittedColor + ScatteredColor
// 	}
// 	else
// 	{
// 		return World.Materials[0].(lambertian).Color
// 	}
// }

// // NOTE(matthew): need to rename this!
// // This isn't actually a direct light integrator; it is still a recurisve integrator,
// // except it only samples the light source. So kinda direct and also indirect, but
// // indirect from previously scattered light paths.
// DirectLightIntegrator :: proc(Ray : ray, World : ^world, Depth : int) -> v3
// {
// 	Record : hit_record

// 	if Depth <= 0
// 	{
// 		return v3{0, 0, 0}
// 	}

// 	if GetIntersection(Ray, World, &Record)
// 	{
// 		SurfaceMaterial := World.Materials[Record.MaterialIndex]

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

// 		ScatteredColor := CosAtten * ScatterRecord.Attenuation * DirectLightIntegrator(ScatteredRay, World, Depth - 1) / PDF

// 		return ScatterRecord.EmittedColor + ScatteredColor
// 	}
// 	else
// 	{
// 		return World.Materials[0].(lambertian).Color
// 	}
// }

RTWIntegrator :: proc(Ray : ray, World : ^world, Depth : int) -> v3
{
	Record : hit_record

	if Depth <= 0
	{
		return v3{0, 0, 0}
	}

	if GetIntersection(Ray, World, &Record)
	{
		SurfaceMaterial := World.Materials[Record.MaterialIndex]

		if SurfaceMaterial.Type == .LIGHT
		{
			return SurfaceMaterial.Light.Le
		}

		SampleResult := SampleBxDF(SurfaceMaterial.BxDF, Ray.Direction, Record.SurfaceNormal)

		f := SampleResult.f
		Dir := SampleResult.wi
		PDF := SampleResult.PDF

		CosAtten := Max(Dot(Dir, Record.SurfaceNormal), 0)

		ScatteredRay := ray{Record.HitPoint, Dir}

		return CosAtten * f * RTWIntegrator(ScatteredRay, World, Depth - 1) / PDF
	}
	else
	{
		return World.Materials[0].BxDF.Lambertian.Rho
	}
}

// PhotonMapVisualizer :: proc(Ray : ray, World : ^world, Depth : int) -> v3
// {
// 	Record : hit_record

// 	if Depth <= 0
// 	{
// 		return v3{0, 0, 0}
// 	}

// 	if GetIntersection(Ray, World, &Record)
// 	{
// 		SurfaceMaterial := World.Materials[Record.MaterialIndex]

// 		ScatterRecord := Scatter(SurfaceMaterial, Ray, Record)

// 		if !ScatterRecord.ScatterAgain
// 		{
// 			// return ScatterRecord.EmittedColor
// 			return v3{0, 0, 0}
// 		}

// 		PHOTON_SEARCH_RADIUS : f32 = 5
// 		Irradiance := IrradianceEstimate(World.PhotonMap, Record.HitPoint, Record.SurfaceNormal, PHOTON_SEARCH_RADIUS)
// 		SurfaceColor := ScatterRecord.Attenuation

// 		return Irradiance * SurfaceColor
// 	}
// 	else
// 	{
// 		return World.Materials[0].(lambertian).Color
// 	}
// }

// ComputeDirectIllumination :: proc(Ray : ray, Record : hit_record, World : ^world) -> v3
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

// 	if GetIntersection(ShadowRay, World, &ShadowRecord)
// 	{
// 		SurfaceMaterial := World.Materials[ShadowRecord.MaterialIndex]
// 		LightScatterRecord := Scatter(SurfaceMaterial, Ray, ShadowRecord)

// 		// We hit the light source without anything obstructing us
// 		if !LightScatterRecord.ScatterAgain
// 		{
// 			SurfaceMaterial = World.Materials[Record.MaterialIndex]
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

// ComputeIndirectIllumination :: proc(World : ^world, RayDirection : v3, Record : ^hit_record) -> v3
// {
// 	Indirect : v3
// 	Map := World.PhotonMap

// 	CosinePDF := cosine_pdf{CreateBasis(Record.SurfaceNormal)}
// 	Dir := GeneratePDFDirection(CosinePDF)
// 	PDF := GeneratePDFValue(CosinePDF, Dir)
// 	CosAtten := Abs(Dot(Record.SurfaceNormal, Dir))

// 	// Single gathering ray (since we only have diffuse materials right now)
// 	FinalRecord : hit_record
// 	FinalRay := ray{Record.HitPoint, Dir}
// 	if GetIntersection(FinalRay, World, &FinalRecord)
// 	{
// 		SurfaceMaterial := World.Materials[FinalRecord.MaterialIndex]
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

// PhotonMapIntegrator :: proc(Ray : ray, World : ^world, Depth : int) -> v3
// {
// 	Record : hit_record

// 	if Depth <= 0
// 	{
// 		return v3{0, 0, 0}
// 	}

// 	if GetIntersection(Ray, World, &Record)
// 	{
// 		SurfaceMaterial := World.Materials[Record.MaterialIndex]
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

// 		DirectIllumination := ComputeDirectIllumination(Ray, Record, World)
// 		IndirectIllumination := BRDF * CosAtten * ComputeIndirectIllumination(World, Ray.Direction, &Record) / PDF

// 		return DirectIllumination + IndirectIllumination
// 	}
// 	else
// 	{
// 		return World.Materials[0].(lambertian).Color
// 	}
// }

