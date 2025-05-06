package main

ScatteringPDF :: proc(SurfaceMaterial : material, InputRay, ScatteredRay : ray, Record : hit_record) -> f32
{
	PDF : f32

	switch Type in SurfaceMaterial
	{
		case lambertian:
		{
			PDF = LambertianPDF(SurfaceMaterial.(lambertian), InputRay, ScatteredRay, Record)
		}
		case light:
		case dielectric:
		case metal:
		{
			PDF = 0
		}
	}

	return PDF
}

LambertianPDF :: proc(Material : lambertian, InputRay, ScatteredRay : ray, Record : hit_record) -> f32
{
	Basis := CreateBasis(Record.SurfaceNormal)

	return Dot(Basis.w, ScatteredRay.Direction) / PI
}

