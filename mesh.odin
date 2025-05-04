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

LoadMesh :: proc(Filename : string) -> mesh
{
    Mesh : mesh

    File, ok := os.read_entire_file(Filename)
    if ok
    {
        StringFile := string(File)

        for Line in strings.split_lines_iterator(&StringFile)
        {
            Tokens := strings.split(strings.trim_right(Line, " "), " ")

            Header := Tokens[0]
            Parts := Tokens[1 : len(Tokens)]

			Components : [dynamic]string

			// TODO(matthew): bullet proof this somehow...
			// Things breaks without this if we havve leading whitespace before
			// the components, eg:
			// v 1.000 2.000 3.000		This works
			// v  1.000 2.000 3.000		This doesn't!
			for Part in Parts
			{
				if len(Part) != 0
				{
					append(&Components, Part)
				}
			}

            if strings.compare(Header, "v") == 0 // Vertex
            {
                V0 := f32(libc.atof(strings.clone_to_cstring(Components[0])))
                V1 := f32(libc.atof(strings.clone_to_cstring(Components[1])))
                V2 := f32(libc.atof(strings.clone_to_cstring(Components[2])))

                append(&Mesh.Vertices, v3{V0, V1, V2})
            }
            else if strings.compare(Header, "vn") == 0 // Normal
            {
                N0 := f32(libc.atof(strings.clone_to_cstring(Components[0])))
                N1 := f32(libc.atof(strings.clone_to_cstring(Components[1])))
                N2 := f32(libc.atof(strings.clone_to_cstring(Components[2])))

                append(&Mesh.Normals, v3{N0, N1, N2})
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
            V0 := Mesh.Vertices[Face.x - 1]
            V1 := Mesh.Vertices[Face.y - 1]
            V2 := Mesh.Vertices[Face.z - 1]

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

