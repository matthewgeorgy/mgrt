package main

import fmt		"core:fmt"
import libc		"core:c/libc"
import strings	"core:strings"
import runtime 	"base:runtime"

// TODO(matthew): This MERL probably needs a LOT of work...
// 1. LoadMERL seems to be fine, I don't see anything that could be problematic.
// 2. BRDFLookup is a bit ad-hoc right now. It's more or less directly copied
//    from Casey's implementation on Handmade Ray, which initially used the z
//    coordinate for Theta, but we use y so I changed that. I'll have to spend
//    some time looking back at on his video and the original paper to see if
//    it's all being done correctly.
// 3. SampleMERLBRDF is generating it's own random direction for Sample.wi, but
//    then using a vector to the light source for the wi that we pass in to
//    BRDFLookup. We really should be passing wi instead (unless this is actually
//    what the paper wants - have to read it again), but that doesn't seem to work.
// 4. Currently, EvaluateMERLBRDF doesn't do anything, just returns zero. It's
//    going to have to call into the BRDFLookup, but this requires a lot more data
//    than just wo and wi - we also need a basis, which the current inteface for
//    EvaluateBxDF doesn't support. A simple way to fix this is to just pass in the
//    hit record as well, as this will give us the surface normal we can use to
//    construct a basis. With this we can just send the transformed vectors
//    directly to BRDFLookup, without having to compute LW and HW internally.
//
// The implementation seems to be working alright for some of the glossier
// materials, like brass.binary and gold-metallic-paint.binary. We do get a lot of
// noise when using a low sample count, but with a high enough sample count (500+)
// we actually get something pretty reasonable (see brass.bmp). This could be a
// consequence of something in our BRDFLookup not being quite up to snuff.

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

BRDFLookup :: proc(Table : ^merl_table, ViewDir, LightDir : v3, Basis : basis) -> v3
{
	HalfVector := Normalize(0.5 * (ViewDir + LightDir))

	Tangent := Basis.u

	LW := BasisTransform(Basis, LightDir)
	HW := BasisTransform(Basis, HalfVector)

    DiffY := Normalize(Cross(HW, Tangent))
    DiffX := Cross(DiffY, HW)

    DiffXInner := Dot(DiffX, LW);
    DiffYInner := Dot(DiffY, LW);
    DiffZInner := Dot(HW, LW);

	ThetaHalf : f32 = ACos(HW.y)
	ThetaDiff : f32 = ACos(DiffZInner)
	PhiDiff : f32 = ATan2(DiffYInner, DiffXInner)
	if(PhiDiff < 0)
	{
		PhiDiff += PI;
	}

	// TODO(casey): Does this just undo what the acos did?  Because I
	// think it does, and then we could just avoid the acos altogether...
	F0 := SquareRoot(clamp(ThetaHalf / (0.5 * PI), 0, 1))
	I0 := u32(f32(Table.Count[0] - 1) * F0)

	F1 : f32 = clamp(ThetaDiff / (0.5 * PI), 0, 1)
	I1 : u32 = u32(f32(Table.Count[1] - 1) * F1)

	F2 : f32 = clamp(PhiDiff / PI, 0, 1);
	I2 : u32 = u32(f32(Table.Count[2] - 1) * F2);

	Index : u32 = I2 + I1 * Table.Count[2] + I0*Table.Count[1]*Table.Count[2]

	runtime.assert(Index < (Table.Count[0]*Table.Count[1]*Table.Count[2]), "BRDF bad")

	Color := Table.Values[Index]

    return Color
}

