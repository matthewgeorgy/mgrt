package main

import fmt 		"core:fmt"
import os		"core:os"
import linalg	"core:math/linalg"
import libc		"core:c/libc"
import rand		"core:math/rand"
import win32	"core:sys/windows"
import slice	"core:slice"
import pq		"core:container/priority_queue"

v2 :: [2]f32
v3 :: [3]f32
Length :: linalg.length
LengthSquared :: linalg.length2
Abs :: abs
Min :: min
Max :: max

kd_node :: struct
{
	Axis : int,
	Idx : int,
	LeftChildIdx, RightChildIdx : int
}

kd_tree :: struct
{
	Nodes : [dynamic]kd_node,
	Points : [dynamic]v3,
}


SortByX :: proc(Idx1, Idx2 : int) -> bool
{
	Ptr := context.user_ptr
	Tree := (cast(^kd_tree)Ptr)^

	return Tree.Points[Idx1].x < Tree.Points[Idx2].x
}

SortByY :: proc(Idx1, Idx2 : int) -> bool
{
	Ptr := context.user_ptr
	Tree := (cast(^kd_tree)Ptr)^

	return Tree.Points[Idx1].y < Tree.Points[Idx2].y
}

SortByZ :: proc(Idx1, Idx2 : int) -> bool
{
	Ptr := context.user_ptr
	Tree := (cast(^kd_tree)Ptr)^

	return Tree.Points[Idx1].z < Tree.Points[Idx2].z
}

SortByAxis : []proc(int, int)->bool = { SortByX, SortByY, SortByZ }

main :: proc()
{
	Tree : kd_tree
	Foo : int = 20

	// COUNT :: 1000000

	// Tree.Points = make([dynamic]v3, 0, COUNT)

	// for Index := 0; Index < COUNT; Index += 1
	// {
	// 	X : f32 = 500.0 * rand.float32() - 100
	// 	Y : f32 = 500.0 * rand.float32() - 100
	// 	Z : f32 = 500.0 * rand.float32() - 100

	// 	append(&Tree.Points, v3{X, Y, Z})
	// }

	for y := 0; y < 11; y += 1
	{
		for x := 0; x < 11; x += 1
		{
			P := v3{f32(x), f32(y), 0}
			append(&Tree.Points, P)
		}
	}

	StartCounter, EndCounter, Frequency : win32.LARGE_INTEGER

	win32.QueryPerformanceFrequency(&Frequency)

	win32.QueryPerformanceCounter(&StartCounter)
	BuildTree(&Tree)
	win32.QueryPerformanceCounter(&EndCounter)

	ElapsedTime := 1000 * (EndCounter - StartCounter) / Frequency

	fmt.println("Tree construction took", ElapsedTime, "ms for", len(Tree.Nodes), "nodes")

	Target := v3{0, 0, 0}
	k := 8

	win32.QueryPerformanceCounter(&StartCounter)
	SearchResult := SearchKNearest(&Tree, Target, k)
	win32.QueryPerformanceCounter(&EndCounter)
	
	ElapsedTime = 1000000 * (EndCounter - StartCounter) / Frequency
	fmt.println("Tree search took", ElapsedTime, "us")
	fmt.println("-", len(SearchResult.Indices), "nodes")
	fmt.println("-", SearchResult.MaxDist2, "dist2")

	for Index in SearchResult.Indices
	{
		fmt.println(Tree.Points[Index])
	}

	// win32.QueryPerformanceCounter(&StartCounter)
	// Manual := make([]f32, 
	// for Point in Tree.Points
	// {
	// 	if (Length(Point - Target) <= Range)
	// 	{
	// 		Manual += 1
	// 	}
	// }
	// win32.QueryPerformanceCounter(&EndCounter)
	// ElapsedTime = 1000000 * (EndCounter - StartCounter) / Frequency

	// fmt.println("Manual search took", ElapsedTime, "us and found ", Manual, "nodes")

	// for Node in Results.NodesFound
	// {
	// 	Dist := Length(Node.Pos - Target)
	// 	if (Dist > Range)
	// 	{
	// 		fmt.println("ERROR: Node at", Node.Pos, "failed!!!")
	// 	}
	// }
}

BuildTree :: proc(Tree : ^kd_tree)
{
	Indices := make([]int, len(Tree.Points))

	for I := 0; I < len(Indices); I += 1
	{
		Indices[I] = I
	}

	// Need this when looking up points in the sort routines
	context.user_ptr = Tree

	BuildNode(Tree, Indices[:], 0)
}

BuildNode :: proc(Tree : ^kd_tree, Indices : []int, Axis : int)
{
	if len(Indices) == 0
	{
		return
	}

	slice.sort_by(Indices, SortByAxis[Axis])

	Mid := (len(Indices) - 1) / 2

	// Remember parent index before we recurse down
	ParentIdx := len(Tree.Nodes)

	Node := kd_node{ Axis = Axis, Idx = Indices[Mid] }

	append(&Tree.Nodes, Node)

	NewAxis := (Axis + 1) % 3

	// Left children
	LeftChildIdx := len(Tree.Nodes)
	BuildNode(Tree, Indices[0:Mid], NewAxis)

	if LeftChildIdx == len(Tree.Nodes)
	{
		Tree.Nodes[ParentIdx].LeftChildIdx = -1
	}
	else
	{
		Tree.Nodes[ParentIdx].LeftChildIdx = LeftChildIdx
	}

	// Right children
	RightChildIdx := len(Tree.Nodes)
	BuildNode(Tree, Indices[Mid + 1 :], NewAxis)

	if RightChildIdx == len(Tree.Nodes)
	{
		Tree.Nodes[ParentIdx].RightChildIdx = -1
	}
	else
	{
		Tree.Nodes[ParentIdx].RightChildIdx = RightChildIdx
	}
}

knn_pair :: struct
{
	Dist : f32,
	Idx : int,
}

knn_queue :: pq.Priority_Queue(knn_pair)

KNNQueueSort :: proc(A, B : knn_pair) -> bool
{
	return A.Dist > B.Dist
}

KNNQueueSwap :: proc(q : []knn_pair, i, j : int)
{
	Temp := q[i]
	q[i] = q[j]
	q[j] = Temp
}

search_result :: struct
{
	Indices : []int,
	MaxDist2 : f32,
}

SearchKNearest :: proc(Tree : ^kd_tree, QueryPoint : v3, k : int) -> search_result
{
	Result : search_result
	Queue : knn_queue

	pq.init(&Queue, KNNQueueSort, KNNQueueSwap, k)

	SearchKNearestNode(Tree, 0, QueryPoint, k, &Queue)

	Result.Indices = make([]int, pq.len(Queue))

	for I := 0; I < len(Result.Indices); I += 1
	{
		Pair := pq.pop(&Queue)

		Result.Indices[I] = Pair.Idx
		Result.MaxDist2 = Max(Result.MaxDist2, Pair.Dist)

	}

	return Result
}

SearchKNearestNode :: proc(Tree : ^kd_tree, NodeIdx : int, QueryPoint : v3, k : int, Queue : ^knn_queue)
{
	if (NodeIdx == -1) || (NodeIdx >= len(Tree.Nodes))
	{
		return
	}

	Node := Tree.Nodes[NodeIdx]

	Median := Tree.Points[Node.Idx]

	Dist2 := LengthSquared(QueryPoint - Median)
	pq.push(Queue, knn_pair{Dist2, Node.Idx})

	if pq.len(Queue^) > k
	{
		pq.pop(Queue)
	}

	// If query point is below the median along this axis, search left
	// Otherwise, search right
	IsLower := QueryPoint[Node.Axis] < Median[Node.Axis]
	if IsLower
	{
		SearchKNearestNode(Tree, Node.LeftChildIdx, QueryPoint, k, Queue)
	}
	else
	{
		SearchKNearestNode(Tree, Node.RightChildIdx, QueryPoint, k, Queue)
	}

	// At a leaf node, if the queue size is less than k, or the queue's largest
	// min distance overlaps sibling regions, then search the siblings as well
	DistanceToSiblings := Median[Node.Axis] - QueryPoint[Node.Axis]
	Top := pq.peek(Queue^)

	if Top.Dist > DistanceToSiblings * DistanceToSiblings
	{
		if IsLower
		{
			SearchKNearestNode(Tree, Node.RightChildIdx, QueryPoint, k, Queue)
		}
		else
		{
			SearchKNearestNode(Tree, Node.LeftChildIdx, QueryPoint, k, Queue)
		}
	}
}

