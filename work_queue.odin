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

