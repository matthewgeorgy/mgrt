package main

/*
    TODO(matthew): Things to add:
    - Disney BRDF
    - NEE + MIS
    - Bidirectional path tracing
    - IBL / environment lighting
    - Path guiding techniques
    - Reduce Fresnel reflectance noise with photon mapping
	- Support for rendering multiple meshes
	- Support for randomly sampling multiple light sources (for photon mapping
	  and other future integrators that will need it)

    NOTE(matthew): Currently supporting:
	* Integrators:
		- Backward path-tracing
		- Photon mapping (diffuse + specular)
	* BxDFs / Materials:
		- Lambertian
		- Metal
		- Dielectric
		- Oren-Nayar
		- MERL
	* Geometry:
		- Sphere
		- Quad
		- Plane
		- Triangle
		- Box
		- Triangle mesh (OBJ, PLY) + BVH
	* Tiled multithreaded rendering
	* Custom scene parser
*/

import fmt      "core:fmt"
import thread   "core:thread"
import win32    "core:sys/windows"
import libc     "core:c/libc"
import strings  "core:strings"
import os		"core:os"

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
	Args := os.args

	if len(Args) != 3
	{
		fmt.println("Usage: mgrt.exe [input scene file] [output filename]")
		fmt.println("    The input must be a .mgrt scene file")
		fmt.println("    The output must be a .bmp image file")

		return
	}

	SceneFilename := os.args[1]
	OutputFilename := os.args[2]

	Camera, Image, Scene := ParseScene(SceneFilename)

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
    libc.printf("Quality: %u samples/pixel, %d bounces (max) per ray\n", Camera.SamplesPerPixel, Camera.MaxDepth)

    win32.QueryPerformanceFrequency(&Frequency)

    //// Photon map
    //MaxGlobalPhotonCount :: 5000000
    //MaxCausticPhotonCount :: 5000000
    //GlobalPhotonMap := CreatePhotonMap(MaxGlobalPhotonCount)
    //CausticPhotonMap := CreatePhotonMap(MaxGlobalPhotonCount)

    ////Global map
    //win32.QueryPerformanceCounter(&StartCounter)
    //BuildGlobalPhotonMap(&GlobalPhotonMap, &Scene, Camera.MaxDepth)
    //win32.QueryPerformanceCounter(&EndCounter)
    //Scene.GlobalPhotonMap = &GlobalPhotonMap
    //ElapsedTime = (EndCounter - StartCounter) * 1000 / Frequency
    //fmt.println("Global photon tracing took", ElapsedTime, "ms\n")

    //// Caustic map
    //win32.QueryPerformanceCounter(&StartCounter)
    //BuildCausticPhotonMap(&CausticPhotonMap, &Scene, Camera.MaxDepth)
    //win32.QueryPerformanceCounter(&EndCounter)
    //Scene.CausticPhotonMap = &CausticPhotonMap
    //ElapsedTime = (EndCounter - StartCounter) * 1000 / Frequency
    //fmt.println("Caustic photon tracing took", ElapsedTime, "ms\n")

    //fmt.println("Global photon map nodes", len(GlobalPhotonMap.Nodes))
    //fmt.println("Caustic photon map nodes", len(CausticPhotonMap.Nodes))

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

    WriteImage(Image, OutputFilename)
}

