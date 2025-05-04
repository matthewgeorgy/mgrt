package main

bvh_node :: struct
{
	AABBMin, AABBMax : v3,
	LeftNode, FirstTriangleIndex, TriangleCount : u32,
};

MinV3 :: proc(A, B : v3) -> v3
{
	return v3{Min(A.x, B.x), Min(A.y, B.y), Min(A.z, B.z)}
}

MaxV3 :: proc(A, B : v3) -> v3
{
	return v3{Max(A.x, B.x), Max(A.y, B.y), Max(A.z, B.z)}
}

// NOTE(matthew): globals for now, will put into a BVH struct later
Centroids : [dynamic]v3
Nodes : [dynamic]bvh_node
RootNodeIndex : u32 = 0
NodesUsed : u32 = 1
TriangleIndices : [dynamic]u32

BuildBVH :: proc()
{
	for Triangle, Index in Triangles
	{
		Centroid := (1.0 / 3.0) * (Triangle.Vertices[0] + Triangle.Vertices[1] + Triangle.Vertices[2])

		append(&Centroids, Centroid)
		append(&TriangleIndices, u32(Index))
	}

	Nodes = make([dynamic]bvh_node, 2 * len(Triangles) - 1)

	Root := &Nodes[RootNodeIndex]

	Root.FirstTriangleIndex = 0
	Root.TriangleCount = u32(len(Triangles))

	UpdateNodeBounds(RootNodeIndex)
	Subdivide(RootNodeIndex)
}

UpdateNodeBounds :: proc(NodeIndex : u32)
{
	Node := &Nodes[NodeIndex]

	Node.AABBMin = v3{ F32_MAX,  F32_MAX,  F32_MAX}
	Node.AABBMax = v3{-F32_MAX, -F32_MAX, -F32_MAX}

	First := Node.FirstTriangleIndex
	for I : u32 = 0; I < Node.TriangleCount; I += 1
	{
		LeafTriangleIndex := TriangleIndices[First + I]
		LeafTriangle := Triangles[LeafTriangleIndex]

		Node.AABBMin = MinV3(Node.AABBMin, LeafTriangle.Vertices[0])
		Node.AABBMin = MinV3(Node.AABBMin, LeafTriangle.Vertices[1])
		Node.AABBMin = MinV3(Node.AABBMin, LeafTriangle.Vertices[2])
		Node.AABBMax = MaxV3(Node.AABBMax, LeafTriangle.Vertices[0])
		Node.AABBMax = MaxV3(Node.AABBMax, LeafTriangle.Vertices[1])
		Node.AABBMax = MaxV3(Node.AABBMax, LeafTriangle.Vertices[2])
	}
}

Subdivide :: proc(NodeIndex : u32)
{
	Node := &Nodes[NodeIndex]

	// Termiante if only two triangles left in this node
	if Node.TriangleCount <= 2
	{
		return
	}

	// Determine (the longest) split axis and position
	Extent := Node.AABBMax - Node.AABBMin
	Axis : u32 = 0

	if Extent.y > Extent.x
	{
		Axis = 1
	}
	if Extent.z > Extent[Axis]
	{
		Axis = 2
	}

	SplitPos : f32 = Node.AABBMin[Axis] + 0.5 * Extent[Axis]

	// Partition in-place
	I := Node.FirstTriangleIndex
	J := I + Node.TriangleCount - 1

	for I <= J
	{
		if Centroids[TriangleIndices[I]][Axis] < SplitPos
		{
			I += 1
		}
		else
		{
			// Swap
			Temp := TriangleIndices[I]
			TriangleIndices[I] = TriangleIndices[J]
			TriangleIndices[J] = Temp
			J -= 1
		}
	}

	// Abort the split if one of the sides is empty
	LeftCount := I - Node.FirstTriangleIndex
	if LeftCount == 0 || LeftCount == Node.TriangleCount
	{
		return
	}

	// Create child nodes
	LeftChildIndex := NodesUsed
	RightChildIndex := NodesUsed + 1
	NodesUsed += 2

	Nodes[LeftChildIndex].FirstTriangleIndex = Node.FirstTriangleIndex
	Nodes[LeftChildIndex].TriangleCount = LeftCount
	Nodes[RightChildIndex].FirstTriangleIndex = I
	Nodes[RightChildIndex].TriangleCount = Node.TriangleCount - LeftCount

	Node.LeftNode = LeftChildIndex
	Node.TriangleCount = 0

	UpdateNodeBounds(LeftChildIndex)
	UpdateNodeBounds(RightChildIndex)

	// Recurse
	Subdivide(LeftChildIndex)
	Subdivide(RightChildIndex)
}

IsLeaf :: proc(Node : bvh_node) -> b32
{
	return Node.TriangleCount > 0
}

RayIntersectAABB :: proc(Ray : ray, BoxMin, BoxMax : v3) -> b32
{
	tx1 := (BoxMin.x - Ray.Origin.x) / Ray.Direction.x
	tx2 := (BoxMax.x - Ray.Origin.x) / Ray.Direction.x

	tMin := Min(tx1, tx2)
	tMax := Max(tx1, tx2)

	ty1 := (BoxMin.y - Ray.Origin.y) / Ray.Direction.y
	ty2 := (BoxMax.y - Ray.Origin.y) / Ray.Direction.y

	tMin = Max(tMin, Min(ty1, ty2))
	tMax = Min(tMax, Max(ty1, ty2))

	tz1 := (BoxMin.z - Ray.Origin.z) / Ray.Direction.z
	tz2 := (BoxMax.z - Ray.Origin.z) / Ray.Direction.z

	tMin = Max(tMin, Min(tz1, tz2))
	tMax = Min(tMax, Max(tz1, tz2))

	return (tMax >= tMin) && (tMin < Ray.t) && (tMax > 0)
}

RayIntersectBVH :: proc(Ray : ^ray, NodeIndex : u32)
{
	Node := Nodes[NodeIndex]

	if !RayIntersectAABB(Ray^, Node.AABBMin, Node.AABBMax)
	{
		return
	}

	if IsLeaf(Node)
	{
		HitDistance : f32 = F32_MAX

		FirstIndex := Node.FirstTriangleIndex
		for I : u32 = 0; I < Node.TriangleCount; I += 1
		{
			TriangleIndex := TriangleIndices[FirstIndex + I]
			RayIntersectTriangle(Ray, Triangles[TriangleIndex])
		}
	}
	else
	{
		RayIntersectBVH(Ray, Node.LeftNode)
		RayIntersectBVH(Ray, Node.LeftNode + 1)
	}
}

