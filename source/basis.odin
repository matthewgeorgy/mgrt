package main

basis :: struct
{
	s : v3, // tangent
	t : v3, // bitangent
	n : v3, // normal
}

CreateBasis :: proc(Normal : v3) -> basis
{
	Basis : basis

	A := (Abs(Normal.x) > 0.9) ? v3{0, 1, 0} : v3{1, 0, 0}

	Basis.n = Normalize(Normal)
	Basis.s = Normalize(Cross(Basis.n, A))
	Basis.t = Cross(Basis.n, Basis.s)

	return Basis
}

LocalToGlobal :: proc(Basis : basis, Vector : v3) -> v3
{
	return (Vector.x * Basis.s) + (Vector.y * Basis.t) + (Vector.z * Basis.n)
}

GlobalToLocal :: proc(Basis : basis, Vector : v3) -> v3
{
	Out : v3

	Out.x = Dot(Basis.s, Vector)
	Out.y = Dot(Basis.t, Vector)
	Out.z = Dot(Basis.n, Vector)

	return Out
}

GlobalToLocalNormalized :: proc(Basis : basis, Vector : v3) -> v3
{
	return Normalize(GlobalToLocal(Basis, Vector))
}

