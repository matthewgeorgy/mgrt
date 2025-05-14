package main

import os		"core:os"
import fmt		"core:fmt"
import strconv	"core:strconv"
import strings	"core:strings"

SCENE_NAMES :: []string {
	"CornellBunny",
	"GlassSuzanne",
	"SpheresMaterial",
	"BunnyPlaneLamp",
	"CornellBox",
}

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

	if len(Args) != 3
	{
		fmt.println("\nUsage: [SceneName] [SamplesPerPixel] [MaxDepth]")
		fmt.println("Available scenes:")
		for SceneName in SCENE_NAMES
		{
			fmt.println("    ", SceneName)
		}

		return false
	}

	GivenSceneName := Args[0]

	for SceneName, Index in SCENE_NAMES
	{
		if strings.compare(SceneName, GivenSceneName) == 0
		{
			Config.SceneIndex = Index 
			break
		}
	}

	Config.SamplesPerPixel = u32(strconv.atoi(Args[1]))
	Config.MaxDepth = strconv.atoi(Args[2])

	return true
}

InitializeFromConfig :: proc(Config : config) -> (scene, camera)
{
	Scene : scene
	Camera : camera

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
	}

	Scene.SamplesPerPixel = Config.SamplesPerPixel
	Scene.MaxDepth = Config.MaxDepth

	return Scene, Camera
}

