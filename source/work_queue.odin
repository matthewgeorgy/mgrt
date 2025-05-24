package main

import fmt			"core:fmt"
import sync			"core:sync"
import intrinsics	"base:intrinsics"
import libc			"core:c/libc"

work_order :: struct
{
	Top, Left, Bottom, Right : u32,
};

work_queue :: struct
{
	WorkOrders : [dynamic]work_order,

	Scene : ^scene,
	Image : image_u32,

	// NOTE(matthew): These are treated as volatile!
	NextEntry : i32,
	EntryCount : i32,
	RemainingOrders : i32,
};

thread_data :: struct
{
	Queue : ^work_queue,
	Camera : ^camera,
	Scene : ^scene,
	Image : ^image_u32,
};

PushWorkOrder :: proc(Queue : ^work_queue, Top, Left, Bottom, Right : u32)
{
	Order := work_order{Top, Left, Bottom, Right}

	append(&Queue.WorkOrders, Order)

	Queue.EntryCount += 1
	Queue.RemainingOrders += 1
}

Render :: proc (Param : rawptr)
{
	ThreadData : ^thread_data = cast(^thread_data)Param

	Queue := ThreadData.Queue
	Camera := ThreadData.Camera
	Scene := ThreadData.Scene
	Image := ThreadData.Image

	for
	{
		NextEntry := intrinsics.volatile_load(&Queue.NextEntry)
		EntryCount := intrinsics.volatile_load(&Queue.EntryCount)

		if NextEntry < EntryCount
		{
			EntryIndex := sync.atomic_add(&NextEntry, 1)
			intrinsics.volatile_store(&Queue.NextEntry, NextEntry)

			Order := Queue.WorkOrders[EntryIndex]

			RenderTile(Order, Camera, Scene, Image)

			RemainingOrders := intrinsics.volatile_load(&Queue.RemainingOrders)

			sync.atomic_sub(&RemainingOrders, 1)
			intrinsics.volatile_store(&Queue.RemainingOrders, RemainingOrders)

			libc.fprintf(libc.stderr, "\rRaycasting %u%%...", 100 * u32(Queue.EntryCount - Queue.RemainingOrders) / u32(Queue.EntryCount));
			libc.fflush(libc.stdout)
		}
		else
		{
			break
		}
	}
}

RenderTile :: proc(WorkOrder : work_order, Camera : ^camera, Scene : ^scene, Image : ^image_u32)
{
	for Y := i32(WorkOrder.Top); Y < i32(WorkOrder.Bottom); Y += 1
	{
		for X := i32(WorkOrder.Left); X < i32(WorkOrder.Right); X += 1
		{
			PixelColor : v3

			for Sample : u32 = 0; Sample < Scene.SamplesPerPixel; Sample += 1
			{
				Offset := v3{RandomUnilateral() - 0.5, RandomUnilateral() - 0.5, 0}
				PixelCenter := Camera.FirstPixel +
							   ((f32(X) + Offset.x) * Camera.PixelDeltaU) +
							   ((f32(Y) + Offset.y) * Camera.PixelDeltaV)
				Ray : ray

				Ray.Origin = Camera.Center
				Ray.Direction = PixelCenter - Ray.Origin

				PixelColor += PhotonMapIntegrator(Ray, Scene, 0)
			}

			Color := PixelColor / f32(Scene.SamplesPerPixel)

			WritePixel(Image^, X, Y, Color)
		}
	}
}

