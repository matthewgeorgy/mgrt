package main

random_series :: struct
{
	A, B, C, D : u64,
}

// NOTE(matthew): thread local so that each thread gets its own copy
@(thread_local) RandomSeries : random_series

INITIAL_RNG_SEED :: 0

RotateLeft :: proc(V : u64, Shift : u32) -> u64
{
	Result : u64

	Result = (V << Shift) | (V >> (64 - Shift))

	return Result
}

RandomU64 :: proc(Series : ^random_series) -> u64
{
	A := Series.A
	B := Series.B
	C := Series.C
	D := Series.D

	E := A - RotateLeft(B, 27)

	A = B ~ RotateLeft(C, 17)
	B = C + D
	C = D + E
	D = E + A

	Series.A = A
	Series.B = B
	Series.C = C
	Series.D = D

	return D
}

Seed :: proc(Value : u64) -> random_series
{
	Series : random_series

	Series.A = 0xF1EA5EED
	Series.B = Value
	Series.C = Value
	Series.D = Value

	for I := 0; I < 20; I += 1
	{
		RandomU64(&Series)
	}

	return Series
}

RandomUnilateral :: proc() -> f32
{
	RandomValue := RandomU64(&RandomSeries)
	Result := f32(RandomValue) / f32(max(u64))

	return Result
}

RandomBilateral :: proc() -> f32
{
	Result := 2.0 * RandomUnilateral() - 1

	return Result
}

RandomFloat :: proc(Min, Max : f32) -> f32
{
	Rand := RandomUnilateral()
	Result := Min + (Max - Min) * Rand

	return Result
}

RandomUnitVector :: proc() -> v3
{
	for
	{
		P := v3{RandomBilateral(), RandomBilateral(), RandomBilateral()}
		L := LengthSquared(P)

		if (1e-20 < L && L <= 1)
		{
			return P / SquareRoot(L)
		}
	}
}

RandomV3 :: proc {
	RandomV3_Unilateral,
	RandomV3_Ranged,
}

RandomV3_Unilateral :: proc() -> v3
{
	return v3{RandomUnilateral(), RandomUnilateral(), RandomUnilateral()}
}

RandomV3_Ranged :: proc(Min, Max : f32) -> v3
{
	return v3{RandomFloat(Min, Max), RandomFloat(Min, Max), RandomFloat(Min, Max)}
}

RandomOnHemisphere :: proc(Normal : v3) -> v3
{
	OnUnitSphere := RandomUnitVector()

	if Dot(OnUnitSphere, Normal) > 0
	{
		return OnUnitSphere
	}
	else
	{
		return -OnUnitSphere
	}
}

RandomCosineDirection :: proc() -> v3
{
	Rand1 := RandomUnilateral()
    Rand2 := RandomUnilateral()

    Phi := 2 * PI * Rand1

	x := Cos(Phi) * SquareRoot(Rand2)
    y := Sin(Phi) * SquareRoot(Rand2)
    z := SquareRoot(1 - Rand2)

    return v3{x, y, z}
}

