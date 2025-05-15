package main

import fmt		"core:fmt"
import libc		"core:c/libc"
import strings	"core:strings"
import runtime 	"base:runtime"

// TODO(matthew): This MERL stuff needs revisiting...
// The big thing is the normal and bitangent vectors we're using for the rotation
// to compute PhiDiff. They're a bit different than the reference code, but that's
// just because my vectors are oriented differently. It seems in the paper they
// have the z-coordinate as up, but I have the y-coordinate as up, and so on. 
/*
					+y    +z
					 |   /
					 |  /
					 | /
					 |/
	   -x ___________O___________ +x
					/|
				   / |
				  /  |
				 /   |
			   -z
*/
// I'm not actually sure if this is something I have to account for, but the way
// things are right now seem reasonable enough for the time being.
//
// The implementation seems to be working alright for some of the glossier
// materials, like brass.binary and gold-metallic-paint.binary.

RED_SCALE 	:: ( 1.0 / 1500.0)
GREEN_SCALE :: (1.15 / 1500.0)
BLUE_SCALE	:: (1.66 / 1500.0)

merl_table :: struct
{
	Count : [3]u32,
	Values : []v3,
}

LoadMERL :: proc(Filename : string, Table : ^merl_table) -> bool
{
	File := libc.fopen(strings.clone_to_cstring(Filename), "rb")

	if File != nil
	{
		libc.fread(&Table.Count, size_of(Table.Count), 1, File)

		TotalCount : u32 = Table.Count[0] * Table.Count[1] * Table.Count[2]
		TotalReadSize : u32 = TotalCount * 3 * size_of(f64)
		TotalTableSize : u32 = TotalCount

		Table.Values = make([]v3, TotalTableSize)
		Temp := make([]f64, uint(TotalReadSize))

		libc.fread(&Temp[0], uint(TotalReadSize), 1, File)
		for ValueIndex : u32 = 0; ValueIndex < TotalCount; ValueIndex += 1
		{
			Table.Values[ValueIndex].x = f32(Temp[ValueIndex])
			Table.Values[ValueIndex].y = f32(Temp[ValueIndex + TotalCount])
			Table.Values[ValueIndex].z = f32(Temp[ValueIndex + (2 * TotalCount)])
		}

		libc.fclose(File)

		return true
	}
	else
	{
		fmt.println("Failed to load file", Filename)

		return false
	}
}

RotateVector :: proc(Vector : v3, Axis : v3, Angle : f32) -> v3
{
	Out : v3

	CosAngle := Cos(Angle)
	SinAngle := Sin(Angle)

	Out = CosAngle * Vector

	Temp := Dot(Axis, Vector)
	Temp = (1.0 - CosAngle) * Temp

	Out += Temp * Axis

	CrossResult := Cross(Axis, Vector)

	Out += SinAngle * CrossResult

	return Out
}

BRDFLookup :: proc(Table : ^merl_table, ViewDir, LightDir : v3, Basis : basis) -> v3
{
	HalfVector := Normalize(0.5 * (ViewDir + LightDir))

	LW := GlobalToLocal(Basis, LightDir)
	HW := GlobalToLocal(Basis, HalfVector)

	// TODO(matthew): This choice works for now, but probably needs a bit of
	// bulletproofing.
	LocalNormal    := v3{0, 1, 0}
	LocalBitangent := v3{0, 0, -1}

	ThetaHalf : f32 = ACos(HW.z) //
	PhiHalf : f32 = ATan2(HW.y, HW.x) //
	ThetaDiff : f32 = ACos(Dot(HW, LW)) // technically don't need this...

	Temp := RotateVector(LW, LocalNormal, -PhiHalf)
	Diff := RotateVector(Temp, LocalBitangent, -ThetaHalf)

	PhiDiff : f32 = ATan2(Diff.y, Diff.x)

	if(PhiDiff < 0)
	{
		PhiDiff += PI
	}

	// TODO(casey): Does this just undo what the acos did?  Because I
	// think it does, and then we could just avoid the acos altogether...
	F0 := SquareRoot(clamp(ThetaHalf / (0.5 * PI), 0, 1))
	I0 := u32(f32(Table.Count[0] - 1) * F0)

	F1 : f32 = clamp(ThetaDiff / (0.5 * PI), 0, 1)
	I1 : u32 = u32(f32(Table.Count[1] - 1) * F1)

	F2 : f32 = clamp(PhiDiff / PI, 0, 1)
	I2 : u32 = u32(f32(Table.Count[2] - 1) * F2)

	Index : u32 = I2 + I1 * Table.Count[2] + I0*Table.Count[1]*Table.Count[2]

	runtime.assert(Index < (Table.Count[0]*Table.Count[1]*Table.Count[2]), "BRDF bad")

	Result : v3
	Color := Table.Values[Index]

	Result.r = Color.r * RED_SCALE
	Result.g = Color.g * GREEN_SCALE
	Result.b = Color.b * BLUE_SCALE

    return Result
}

