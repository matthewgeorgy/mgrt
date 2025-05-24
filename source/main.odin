package main

/*
	TODO(matthew): Things to add:
	- Disney BRDF
	- NEE
	- MIS
	- Bidirectional path tracing
	- IBL / environment lighting
	- Path guiding techniques
	- Scene file format that can be loaded at run-time
	- Reduce Fresnel reflectancen noise with photon mapping

	NOTE(matthew): Currently supporting:
	- Standard backwards path tracing integrator
	- Basic lambertian, metal, and glass BRDFs
	- Oren-Nayar BRDF
	- Photon mapping with both diffuse and specular
	- Measured BRDF data (MERL)
	- Triangle meshes (OBJ, PLY) + BVH
	- Tiled multithreaded rendering
*/

import fmt		"core:fmt"
import thread	"core:thread"
import win32	"core:sys/windows"
import libc		"core:c/libc"
import strings	"core:strings"

when ODIN_DEBUG == true
{
	THREADCOUNT :: 1
}
else
{
	THREADCOUNT :: 8
}

main :: proc()
{
	// Initialize scene, camera, and image from command line args
	Config : config
	if !ParseCommandLine(&Config)
	{
		return
	}

	Scene, Camera, Image := InitializeFromConfig(Config)

	// Work queue
	Queue : work_queue

	TilesX : u32 = 20
	TilesY : u32 = 20
	TileWidth : u32 = u32(Image.Width) / TilesX
	TileHeight : u32 = u32(Image.Height) / TilesY

	for X : u32 = 0; X < TilesX; X += 1
	{
		for Y : u32 = 0; Y < TilesY; Y += 1
		{
			Top := TileHeight * Y
			Left := TileWidth * X
			Bottom := TileHeight * (Y + 1)
			Right := TileWidth * (X + 1)

			PushWorkOrder(&Queue, Top, Left, Bottom, Right)
		}
	}

	// Counters & stats
	StartCounter, EndCounter, Frequency, ElapsedTime: win32.LARGE_INTEGER

	libc.printf("Resolution: %dx%d\n", Image.Width, Image.Height)
	libc.printf("%d cores with %d %dx%d (%dk/tile) tiles\n", THREADCOUNT, Queue.EntryCount, TileWidth, TileHeight, TileWidth * TileHeight * 4 / 1024)
	libc.printf("Quality: %u samples/pixel, %d bounces (max) per ray\n", Scene.SamplesPerPixel, Scene.MaxDepth)

	win32.QueryPerformanceFrequency(&Frequency)

	// Photon map
	MaxGlobalPhotonCount :: 5000000
	MaxCausticPhotonCount :: 5000000
	GlobalPhotonMap := CreatePhotonMap(MaxGlobalPhotonCount)
	CausticPhotonMap := CreatePhotonMap(MaxGlobalPhotonCount)

	// Global
	win32.QueryPerformanceCounter(&StartCounter)
	BuildGlobalPhotonMap(&GlobalPhotonMap, &Scene)
	win32.QueryPerformanceCounter(&EndCounter)
	Scene.GlobalPhotonMap = &GlobalPhotonMap
	ElapsedTime = (EndCounter - StartCounter) * 1000 / Frequency
	fmt.println("Global photon tracing took", ElapsedTime, "ms\n")

	// Caustic
	win32.QueryPerformanceCounter(&StartCounter)
	BuildCausticPhotonMap(&CausticPhotonMap, &Scene)
	win32.QueryPerformanceCounter(&EndCounter)
	Scene.CausticPhotonMap = &CausticPhotonMap
	ElapsedTime = (EndCounter - StartCounter) * 1000 / Frequency
	fmt.println("Caustic photon tracing took", ElapsedTime, "ms\n")

	fmt.println("Global photon map nodes", len(GlobalPhotonMap.Nodes))
	fmt.println("Caustic photon map nodes", len(CausticPhotonMap.Nodes))

	// Threading
	ThreadData : thread_data
	Threads : [THREADCOUNT]^thread.Thread

	ThreadData.Queue = &Queue
	ThreadData.Camera = &Camera
	ThreadData.Scene = &Scene
	ThreadData.Image = &Image

	win32.QueryPerformanceCounter(&StartCounter)

	for I := 0; I < THREADCOUNT; I += 1
	{
		Threads[I] = thread.create_and_start_with_data(&ThreadData, Render)
	}

	thread.join_multiple(..Threads[:])

	win32.QueryPerformanceCounter(&EndCounter)

	ElapsedTime = (EndCounter - StartCounter) * 1000

	fmt.println(" Render took", ElapsedTime / Frequency, "ms")

	WriteImage(Image, string("test.bmp"))
}

