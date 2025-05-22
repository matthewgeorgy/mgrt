package main

scene :: struct
{
	Materials : [dynamic]material,
	Lights : [dynamic]light,

	Primitives : [dynamic]primitive,
	LightIndices : [dynamic]u32,

	BVH : bvh,
	GlobalPhotonMap : ^photon_map,
	CausticPhotonMap : ^photon_map,

	SamplesPerPixel : u32,
	MaxDepth : int,
};

GatherLightIndices :: proc(Scene : ^scene)
{
	if len(Scene.Lights) != 0
	{
		for Primitive, Index in Scene.Primitives
		{
			if Primitive.LightIndex != 0
			{
				append(&Scene.LightIndices, u32(Index))
			}
		}
	}
}

