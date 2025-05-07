package main

import slice	"core:slice"

photon :: struct
{
	Pos : v3,
	Theta, Phi : u8,
	Dir : v3,
	Power : v3
};

photon_node :: struct
{
	Photon : photon,

	Axis : int,
	Left, Right : ^photon_node,
};

photon_map :: struct
{
	// From Jensen
	StoredPhotons : i32,
	HalfStoredPhotons : i32,
	MaxPhotons : i32,
	PrevScale : i32,
	CosTheta : [256]f32,
	SinTheta : [256]f32,
	CosPhi : [256]f32,
	SinPhi : [256]f32,
	Photons : [dynamic]photon,

	// kd-tree
	Root : ^photon_node,
	Nodes : []photon_node,
	NodeCount : int,
};

nearest_photons :: struct
{
	PhotonsFound : [dynamic]^photon
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

	for AngleIndex := 0; AngleIndex < 256; AngleIndex += 1
	{
		Angle := f32(AngleIndex) * (1.0 / 256.0) * PI

		Map.CosTheta[AngleIndex] = Cos(Angle)
		Map.SinTheta[AngleIndex] = Sin(Angle)
		Map.CosPhi[AngleIndex] = Cos(2.0 * Angle)
		Map.SinPhi[AngleIndex] = Sin(2.0 * Angle)
	}

	return Map
}

StorePhoton :: proc(Map : ^photon_map, Pos, Power, Dir : v3)
{
	if Map.StoredPhotons >= Map.MaxPhotons
	{
		return
	}

	Photon : photon

	Photon.Pos = Pos
	Photon.Power = Power
	Photon.Dir = Dir

	Theta := int(ACos(Dir[2]) * (256.0 / PI))
	if Theta > 255
	{
		Photon.Theta = 255
	}
	else
	{
		Photon.Theta = u8(Theta)
	}

	Phi := int(ATan2(Dir[1], Dir[0]) * (256.0 / (2.0 * PI)))
	if Phi > 255
	{
		Photon.Phi = 255
	}
	else if Phi < 0
	{
		Photon.Phi = 0
	}
	else
	{
		Photon.Phi = u8(Phi)
	}

	append(&Map.Photons, Photon)
	Map.StoredPhotons += 1
}

ScalePhotonPower :: proc(Map : ^photon_map, Scale : f32)
{
	for PhotonIndex := 0; PhotonIndex < len(Map.Photons); PhotonIndex += 1
	{
		Map.Photons[PhotonIndex].Power *= Scale
	}

	Map.PrevScale = Map.StoredPhotons
}

MapPhotonDirection :: proc(Map : ^photon_map, Photon : photon) -> v3
{
	Direction : v3

	Direction[0] = Map.SinTheta[Photon.Theta] * Map.CosPhi[Photon.Phi]
	Direction[1] = Map.SinTheta[Photon.Theta] * Map.SinPhi[Photon.Phi]
	Direction[2] = Map.CosTheta[Photon.Theta]

	return Direction
}

IrradianceEstimate :: proc(Map : ^photon_map, Pos, Normal : v3, MaxDistance : f32) -> v3
{
	Irradiance : v3
	Dir : v3

	NearestPhotons := LocatePhotons(Map, Pos, MaxDistance)
	defer delete(NearestPhotons.PhotonsFound)

	if len(NearestPhotons.PhotonsFound) < 0
	{
		return v3{0, 0, 0}
	}

	for Photon in NearestPhotons.PhotonsFound
	{
		PhotonDir := MapPhotonDirection(Map, Photon^)
		if Dot(Photon.Dir, Normal) < 0
		{
			Irradiance += Photon.Power
		}
	}

	// TODO(matthew): see if this needs to be changed? Was causing problems in the past
	Temp := 1.0  / (PI * MaxDistance * MaxDistance) // density estimate

	Irradiance *= Temp

	return Irradiance
}

// NOTE(matthew): to be called before the integrator!
CastPhoton :: proc(Map : ^photon_map, Ray : ray, World : ^world)
{
	Record : hit_record

	HitSomething := GetIntersection(Ray, World, &Record)

	if HitSomething
	{
		SurfaceMaterial := World.Materials[Record.MaterialIndex]
		ScatterRecord := Scatter(SurfaceMaterial, Ray, Record)

		if ScatterRecord.ScatterAgain
		{
			Color := ScatterRecord.Attenuation
			StorePhoton(Map, Record.HitPoint, Color, Record.IncomingRay.Direction)
		}
	}
}

///////////////////////////////////////
// These functions are for working with the kd-structure of the photon map
///////////////////////////////////////

SortByX :: proc(A, B : photon) -> bool
{
	return A.Pos.x < B.Pos.x
}

SortByY :: proc(A, B : photon) -> bool
{
	return A.Pos.y < B.Pos.y
}

SortByZ :: proc(A, B : photon) -> bool
{
	return A.Pos.z < B.Pos.z
}

SortByAxis : []proc(photon, photon)->bool = { SortByX, SortByY, SortByZ }

BuildPhotonMap :: proc(Map : ^photon_map)
{
	Map.Nodes = make([]photon_node, Map.StoredPhotons)
	Map.Root = InsertNode(Map, Map.Photons[:], 0)
}

InsertNode :: proc(Map : ^photon_map, Photons : []photon, Axis : int) -> ^photon_node
{
	PhotonNode : ^photon_node

	if len(Photons) == 0
	{
		return nil
	}
	else
	{
		NewAxis := (Axis + 1) % 3

		slice.sort_by(Photons, SortByAxis[NewAxis])

		MedianIndex := len(Photons) / 2

		Node := &Map.Nodes[Map.NodeCount]
		Map.NodeCount += 1

		Node.Photon = Photons[MedianIndex]
		Node.Axis = NewAxis

		Node.Left = InsertNode(Map, Photons[0 : MedianIndex], NewAxis)
		Node.Right = InsertNode(Map, Photons[MedianIndex + 1 : len(Photons)], NewAxis)

		return Node
	}
}

LocatePhotons :: proc(Map : ^photon_map, Pos : v3, MaxDistance : f32) -> nearest_photons
{
	Photons : nearest_photons

	FindPhotons(Map.Root, Pos, MaxDistance, &Photons.PhotonsFound)

	return Photons
}

FindPhotons :: proc(Node : ^photon_node, Pos : v3, MaxDistance : f32, PhotonsFound : ^[dynamic]^photon) -> int
{
	AddedRes : int = 0

	if Node == nil
	{
		return 0
	}

	DistSq := LengthSquared(Node.Photon.Pos - Pos)
	if (DistSq <= MaxDistance * MaxDistance)
	{
		append(PhotonsFound, &Node.Photon)

		AddedRes = 1
	}

	dx : f32 = Pos[Node.Axis] - Node.Photon.Pos[Node.Axis]

	Ret := FindPhotons(dx < 0.0 ? Node.Left : Node.Right, Pos, MaxDistance, PhotonsFound)
	if (Ret >= 0 && Abs(dx) < MaxDistance)
	{
		AddedRes += Ret
		Ret = FindPhotons(dx < 0.0 ? Node.Right : Node.Left, Pos, MaxDistance, PhotonsFound)
	}

	AddedRes += Ret

	return AddedRes
}

