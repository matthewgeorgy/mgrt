package main

basis :: struct
{
	u, v, w : v3
}

CreateBasis :: proc(Normal : v3) -> basis
{
	Basis : basis

	Basis.w = Normalize(Normal)
	A := (Abs(Basis.w.x) > 0.9) ? v3{0, 1, 0} : v3{1, 0, 0}
	Basis.v = Normalize(Cross(Basis.w, A))
	Basis.u = Cross(Basis.w, Basis.v)

	return Basis
}

LocalToGlobal :: proc(Basis : basis, Vector : v3) -> v3
{
	return (Vector.x * Basis.u) + (Vector.y * Basis.v) + (Vector.z * Basis.w)
}

GlobalToLocal :: proc(Basis : basis, Vector : v3) -> v3
{
	Out : v3

	Out.x = Dot(Basis.u, Vector)
	Out.y = Dot(Basis.v, Vector)
	Out.z = Dot(Basis.w, Vector)

	return Out
}

