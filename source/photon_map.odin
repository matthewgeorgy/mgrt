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
	PhotonIdx : i32,

	Axis : i32,
	Left, Right : i32,
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
	AreaFactor := 1.0  / (PI * MaxDistance * MaxDistance) // density estimate

	Irradiance *= AreaFactor

	return Irradiance
}

SampleRayFromLight :: proc(Scene : scene) -> (ray, v3)
{
	Ray : ray
	Power : v3
	LightColor := v3{15, 15, 15}
	Normal := v3{0, -1, 0}

	Ray.Origin = v3{RandomFloat(213, 343), 554, RandomFloat(227, 332)}

	Basis := CreateBasis(v3{0, -1, 0})
	Ray.Direction = BasisTransform(Basis, RandomCosineDirection())
	CosineTheta := Dot(Normalize(Ray.Direction), Basis.w)
	LightDirPDF := Max(0, CosineTheta / PI)

	LightArea : f32 = (343 - 213) * (332 - 227)
	LightPosPDF := 1 / LightArea
	CosAtten := Max(Dot(Normal, Ray.Direction), 0)

	Power = LightColor * CosAtten / (LightPosPDF * LightDirPDF)

	return Ray, Power
}

CastPhoton :: proc(Map : ^photon_map, InitialRay : ray, InitialPower : v3, Scene : ^scene, MaxPhotonBounces : int)
{
	Throughput := InitialPower
	Ray := InitialRay

	for BounceCount := 0; BounceCount < MaxPhotonBounces; BounceCount += 1
	{
		Record : hit_record

		if GetIntersection(Ray, Scene, &Record)
		{
			SurfaceMaterial := Scene.Materials[Record.MaterialIndex]

			// Store diffuse interaction
			if SurfaceMaterial.Type == .DIFFUSE
			{
				StorePhoton(Map, Record.HitPoint, Throughput, Ray.Direction)
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

			Sample := SampleBxDF(SurfaceMaterial, Ray.Direction, Record)
			CosAtten := Max(Dot(Record.SurfaceNormal, Sample.wi), 0)

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
	_ = InsertNode(Map, Map.Photons[:], 0)
}

InsertNode :: proc(Map : ^photon_map, Photons : []photon, Axis : i32) -> i32
{
	PhotonNode : ^photon_node

	if len(Photons) == 0
	{
		return -1
	}
	else
	{
		slice.sort_by(Photons, SortByAxis[Axis])

		MedianIndex := len(Photons) / 2

		MapIndex := i32(Map.NodeCount)
		Node := &Map.Nodes[Map.NodeCount]
		Map.NodeCount += 1

		Node.PhotonIdx = i32(MedianIndex)
		Node.Axis = Axis

		NewAxis := (Axis + 1) % 3

		Node.Left = InsertNode(Map, Photons[0 : MedianIndex], NewAxis)
		Node.Right = InsertNode(Map, Photons[MedianIndex + 1 : len(Photons)], NewAxis)

		return MapIndex
	}
}

LocatePhotons :: proc(Map : ^photon_map, Pos : v3, MaxDistance : f32) -> nearest_photons
{
	Photons : nearest_photons

	FindPhotons(Map, 0, Pos, MaxDistance, &Photons.PhotonsFound)

	return Photons
}

FindPhotons :: proc(Map : ^photon_map, NodeIndex : i32, Pos : v3, MaxDistance : f32, PhotonsFound : ^[dynamic]^photon) -> int
{
	AddedRes : int = 0

	if NodeIndex == -1
	{
		return 0
	}

	Node := &Map.Nodes[NodeIndex]
	Photon := &Map.Photons[Node.PhotonIdx]

	DistSq := LengthSquared(Photon.Pos - Pos)
	if (DistSq <= MaxDistance * MaxDistance)
	{
		append(PhotonsFound, Photon)

		AddedRes = 1
	}

	dx : f32 = Pos[Node.Axis] - Photon.Pos[Node.Axis]

	Ret := FindPhotons(Map, dx < 0.0 ? Node.Left : Node.Right, Pos, MaxDistance, PhotonsFound)
	if (Ret >= 0 && Abs(dx) < MaxDistance)
	{
		AddedRes += Ret
		Ret = FindPhotons(Map, dx < 0.0 ? Node.Right : Node.Left, Pos, MaxDistance, PhotonsFound)
	}

	AddedRes += Ret

	return AddedRes
}

