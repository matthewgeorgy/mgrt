package main

bvh_node :: struct
{
	AABB : aabb,
	LeftFirst, TriangleCount : u32,
};

MinV3 :: proc(A, B : v3) -> v3
{
	return v3{Min(A.x, B.x), Min(A.y, B.y), Min(A.z, B.z)}
}

MaxV3 :: proc(A, B : v3) -> v3
{
	return v3{Max(A.x, B.x), Max(A.y, B.y), Max(A.z, B.z)}
}

bvh :: struct
{
	Nodes : [dynamic]bvh_node,
	Triangles : [dynamic]triangle,
	TriangleIndices : [dynamic]u32,
	Centroids : [dynamic]v3,
	RootNodeIndex : u32,
	NodesUsed : u32,

	MaterialIndex : u32,
	LightIndex : u32,

	Translation : v3,
	Rotation : f32,
};

BuildBVH :: proc(Triangles : [dynamic]triangle) -> bvh
{
	BVH : bvh

	BVH.RootNodeIndex = 0
	BVH.NodesUsed = 1
	BVH.Triangles = Triangles

	for Triangle, Index in Triangles
	{
		Centroid := (1.0 / 3.0) * (Triangle.Vertices[0] + Triangle.Vertices[1] + Triangle.Vertices[2])

		append(&BVH.Centroids, Centroid)
		append(&BVH.TriangleIndices, u32(Index))
	}

	BVH.Nodes = make([dynamic]bvh_node, 2 * len(Triangles))

	Root := &BVH.Nodes[BVH.RootNodeIndex]

	Root.LeftFirst = 0
	Root.TriangleCount = u32(len(Triangles))

	UpdateNodeBounds(&BVH, BVH.RootNodeIndex)
	Subdivide(&BVH, BVH.RootNodeIndex)

	return BVH
}

UpdateNodeBounds :: proc(BVH : ^bvh, NodeIndex : u32)
{
	Node := &BVH.Nodes[NodeIndex]

	Node.AABB.Min = v3{ F32_MAX,  F32_MAX,  F32_MAX}
	Node.AABB.Max = v3{-F32_MAX, -F32_MAX, -F32_MAX}

	First := Node.LeftFirst
	for I : u32 = 0; I < Node.TriangleCount; I += 1
	{
		LeafTriangleIndex := BVH.TriangleIndices[First + I]
		LeafTriangle := BVH.Triangles[LeafTriangleIndex]

		Node.AABB.Min = MinV3(Node.AABB.Min, LeafTriangle.Vertices[0])
		Node.AABB.Min = MinV3(Node.AABB.Min, LeafTriangle.Vertices[1])
		Node.AABB.Min = MinV3(Node.AABB.Min, LeafTriangle.Vertices[2])
		Node.AABB.Max = MaxV3(Node.AABB.Max, LeafTriangle.Vertices[0])
		Node.AABB.Max = MaxV3(Node.AABB.Max, LeafTriangle.Vertices[1])
		Node.AABB.Max = MaxV3(Node.AABB.Max, LeafTriangle.Vertices[2])
	}
}

Subdivide :: proc(BVH : ^bvh, NodeIndex : u32)
{
	Node := &BVH.Nodes[NodeIndex]

	// Termiante if only two triangles left in this node
	if Node.TriangleCount <= 2
	{
		return
	}

	// Determine (the longest) split axis and position
	Extent := Node.AABB.Max - Node.AABB.Min
	Axis : u32 = 0

	if Extent.y > Extent.x
	{
		Axis = 1
	}
	if Extent.z > Extent[Axis]
	{
		Axis = 2
	}

	SplitPos : f32 = Node.AABB.Min[Axis] + 0.5 * Extent[Axis]

	// Partition in-place
	I := Node.LeftFirst
	J := I + Node.TriangleCount - 1

	for I <= J
	{
		if BVH.Centroids[BVH.TriangleIndices[I]][Axis] < SplitPos
		{
			I += 1
		}
		else
		{
			// Swap
			Temp := BVH.TriangleIndices[I]
			BVH.TriangleIndices[I] = BVH.TriangleIndices[J]
			BVH.TriangleIndices[J] = Temp
			J -= 1
		}
	}

	// Abort the split if one of the sides is empty
	LeftCount := I - Node.LeftFirst
	if LeftCount == 0 || LeftCount == Node.TriangleCount
	{
		return
	}

	// Create child nodes
	LeftChildIndex := BVH.NodesUsed
	RightChildIndex := BVH.NodesUsed + 1
	BVH.NodesUsed += 2

	BVH.Nodes[LeftChildIndex].LeftFirst = Node.LeftFirst
	BVH.Nodes[LeftChildIndex].TriangleCount = LeftCount
	BVH.Nodes[RightChildIndex].LeftFirst = I
	BVH.Nodes[RightChildIndex].TriangleCount = Node.TriangleCount - LeftCount

	Node.LeftFirst = LeftChildIndex
	Node.TriangleCount = 0

	UpdateNodeBounds(BVH, LeftChildIndex)
	UpdateNodeBounds(BVH, RightChildIndex)

	// Recurse
	Subdivide(BVH, LeftChildIndex)
	Subdivide(BVH, RightChildIndex)
}

IsLeaf :: proc(Node : bvh_node) -> b32
{
	return Node.TriangleCount > 0
}

TraverseBVH :: proc(Ray : ray, Record : ^hit_record, BVH : bvh, NodeIndex : u32)
{
	Node := BVH.Nodes[NodeIndex]

	if !RayIntersectAABB(Ray, Record, Node.AABB)
	{
		return
	}

	if IsLeaf(Node)
	{
		FirstIndex := Node.LeftFirst
		for I : u32 = 0; I < Node.TriangleCount; I += 1
		{
			TriangleIndex := BVH.TriangleIndices[FirstIndex + I]
			Triangle := BVH.Triangles[TriangleIndex]
			Distance := RayIntersectTriangle(Ray, Triangle)

			if Distance > 0.0001 && Distance < Record.t
			{
				Record.t = Distance 
				Record.BestTriangleIndex = TriangleIndex
			}
		}
	}
	else
	{
		TraverseBVH(Ray, Record, BVH, Node.LeftFirst)
		TraverseBVH(Ray, Record, BVH, Node.LeftFirst + 1)
	}
}

