package main

import fmt      "core:fmt"
import os       "core:os"
import libc     "core:c/libc"
import strings  "core:strings"

mesh :: struct
{
    Vertices : [dynamic]v3,
    Normals : [dynamic]v3,
    Faces : [dynamic]v3i,
    Triangles : [dynamic]triangle,
};

LoadMesh :: proc(Filename : string, Scale : f32 = 1) -> mesh
{
    Mesh : mesh

    File, ok := os.read_entire_file(Filename)
    if ok
    {
        StringFile := string(File)

        for Line in strings.split_lines_iterator(&StringFile)
        {
			Trimmed := strings.trim(Line, " ")

            Tokens := strings.fields(Trimmed)

			// This was just a blank line, skip to the next line
			if len(Tokens) == 0
			{
				continue
			}

            Header := Tokens[0]
            Components := Tokens[1 : len(Tokens)]

            if strings.compare(Header, "v") == 0 // Vertex
            {

                V0 := f32(libc.atof(strings.clone_to_cstring(Components[0])))
                V1 := f32(libc.atof(strings.clone_to_cstring(Components[1])))
                V2 := f32(libc.atof(strings.clone_to_cstring(Components[2])))

                append(&Mesh.Vertices, v3{V0, V1, V2})
            }
            else if strings.compare(Header, "f") == 0 // Face
            {
                if len(Components) == 3
                {
                    Point0 := strings.split(Components[0], "/")
                    Point1 := strings.split(Components[1], "/")
                    Point2 := strings.split(Components[2], "/")

                    I0 := libc.atoi(strings.clone_to_cstring(Point0[0]))
                    I1 := libc.atoi(strings.clone_to_cstring(Point1[0]))
                    I2 := libc.atoi(strings.clone_to_cstring(Point2[0]))

                    append(&Mesh.Faces, v3i{I0, I1, I2})
                }
                else if len(Components) == 4
                {
                    Point0 := strings.split(Components[0], "/")
                    Point1 := strings.split(Components[1], "/")
                    Point2 := strings.split(Components[2], "/")
                    Point3 := strings.split(Components[3], "/")

                    I0 := libc.atoi(strings.clone_to_cstring(Point0[0]))
                    I1 := libc.atoi(strings.clone_to_cstring(Point1[0]))
                    I2 := libc.atoi(strings.clone_to_cstring(Point2[0]))
                    I3 := libc.atoi(strings.clone_to_cstring(Point3[0]))

                    append(&Mesh.Faces, v3i{I0, I1, I2})
                    append(&Mesh.Faces, v3i{I0, I2, I3})
                }
            }
        }

        for Face in Mesh.Faces
        {
            V0 := Mesh.Vertices[Face.x - 1] * Scale
            V1 := Mesh.Vertices[Face.y - 1] * Scale
            V2 := Mesh.Vertices[Face.z - 1] * Scale

            Triangle := triangle{ Vertices = {V0, V1, V2}}

            append(&Mesh.Triangles, Triangle)
        }
    }
    else
    {
        fmt.println("Failed to load", Filename)
    }

    return Mesh
}

