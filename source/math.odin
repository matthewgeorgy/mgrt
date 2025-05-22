package main

import fmt		"core:fmt"
import math		"core:math"
import linalg	"core:math/linalg"
import rand		"core:math/rand"

v3f	:: [3]f32
v3i :: [3]i32
v3u :: [3]u32
v3 	:: v3f

Cross 			:: linalg.cross
Dot 			:: linalg.dot
Normalize 		:: linalg.normalize
Length 			:: linalg.length
LengthSquared	:: linalg.length2
SquareRoot 		:: linalg.sqrt
Abs 			:: abs
Min 			:: min
Max 			:: max
Sin				:: math.sin
Cos				:: math.cos
ACos			:: math.acos
ATan2			:: math.atan2
Tan				:: math.tan
Pow				:: math.pow_f32
Degs2Rads		:: math.to_radians_f32
Rads2Degs		:: math.to_degrees_f32
Clamp			:: clamp

F32_MAX 		:: 3.402823466e+38
PI				: f32 : math.PI
INV_PI			: f32 : 1.0 / PI

RandomUnilateral :: proc() -> f32
{
	return rand.float32()
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

RandomV3 :: proc{ RandomV3_Unilateral, RandomV3_Ranged, }

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

Reflect :: proc(Vector, Normal : v3) -> v3
{
	return Vector - 2 * Dot(Vector, Normal) * Normal
}

Refract :: proc(UV, Normal : v3, AngleRatio : f32) -> v3
{
	CosTheta := Min(Dot(-UV, Normal), 1)
	Perpendicular := AngleRatio * (UV + CosTheta * Normal)
	Parallel := -SquareRoot(Abs(1 - LengthSquared(Perpendicular))) * Normal

	return Perpendicular + Parallel
}

// Shlick approximation
FresnelReflectance :: proc(Cosine, RefractionIndex : f32) -> f32
{
	r0 := (1 - RefractionIndex) / (1 + RefractionIndex)
	r0 = r0 * r0

	return r0 + (1 - r0) * Pow(1 - Cosine, 5)
}

///////////////////////////////////////
// Utility functions for angles

CosTheta :: proc(w : v3) -> f32
{
	return w.z
}

Cos2Theta :: proc(w : v3) -> f32
{
	return w.z * w.z
}

AbsCosTheta :: proc(w : v3) -> f32
{
	return Abs(w.z)
}

SinTheta :: proc(w : v3) -> f32
{
	return SquareRoot(Sin2Theta(w))
}

Sin2Theta :: proc(w : v3) -> f32
{
	return Max(0, 1 - Cos2Theta(w))
}

TanTheta :: proc(w : v3) -> f32
{
	return SinTheta(w) / CosTheta(w)
}

Tan2Theta :: proc(w : v3) -> f32
{
	return Sin2Theta(w) / Cos2Theta(w)
}

CosPhi :: proc(w : v3) -> f32
{
	SinTheta := SinTheta(w)

	return (SinTheta == 0) ? 1 : Clamp(w.x / SinTheta, -1, 1)
}

SinPhi :: proc(w : v3) -> f32
{
	SinTheta := SinTheta(w)

	return (SinTheta == 0) ? 0 : Clamp(w.y / SinTheta, -1, 1)
}

Cos2Phi :: proc(w : v3) -> f32
{
	return CosPhi(w) * CosPhi(w)
}

Sin2Phi :: proc(w : v3) -> f32
{
	return SinPhi(w) * SinPhi(w)
}

