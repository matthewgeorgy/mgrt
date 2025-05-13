package main

import fmt		"core:fmt"
import thread	"core:thread"
import win32	"core:sys/windows"
import libc		"core:c/libc"
import strings	"core:strings"

main :: proc()
{
	// Image
	Image := AllocateImage(640, 640)

	// Scene & camera
	Scene : scene
	Camera : camera

	// Scene
	CornellBox(&Scene, &Camera, Image.Width, Image.Height)

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
	// PHOTON_COUNT :: 1000000
	// MaxPhotonBounces := Scene.MaxDepth
	// PhotonMap := CreatePhotonMap(PHOTON_COUNT)

	// win32.QueryPerformanceCounter(&StartCounter)
	// for PhotonIndex := 0; PhotonIndex < PHOTON_COUNT / 4; PhotonIndex += 1
	// {
	// 	Ray, Power := SampleRayFromLight(Scene)

	// 	CastPhoton(&PhotonMap, Ray, Power, &Scene, MaxPhotonBounces)
	// }

	// fmt.println("\nStored", PhotonMap.StoredPhotons, "photons")
	// ScalePhotonPower(&PhotonMap, f32(1.0) / f32(len(PhotonMap.Photons)))
	// BuildPhotonMap(&PhotonMap)

	// Scene.PhotonMap = &PhotonMap

	// win32.QueryPerformanceCounter(&EndCounter)
	// ElapsedTime = (EndCounter - StartCounter) * 1000 / Frequency

	// fmt.println("Photon tracing took", ElapsedTime, "ms\n")

	// Threading
	THREADCOUNT :: 8
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

