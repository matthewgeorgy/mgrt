package main

import fmt		"core:fmt"
import slice	"core:slice"
import pq		"core:container/priority_queue"

photon :: struct
{
	Pos : v3,
	Dir : v3,
	Power : v3
};

photon_map :: struct
{
	// From Jensen
	StoredPhotons : i32,
	HalfStoredPhotons : i32,
	MaxPhotons : i32,
	PrevScale : i32,
	Photons : [dynamic]photon,

	// kd-tree
	Nodes : [dynamic]kd_node,
};

nearest_photons :: struct
{
	Photons : []photon,
	MaxDist2 : f32,
};

///////////////////////////////////////
// These functions are for working with the actual rendering of the photon map
///////////////////////////////////////

CreatePhotonMap :: proc(MaxPhotons : i32) -> photon_map
{
	Map : photon_map

	Map.StoredPhotons = 0
	Map.PrevScale = 1
	Map.MaxPhotons = MaxPhotons

	Map.Photons = make([dynamic]photon, 0, MaxPhotons)

	return Map
}

StorePhoton :: proc(Map : ^photon_map, Pos, Power, Dir : v3)
{
	if Map.StoredPhotons < Map.MaxPhotons
	{
		Photon := photon{ Pos, Dir, Power }

		append(&Map.Photons, Photon)
		Map.StoredPhotons += 1
	}
}

ScalePhotonPower :: proc(Map : ^photon_map, Scale : f32)
{
	for PhotonIndex := 0; PhotonIndex < len(Map.Photons); PhotonIndex += 1
	{
		Map.Photons[PhotonIndex].Power *= Scale
	}

	Map.PrevScale = Map.StoredPhotons
}

photon_map_query :: struct
{
	Material : material,
	Record : hit_record,
	wo : v3,
	NumPhotons : int,
}

RadianceEstimate :: proc(Map : ^photon_map, Query : photon_map_query) -> v3
{
	Radiance : v3

	NearestPhotons := LocatePhotons(Map, Query.Record.HitPoint, Query.NumPhotons)
	defer delete(NearestPhotons.Photons)

	if len(NearestPhotons.Photons) == 0
	{
		return v3{0, 0, 0}
	}

	MaxDist2 : f32
	for Photon in NearestPhotons.Photons
	{
		f := EvaluateBxDF(Query.Material, Query.wo, Photon.Dir, Query.Record)

		Radiance += f * Photon.Power
	}

	AreaFactor := 1.0  / (PI * NearestPhotons.MaxDist2)

	Radiance *= AreaFactor

	return Radiance
}

SampleRayFromLight :: proc(Scene : ^scene) -> (ray, v3)
{
	Ray : ray
	Power : v3

	LightSurface := SampleRandomLight(Scene)
	Ray.Origin = LightSurface.Point

	Basis := CreateBasis(LightSurface.Normal)
	Ray.Direction = LocalToGlobal(Basis, RandomCosineDirection())
	CosineTheta := Dot(Normalize(Ray.Direction), Basis.n)
	LightDirPDF := Max(0, CosineTheta / PI)

	CosAtten := Max(Dot(LightSurface.Normal, Ray.Direction), 0)

	Power = LightSurface.Color * CosAtten / (LightSurface.PDF * LightDirPDF)

	return Ray, Power
}

BuildGlobalPhotonMap :: proc(Map : ^photon_map, Scene : ^scene)
{
	EmittedPhotons :: 100000
	MaxPhotonBounces := Scene.MaxDepth

	for PhotonIndex := 0; PhotonIndex < EmittedPhotons; PhotonIndex += 1
	{
		Ray, Power := SampleRayFromLight(Scene)

		CastGlobalPhoton(Map, Ray, Power, Scene, MaxPhotonBounces)
	}

	fmt.println("\nStored", Map.StoredPhotons, "photons")
	fmt.println(Map.StoredPhotons * size_of(photon) / (1024), "KB of photons")
	ScalePhotonPower(Map, f32(1.0) / f32(EmittedPhotons))

	BuildTree(Map)
}

BuildCausticPhotonMap :: proc(Map : ^photon_map, Scene : ^scene)
{
	EmittedPhotons :: 100000
	MaxPhotonBounces := Scene.MaxDepth

	for PhotonIndex := 0; PhotonIndex < EmittedPhotons; PhotonIndex += 1
	{
		Ray, Power := SampleRayFromLight(Scene)

		CastCausticPhoton(Map, Ray, Power, Scene, MaxPhotonBounces)
	}

	fmt.println("\nStored", Map.StoredPhotons, "photons")
	fmt.println(Map.StoredPhotons * size_of(photon) / (1024), "KB of photons")
	ScalePhotonPower(Map, f32(1.0) / f32(EmittedPhotons))

	BuildTree(Map)
}

CastGlobalPhoton :: proc(Map : ^photon_map, InitialRay : ray, InitialPower : v3, Scene : ^scene, MaxPhotonBounces : int)
{
	Throughput := InitialPower
	Ray := InitialRay
	BounceCount : int

	for BounceCount = 0; BounceCount < MaxPhotonBounces; BounceCount += 1
	{
		Record : hit_record

		if GetIntersection(Ray, Scene, &Record)
		{
			if HasLight(Record)
			{
				break
			}

			SurfaceMaterial := Scene.Materials[Record.MaterialIndex]
			MaterialType := GetMaterialType(SurfaceMaterial)

			// Store diffuse interaction
			if MaterialType == .DIFFUSE
			{
				StorePhoton(Map, Record.HitPoint, Throughput, -Ray.Direction)
			}

			// Russian roulette to start a new photon
			if BounceCount > 0
			{
				RussianRouletteProb := Min(Max(Throughput.x, Throughput.y, Throughput.z), 1)
				RandomRoll := RandomUnilateral()

				if RandomRoll >= RussianRouletteProb
				{
					break
				}
				Throughput /= RussianRouletteProb
			}

			Sample := SampleBxDF(SurfaceMaterial, -Ray.Direction, Record)
			CosAtten := Abs(Dot(Record.SurfaceNormal, Sample.wi))

			Throughput *= CosAtten * Sample.f / Sample.PDF
			Ray = ray{Record.HitPoint, Sample.wi}
		}
		else
		{
			break
		}
	}
}

CastCausticPhoton :: proc(Map : ^photon_map, InitialRay : ray, InitialPower : v3, Scene : ^scene, MaxPhotonBounces : int)
{
	Throughput := InitialPower
	Ray := InitialRay
	BounceCount : int

	PrevSpecular := false

	for BounceCount = 0; BounceCount < MaxPhotonBounces; BounceCount += 1
	{
		Record : hit_record

		if GetIntersection(Ray, Scene, &Record)
		{
			if HasLight(Record)
			{
				break
			}

			SurfaceMaterial := Scene.Materials[Record.MaterialIndex]

			MaterialType := GetMaterialType(SurfaceMaterial)

			// Break when hitting diffuse surface without a previous specular hit
			if MaterialType == .DIFFUSE && !PrevSpecular
			{
				break
			}

			if MaterialType == .DIFFUSE && PrevSpecular
			{
				StorePhoton(Map, Record.HitPoint, Throughput, -Ray.Direction)
			}

			PrevSpecular = (MaterialType == .SPECULAR)

			// Russian roulette for new photon
			if BounceCount > 0
			{
				RussianRouletteProb := Min(Max(Throughput.x, Throughput.y, Throughput.z), 1)
				RandomRoll := RandomUnilateral()

				if RandomRoll >= RussianRouletteProb
				{
					break
				}
				Throughput /= RussianRouletteProb
			}

			Sample := SampleBxDF(SurfaceMaterial, -Ray.Direction, Record)
			CosAtten := Abs(Dot(Record.SurfaceNormal, Sample.wi))

			Throughput *= CosAtten * Sample.f / Sample.PDF
			Ray = ray{Record.HitPoint, Sample.wi}
		}
		else
		{
			break
		}
	}
}

///////////////////////////////////////
// These functions are for working with the kd-structure of the photon map
///////////////////////////////////////

kd_node :: struct
{
	Idx : i32,
	Axis : i32,
	LeftChildIdx, RightChildIdx : i32,
};

knn_pair :: struct
{
	Dist2 : f32,
	Idx : i32,
}

knn_queue :: pq.Priority_Queue(knn_pair)

BuildTree :: proc(Map : ^photon_map)
{
	Indices := make([]i32, len(Map.Photons))

	for I : i32 = 0; I < i32(len(Indices)); I += 1
	{
		Indices[I] = I
	}

	// Need this when looking up points in the sort routines
	context.user_ptr = Map

	BuildNode(Map, Indices[:], 0)
}

BuildNode :: proc(Map : ^photon_map, Indices : []i32, Axis : i32)
{
	if len(Indices) == 0
	{
		return
	}

	slice.sort_by(Indices, SortByAxis[Axis])

	Mid : i32 = i32(len(Indices) - 1) / 2

	// Remember parent index before we recurse down
	ParentIdx := len(Map.Nodes)

	Node := kd_node{ Axis = Axis, Idx = Indices[Mid] }

	append(&Map.Nodes, Node)

	NewAxis := (Axis + 1) % 3

	// Left children
	LeftChildIdx := len(Map.Nodes)
	BuildNode(Map, Indices[0:Mid], NewAxis)

	if LeftChildIdx == len(Map.Nodes)
	{
		Map.Nodes[ParentIdx].LeftChildIdx = -1
	}
	else
	{
		Map.Nodes[ParentIdx].LeftChildIdx = i32(LeftChildIdx)
	}

	// Right children
	RightChildIdx := len(Map.Nodes)
	BuildNode(Map, Indices[Mid + 1 :], NewAxis)

	if RightChildIdx == len(Map.Nodes)
	{
		Map.Nodes[ParentIdx].RightChildIdx = -1
	}
	else
	{
		Map.Nodes[ParentIdx].RightChildIdx = i32(RightChildIdx)
	}
}

LocatePhotons :: proc(Map : ^photon_map, QueryPoint : v3, k : int) -> nearest_photons
{
	Result : nearest_photons
	Queue : knn_queue

	pq.init(&Queue, KNNQueueSort, KNNQueueSwap, k)

	SearchKNN(Map, 0, QueryPoint, k, &Queue)

	Result.Photons = make([]photon, pq.len(Queue))

	for I := 0; I < len(Result.Photons); I += 1
	{
		Pair := pq.pop(&Queue)

		Result.Photons[I] = Map.Photons[Pair.Idx]
		Result.MaxDist2 = Max(Result.MaxDist2, Pair.Dist2)
	}

	pq.destroy(&Queue)

	return Result
}

SearchKNN :: proc(Map : ^photon_map, NodeIdx : i32, QueryPoint : v3, k : int, Queue : ^knn_queue)
{
	if (NodeIdx == -1) || (NodeIdx >= i32(len(Map.Nodes)))
	{
		return
	}

	Node := Map.Nodes[NodeIdx]

	Median := Map.Photons[Node.Idx].Pos

	Dist2 := LengthSquared(QueryPoint - Median)
	pq.push(Queue, knn_pair{Dist2, Node.Idx})

	if pq.len(Queue^) > k
	{
		pq.pop(Queue)
	}

	// If query point is below the median along this axis, search left
	// Otherwise, search right
	IsLower := QueryPoint[Node.Axis] < Median[Node.Axis]
	if IsLower
	{
		SearchKNN(Map, Node.LeftChildIdx, QueryPoint, k, Queue)
	}
	else
	{
		SearchKNN(Map, Node.RightChildIdx, QueryPoint, k, Queue)
	}

	// At a leaf node, if the queue size is less than k, or the queue's largest
	// min distance overlaps sibling regions, then search the siblings as well
	DistanceToSiblings := Median[Node.Axis] - QueryPoint[Node.Axis]
	Top := pq.peek(Queue^)

	if Top.Dist2 > DistanceToSiblings * DistanceToSiblings
	{
		if IsLower
		{
			SearchKNN(Map, Node.RightChildIdx, QueryPoint, k, Queue)
		}
		else
		{
			SearchKNN(Map, Node.LeftChildIdx, QueryPoint, k, Queue)
		}
	}
}



// Utility functions for sorting, swappping

SortByX :: proc(Idx1, Idx2 : i32) -> bool
{
	Ptr := context.user_ptr
	Map:= (cast(^photon_map)Ptr)^

	return Map.Photons[Idx1].Pos.x < Map.Photons[Idx2].Pos.x
}

SortByY :: proc(Idx1, Idx2 : i32) -> bool
{
	Ptr := context.user_ptr
	Map:= (cast(^photon_map)Ptr)^

	return Map.Photons[Idx1].Pos.y < Map.Photons[Idx2].Pos.y
}

SortByZ :: proc(Idx1, Idx2 : i32) -> bool
{
	Ptr := context.user_ptr
	Map:= (cast(^photon_map)Ptr)^

	return Map.Photons[Idx1].Pos.z < Map.Photons[Idx2].Pos.z
}

SortByAxis : []proc(i32, i32)->bool = { SortByX, SortByY, SortByZ }

KNNQueueSort :: proc(A, B : knn_pair) -> bool
{
	return A.Dist2 > B.Dist2
}

KNNQueueSwap :: proc(q : []knn_pair, i, j : int)
{
	Temp := q[i]
	q[i] = q[j]
	q[j] = Temp
}

