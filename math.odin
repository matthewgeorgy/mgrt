package main

import "core:math/linalg"

v3f	:: [3]f32
v3i :: [3]i32
v3u :: [3]u32
v3 	:: v3f

Cross 			:: linalg.cross
Dot 			:: linalg.dot
Normalize 		:: linalg.normalize
Length 			:: linalg.length
LengthSquared	:: linalg.length2
SquareRoot 		:: linalg.sqrt
Abs 			:: abs
Min 			:: min
Max 			:: max

F32_MAX 		:: 3.402823466e+38

ray :: struct
{
	Origin : v3,
	Direction : v3,
};

sphere :: struct
{
	Center : v3,
	Radius : f32,
};

