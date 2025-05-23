package main

import fmt		"core:fmt"
import math		"core:math"
import linalg	"core:math/linalg"
import rand		"core:math/rand"

v2f	:: [2]f32
v2i :: [2]i32
v2u :: [2]u32
v2 	:: v2f

v3f	:: [3]f32
v3i :: [3]i32
v3u :: [3]u32
v3 	:: v3f

triangle :: struct
{
	Vertices : [3]v3,
}

