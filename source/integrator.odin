package main

integrator_proc :: #type proc(ray, ^scene, int, int) -> v3

integrator_type :: enum
{
	PATH_TRACING,
	PHOTON_MAP,
	NEE,
}

integrator :: struct
{
	Proc : integrator_proc,
	Type : integrator_type,

	SamplesPerPixel : int,
	MaxDepth : int,
}

PathTracingIntegrator :: proc(Ray : ray, Scene : ^scene, CurrentDepth, MaxDepth : int) -> v3
{
	Record : hit_record

	if CurrentDepth == MaxDepth
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

		return CosAtten * f * PathTracingIntegrator(ScatteredRay, Scene, CurrentDepth + 1, MaxDepth) / PDF
	}
	else
	{
		return Scene.Materials[0].(lambertian).Rho
	}
}

PhotonMapIntegrator :: proc(Ray : ray, Scene : ^scene, CurrentDepth, MaxDepth : int) -> v3
{
	Record : hit_record

	if CurrentDepth == MaxDepth
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

			IndirectIllumination := ComputeIndirectIllumination(Scene, Ray.Direction, &Record, 0, MaxDepth)

			CausticsQuery := photon_map_query{ SurfaceMaterial, Record, -Ray.Direction, 100 }
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

			return f * CosAtten * PhotonMapIntegrator(NewRay, Scene, CurrentDepth + 1, MaxDepth) / PDF
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

ComputeDirectIllumination :: proc(Ray : ray, Record : hit_record, Scene : ^scene) -> v3
{
	DirectIllumination : v3

	LightSurface := SampleRandomLight(Scene)
	ToLight := Normalize(LightSurface.Point - Record.HitPoint)
	DistanceSquared := LengthSquared(LightSurface.Point - Record.HitPoint)

	LightArea := 1.0 / LightSurface.PDF
	LightCosine := Abs(Dot(ToLight, Normalize(LightSurface.Normal)))
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

ComputeIndirectIllumination :: proc(Scene : ^scene, RayDirection : v3, Record : ^hit_record, CurrentDepth, MaxDepth : int) -> v3
{
	Indirect : v3

	if CurrentDepth == MaxDepth
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
				Query := photon_map_query{ HitMaterial, FinalRecord, -FinalRay.Direction, 100 }

				Indirect = f * CosAtten * RadianceEstimate(Scene.GlobalPhotonMap, Query) / Sample.PDF
			}
			else if MaterialType == .SPECULAR
			{
				Indirect = f * CosAtten * ComputeIndirectIllumination(Scene, -FinalRay.Direction, &FinalRecord, CurrentDepth + 1, MaxDepth) / Sample.PDF
			}
		}
	}

	return Indirect
}

NEEIntegrator :: proc(Ray : ray, Scene : ^scene, CurrentDepth, MaxDepth : int) -> v3
{
	Record : hit_record

	if CurrentDepth == MaxDepth
	{
		return v3{}
	}

	if GetIntersection(Ray, Scene, &Record)
	{
		Output : v3 // weight=0  most of the time, except at first bounce

		if CurrentDepth == 0
		{
			if HasLight(Record)
			{
				Light := Scene.Lights[Record.LightIndex]
				Output = Light.Le
			}
		}

		SurfaceMaterial := Scene.Materials[Record.MaterialIndex]

		SampleResult := SampleBxDF(SurfaceMaterial, -Ray.Direction, Record)

		f := SampleResult.f
		Dir := SampleResult.wi
		PDF := SampleResult.PDF

		CosAtten := Abs(Dot(Dir, Record.SurfaceNormal))

		ScatteredRay := ray{Record.HitPoint, Dir}

		Direct := ComputeDirectIllumination(Ray, Record, Scene)
		Indirect := CosAtten * f * NEEIntegrator(ScatteredRay, Scene, CurrentDepth + 1, MaxDepth) / PDF

		Output += (Direct + Indirect) // weight=1 most of the time

		return Output
	}
	else
	{
		return Scene.Materials[0].(lambertian).Rho
	}
}

