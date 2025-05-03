package main

work_order :: struct
{
	Top, Left, Bottom, Right : u32,
};

work_queue :: struct
{
	WorkOrders : [dynamic]work_order,

	World : ^world,
	Image : image_u32,

	NextEntry : u32,
	EntryCount : u32,
	RemainingEntries : u32,
};

PushWorkOrder :: proc(Queue : ^work_queue, Top, Left, Bottom, Right : u32)
{
	Order := work_order{Top, Left, Bottom, Right}

	append(&Queue.WorkOrders, Order)

	Queue.EntryCount += 1
	Queue.RemainingEntries += 1
}

RenderTile :: proc(WorkOrder : work_order, Camera : ^camera, World : ^world, Image : ^image_u32)
{
	for Y := i32(WorkOrder.Top); Y < i32(WorkOrder.Bottom); Y += 1
	{
		for X := i32(WorkOrder.Left); X < i32(WorkOrder.Right); X += 1
		{
			PixelColor : v3
			SamplesPerPixel : u32 = 8

			for Sample : u32 = 0; Sample < SamplesPerPixel; Sample += 1
			{
				Offset := v3{RandomUnilateral() - 0.5, RandomUnilateral() - 0.5, 0}
				PixelCenter := Camera.FirstPixel +
							   ((f32(X) + Offset.x) * Camera.PixelDeltaU) +
							   ((f32(Y) + Offset.y) * Camera.PixelDeltaV)
				Ray : ray

				Ray.Origin = Camera.Center
				Ray.Direction = PixelCenter - Ray.Origin

				PixelColor += CastRay(Ray, World, 10)
			}

			Color := PixelColor / f32(SamplesPerPixel)

			WritePixel(Image^, X, Y, Color)
		}
	}
}


