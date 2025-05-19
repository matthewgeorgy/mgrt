package main

/*
	TODO(matthew): Things to add:
	- Oren-Nayar BRDF
	- Disney BRDF
	- NEE
	- MIS 
	- Bidirectional path tracing
	- IBL / environment lighting 
	- Path guiding techniques
	- Improve our basis construction & usage, mostly for MERL
	- Support for photon map with caustics and specular surfaces
	- Scene file format that can be loaded at run-time
	- Extend the OBJ reader to support the dragon mesh

	NOTE(matthew): Currently supporting:
	- Standard backwards path tracing integrator
	- Basic lambertian, metal, and glass BRDFs
	- Photon mapping with diffuse only
	- Measured BRDF data (MERL)
	- Triangle meshes + BVH
	- Tiled multithreaded rendering
*/

import fmt		"core:fmt"
import thread	"core:thread"
import win32	"core:sys/windows"
import libc		"core:c/libc"
import strings	"core:strings"

main :: proc()
{
	// Image
	Image := AllocateImage(640, 640)

	// Initialize scene and camera from command line args
	Config : config
	if !ParseCommandLine(&Config)
	{
		return
	}

	Config.ImageWidth = Image.Width
	Config.ImageHeight = Image.Height


	Scene, Camera := InitializeFromConfig(Config)

	// Work queue
	Queue : work_queue

	TilesX : u32 = 16
	TilesY : u32 = 16
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
	// EmittedPhotons ::  100000
	// MaxPhotonCount :: 5000000
	// MaxPhotonBounces := Scene.MaxDepth
	// PhotonMap := CreatePhotonMap(MaxPhotonCount)

	// win32.QueryPerformanceCounter(&StartCounter)
	// for PhotonIndex := 0; PhotonIndex < EmittedPhotons; PhotonIndex += 1
	// {
	// 	Ray, Power := SampleRayFromLight(&Scene)

	// 	CastPhoton(&PhotonMap, Ray, Power, &Scene, MaxPhotonBounces)
	// }

	// fmt.println("\nStored", PhotonMap.StoredPhotons, "photons")
	// ScalePhotonPower(&PhotonMap, f32(1.0) / f32(EmittedPhotons))
	// BuildPhotonMap(&PhotonMap)

	// Scene.PhotonMap = &PhotonMap

	// win32.QueryPerformanceCounter(&EndCounter)
	// ElapsedTime = (EndCounter - StartCounter) * 1000 / Frequency

	// fmt.println("Photon tracing took", ElapsedTime, "ms\n")

	// Threading
	when ODIN_DEBUG == true
	{
		THREADCOUNT :: 8
	}
	else
	{
		THREADCOUNT :: 1
	}
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

