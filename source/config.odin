package main

import os		"core:os"
import fmt		"core:fmt"
import strconv	"core:strconv"
import strings	"core:strings"

config :: struct
{
	SceneIndex 	: int,
	SamplesPerPixel	: u32,
	MaxDepth : int,
	ImageWidth, ImageHeight : i32,
}

ParseCommandLine :: proc(Config : ^config) -> bool
{
	Args := os.args[1:]

	if len(Args) != 5
	{
		fmt.println("\nUsage: [SceneName] [ImageWidth] [ImageHeight] [SamplesPerPixel] [MaxDepth]")
		fmt.println("Available scenes:")
		for SceneName in SCENE_NAMES
		{
			fmt.println("    ", SceneName)
		}

		return false
	}

	GivenSceneName := Args[0]
	SceneFound := false

	for SceneName, Index in SCENE_NAMES
	{
		if strings.compare(SceneName, GivenSceneName) == 0
		{
			SceneFound = true
			Config.SceneIndex = Index 

			break
		}
	}

	if !SceneFound
	{
		fmt.println("INVALID SCENE SPECIFIED")
		os.exit(-1)
	}

	Config.ImageWidth = i32(strconv.atoi(Args[1]))
	Config.ImageHeight = i32(strconv.atoi(Args[2]))
	Config.SamplesPerPixel = u32(strconv.atoi(Args[3]))
	Config.MaxDepth = strconv.atoi(Args[4])

	return true
}

InitializeFromConfig :: proc(Config : config) -> (scene, camera, image_u32)
{
	Scene : scene
	Camera : camera
	Image : image_u32

	Image = AllocateImage(Config.ImageWidth, Config.ImageHeight)

	switch Config.SceneIndex
	{
		case 0:
		{
			CornellBunny(&Scene, &Camera, Config.ImageWidth, Config.ImageHeight)
		}
		case 1:
		{
			GlassSuzanne(&Scene, &Camera, Config.ImageWidth, Config.ImageHeight)
		}
		case 2:
		{
			SpheresMaterial(&Scene, &Camera, Config.ImageWidth, Config.ImageHeight)
		}
		case 3:
		{
			BunnyPlaneLamp(&Scene, &Camera, Config.ImageWidth, Config.ImageHeight)
		}
		case 4:
		{
			CornellBox(&Scene, &Camera, Config.ImageWidth, Config.ImageHeight)
		}
		case 5:
		{
			CornellSphere(&Scene, &Camera, Config.ImageWidth, Config.ImageHeight)
		}
		case 6:
		{
			FinalSceneRTW(&Scene, &Camera, Config.ImageWidth, Config.ImageHeight)
		}
		case 7:
		{
			PlaneDragon(&Scene, &Camera, Config.ImageWidth, Config.ImageHeight)
		}
		case 8:
		{
			CornellDragon(&Scene, &Camera, Config.ImageWidth, Config.ImageHeight)
		}
		case 9:
		{
			CornellPLY(&Scene, &Camera, Config.ImageWidth, Config.ImageHeight)
		}
	}

	Scene.SamplesPerPixel = Config.SamplesPerPixel
	Scene.MaxDepth = Config.MaxDepth

	GatherLightIndices(&Scene)

	return Scene, Camera, Image
}

