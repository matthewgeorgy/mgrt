package main

cosine_pdf :: struct
{
	Basis : basis,
};

sphere_pdf :: struct
{
	Dummy : f32,
};

pdf :: union
{
	sphere_pdf,
	cosine_pdf,
};

GeneratePDFValue :: proc(PDF : pdf, Direction : v3) -> f32
{
	RandomValue : f32

	switch Type in PDF
	{
		case sphere_pdf:
		{
			RandomValue = SpherePDFValue(PDF.(sphere_pdf), Direction)
		}
		case cosine_pdf:
		{
			RandomValue = CosinePDFValue(PDF.(cosine_pdf), Direction)
		}
	}

	return RandomValue
}

GeneratePDFDirection :: proc(PDF : pdf) -> v3
{
	RandomDirection : v3

	switch Type in PDF
	{
		case sphere_pdf:
		{
			RandomDirection = SpherePDFDirection(PDF.(sphere_pdf))
		}
		case cosine_pdf:
		{
			RandomDirection = CosinePDFDirection(PDF.(cosine_pdf))
		}
	}

	return RandomDirection
}

SpherePDFValue :: proc(PDF : sphere_pdf, Direction : v3) -> f32
{
	RandomValue := 1 / (4 * PI)

	return RandomValue
}

SpherePDFDirection :: proc(PDF : sphere_pdf) -> v3
{
	RandomDirection := RandomUnitVector()

	return RandomDirection
}

CosinePDFValue :: proc(PDF : cosine_pdf, Direction : v3) -> f32
{
	Basis := PDF.Basis

	CosineTheta := Dot(Normalize(Direction), Basis.w)
	RandomValue := Max(0, CosineTheta / PI)

	return RandomValue
}

CosinePDFDirection :: proc(PDF : cosine_pdf) -> v3
{
	Basis := PDF.Basis

	RandomDirection := BasisTransform(Basis, RandomCosineDirection())

	return RandomDirection
}

