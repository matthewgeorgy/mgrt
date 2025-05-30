package main

import fmt      "core:fmt"
import os       "core:os"
import libc     "core:c/libc"
import strings  "core:strings"
import strconv	"core:strconv"

mesh :: struct
{
    Vertices : [dynamic]v3,
    Faces : [dynamic]v3i,
};

LoadMesh :: proc(Filename : string) -> mesh
{
	Mesh : mesh

	Split := strings.split(Filename, ".")
	Extension := Split[len(Split) - 1]

	if Extension == "obj"
	{
		Mesh = LoadMesh_OBJ(Filename)
	}
	else if Extension == "ply"
	{
		Mesh = LoadMesh_PLY(Filename)
	}
	else
	{
		fmt.println("Unrecognized extension in:", Filename)
	}

	return Mesh
}

AssembleTrianglesFromMesh :: proc(Mesh : mesh, Scale : f32 = 1) -> []triangle
{
	Triangles : [dynamic]triangle

	for Face in Mesh.Faces
	{
		V0 := Scale * Mesh.Vertices[Face.x]
		V1 := Scale * Mesh.Vertices[Face.y]
		V2 := Scale * Mesh.Vertices[Face.z]

		Triangle := triangle{ Vertices = {V0, V1, V2} }

		append(&Triangles, Triangle)
	}

	return Triangles[:]
}

GetMeshBoundingBox :: proc(Mesh : mesh, Scale : f32 = 1) -> aabb
{
	BoundingBox : aabb

	BoundingBox.Min = v3{ F32_MAX,  F32_MAX,  F32_MAX}
	BoundingBox.Max = v3{-F32_MAX, -F32_MAX, -F32_MAX}

	for Vertex in Mesh.Vertices
	{
		BoundingBox.Min = MinV3(BoundingBox.Min, Scale * Vertex)
		BoundingBox.Max = MaxV3(BoundingBox.Max, Scale * Vertex)
	}

	return BoundingBox
}

///////////////////////////////////////
// OBJ Loader

LoadMesh_OBJ :: proc(Filename : string) -> mesh
{
    Mesh : mesh

    File, ok := os.read_entire_file(Filename)
	defer delete(File)

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

        for &Face in Mesh.Faces
        {
			Index := MapFaceToIndex(Face, i32(len(Mesh.Vertices)))

			Face.x = Index.x
			Face.y = Index.y
			Face.z = Index.z
        }
    }
    else
    {
        fmt.println("Failed to load", Filename)
    }

    return Mesh
}

MapFaceToIndex :: proc(Face : v3i, Len : i32) -> v3i
{
	Index : v3i

	Index.x = CorrectOBJIndex(Face.x, Len)
	Index.y = CorrectOBJIndex(Face.y, Len)
	Index.z = CorrectOBJIndex(Face.z, Len)

	return Index
}

CorrectOBJIndex :: proc(Index : i32, Len : i32) -> i32
{
	if Index > 0
	{
		return Index - 1
	}
	else
	{
		return Len + Index
	}
}

///////////////////////////////////////
// PLY loader

LoadMesh_PLY :: proc(Filename : string) -> mesh
{
	File := OpenPLYFile(Filename)

	Mesh := ReadPLYData(File)

	ClosePLYFile(File)

	return Mesh
}

///////////////////////////////////////
// PLY impl

ply_type :: enum
{
	NULL = 0,
	INT8,
	INT16,
	INT32,
	UINT8,
	UINT16,
	UINT32,
	FLOAT32,
	FLOAT64,
	LIST,
}

ply_property :: struct
{
	Name : string,			// Property name
	Type : ply_type,		// Type (scalar or list)
	LengthType : ply_type,	// List length type
	ValueType : ply_type,	// List value type
}

ply_element :: struct
{
	Name : string, 						// Element name (vertex or face)
	Count : int, 						// Number of such elements in data section
	Properties : [dynamic]ply_property,	// Corresponding properties
}

ply_format :: enum
{
	ASCII,
	BINARY_BIG_ENDIAN,
	BINARY_LITTLE_ENDIAN,
}

ply_header :: struct
{
	Format : ply_format,
	Elements : [dynamic]ply_element,
}

ply_file :: struct
{
	Header : ply_header,
	Data : []u8,
}

OpenPLYFile :: proc(Filename : string) -> ply_file
{
	File : ply_file

	Data, ok := os.read_entire_file(Filename)
	if !ok
	{
		fmt.println("Failed to open file:", Filename)
		return ply_file{}
	}

	defer delete(Data)

	StringFile := string(Data)

	Idx, Width := strings.index_multi(StringFile, []string{string("end_header")})

	// Jump over newline characters to reach the true start of data segment
	DataSegmentStart := Idx + Width
	for
	{
		C := Data[DataSegmentStart]
		if (C == '\r' || C == '\n')
		{
			DataSegmentStart += 1
		}
		else
		{
			break
		}
	}

	DataSegmentLength := len(Data) - DataSegmentStart

	File.Data = make([]u8, DataSegmentLength)

	copy(File.Data[:], Data[DataSegmentStart : len(Data)])

	// Strip header of comments, etc.

	CurrentElementIndex := 0

	for Line in strings.split_lines_iterator(&StringFile)
   	{
		Tokens := strings.fields(Line)

		if len(Tokens) == 0
		{
			continue
		}

		if strings.compare(Tokens[0], "end_header") == 0
		{
			break
		}
		else if strings.compare(Tokens[0], "format") == 0
		{
			Format := Tokens[1]

			if Format == "ascii"
			{
				File.Header.Format = .ASCII
			}
			else if Format == "binary_big_endian"
			{
				File.Header.Format = .BINARY_BIG_ENDIAN
			}
			else if Format == "binary_little_endian"
			{
				File.Header.Format = .BINARY_LITTLE_ENDIAN
			}
		}
		else if strings.compare(Tokens[0], "element") == 0
		{
			Name := strings.clone(Tokens[1])
			Count := strconv.atoi(Tokens[2])

			append(&File.Header.Elements, ply_element{Name, Count, nil})

			CurrentElementIndex = len(File.Header.Elements) - 1
		}
		else if strings.compare(Tokens[0], "property") == 0
		{
			Property : ply_property

			Property.Type = MapStringToType(Tokens[1])

			if Property.Type == .LIST
			{
				Property.LengthType = MapStringToType(Tokens[2])
				Property.ValueType = MapStringToType(Tokens[3])
				Property.Name = strings.clone(Tokens[4])
			}
			else
			{
				Property.Name = strings.clone(Tokens[2])
			}

			append(&File.Header.Elements[CurrentElementIndex].Properties, Property)
		}
		else
		{
			continue
		}
   	}

	return File
}

ReadPLYData :: proc(File : ply_file) -> mesh
{
	Mesh : mesh

	switch File.Header.Format
	{
		case .ASCII:
		{
			Mesh = ReadPLYData_Ascii(File)
		}
		case .BINARY_LITTLE_ENDIAN:
		{
			Mesh = ReadPLYData_Binary(File)
		}
		case .BINARY_BIG_ENDIAN:
		{
			fmt.println("BIG ENDIAN PLY FILES NOT SUPPORTED")
		}
	}

	return Mesh
}

ReadPLYData_Binary :: proc(File : ply_file) -> mesh
{
	Mesh : mesh

	DataPtr := 0
	for Element in File.Header.Elements
	{
		if Element.Name == "vertex"
		{
			// Repeat for how many of these elements we have
			for ElemIdx := 0; ElemIdx < Element.Count; ElemIdx += 1
			{
				Vertex : v3

				for Property in Element.Properties
				{
					PropertySize := MapTypeToSize(Property.Type)
					Component, Valid := MapNameToComponent(Property.Name)
					if Valid
					{
						Ptr := rawptr(&File.Data[DataPtr])
						Value := (cast(^f32)Ptr)^

						Vertex[Component] = Value
					}

					DataPtr += PropertySize
				}

				append(&Mesh.Vertices, Vertex)
			}
		}
		if Element.Name == "face"
		{
			assert(len(Element.Properties) == 1, "face element with more than one property!")

			Property := Element.Properties[0]
			LengthSize := MapTypeToSize(Property.LengthType)
			ValueSize := MapTypeToSize(Property.ValueType)

			// Repeat for how many of these elements we have
			for ElemIdx := 0; ElemIdx < Element.Count; ElemIdx += 1
			{
				LengthPtr := rawptr(&File.Data[DataPtr])
				DataPtr += LengthSize

				TriangleCount := ReadPtrFromType(LengthPtr, Property.LengthType) - 2

				for Offset := 0; Offset < TriangleCount; Offset += 1
				{
					ValuePtr0 := rawptr(&File.Data[DataPtr])
					ValuePtr1 := rawptr(&File.Data[DataPtr + (Offset + 1) * ValueSize])
					ValuePtr2 := rawptr(&File.Data[DataPtr + (Offset + 2) * ValueSize])

					I0 := i32(ReadPtrFromType(ValuePtr0, Property.ValueType))
					I1 := i32(ReadPtrFromType(ValuePtr1, Property.ValueType))
					I2 := i32(ReadPtrFromType(ValuePtr2, Property.ValueType))

					append(&Mesh.Faces, v3i{I0, I1, I2})
				}

				Offset := (3 + TriangleCount - 1)
				DataPtr += Offset * ValueSize
			}
		}
	}

	return Mesh
}

ReadPLYData_Ascii :: proc(File : ply_file) -> mesh
{
	Mesh : mesh
	StringData := string(File.Data)
	FileData : [dynamic]string

	for Line in strings.split_lines_iterator(&StringData)
	{
		append(&FileData, Line)
	}

	DataIdx := 0
	for Element in File.Header.Elements
	{
		if Element.Name == "vertex"
		{
			// Repeat for how many of these elements we have
			for ElemIdx := 0; ElemIdx < Element.Count; ElemIdx += 1
			{
				// Grab line of data
				Line := strings.fields(FileData[DataIdx])

				// Add data according to the properties
				Vertex : v3
				for Property, ValueIdx in Element.Properties
				{
					if Property.Type == .FLOAT32
					{
						Value := f32(strconv.atof(Line[ValueIdx]))
						Vertex[ValueIdx] = Value
					}
				}

				// Append and move to next data line
				append(&Mesh.Vertices, Vertex)
				DataIdx += 1
			}
		}
		else if Element.Name == "face"
		{
			for ElemIdx := 0; ElemIdx < Element.Count; ElemIdx += 1
			{
				// Grab line of data
				Line := strings.fields(FileData[DataIdx])
				FaceValues := Line[1 : len(Line)]

				TriangleCount := strconv.atoi(Line[0]) - 2

				for Offset := 0; Offset < TriangleCount; Offset += 1
				{
					I0 := i32(strconv.atoi(FaceValues[0]))
					I1 := i32(strconv.atoi(FaceValues[Offset + 1]))
					I2 := i32(strconv.atoi(FaceValues[Offset + 2]))

					append(&Mesh.Faces, v3i{I0, I1, I2})
				}

				DataIdx += 1
			}
		}
	}

	return Mesh
}

ClosePLYFile :: proc(File : ply_file)
{
	for Element in File.Header.Elements
	{
		delete(Element.Properties)
		delete(Element.Name)
	}

	delete(File.Header.Elements)

	delete(File.Data)
}

MapStringToType :: proc(StringType : string) -> ply_type
{
	Type : ply_type

	switch StringType
	{
		case "int8", "char":
		{
			return .INT8
		}
		case "int16", "short":
		{
			return .INT16
		}
		case "int32", "int":
		{
			return .INT32
		}
		case "uint8", "uchar":
		{
			return .UINT8
		}
		case "uint16", "ushort":
		{
			return .UINT16
		}
		case "uint32", "uint":
		{
			return .UINT32
		}
		case "float32", "float":
		{
			return .FLOAT32
		}
		case "float64", "double":
		{
			return .FLOAT64
		}
		case "list":
		{
			return .LIST
		}
	}

	return Type
}

MapTypeToSize :: proc(Type : ply_type) -> int
{
	Size : int

	switch Type
	{
		case .NULL, .LIST:
		{
			Size = 0
		}
		case .INT8, .UINT8:
		{
			Size = 1
		}
		case .INT16, .UINT16:
		{
			Size = 2
		}
		case .INT32, .UINT32, .FLOAT32:
		{
			Size = 4
		}
		case .FLOAT64:
		{
			Size = 8
		}
	}

	return Size
}

MapNameToComponent :: proc(Name : string) -> (int, bool)
{
	Index : int
	Valid := true

	if Name == "x"
	{
		Index = 0
	}
	else if Name == "y"
	{
		Index = 1
	}
	else if Name == "z"
	{
		Index = 2
	}
	else
	{
		Valid = false
	}

	return Index, Valid
}

ReadPtrFromType :: proc(Ptr : rawptr, Type : ply_type) -> int
{
	Value : int

	switch Type
	{
		case .INT8:
		{
			Length := (cast(^i8)Ptr)^
			Value = int(Length)
		}
		case .INT16:
		{
			Length := (cast(^i16)Ptr)^
			Value = int(Length)
		}
		case .INT32:
		{
			Length := (cast(^i32)Ptr)^
			Value = int(Length)
		}
		case .UINT8:
		{
			Length := (cast(^u8)Ptr)^
			Value = int(Length)
		}
		case .UINT16:
		{
			Length := (cast(^u16)Ptr)^
			Value = int(Length)
		}
		case .UINT32:
		{
			Length := (cast(^u32)Ptr)^
			Value = int(Length)
		}
		case .FLOAT32:
		{
			Length := (cast(^f32)Ptr)^
			Value = int(Length)
		}
		case .FLOAT64:
		{
			Length := (cast(^f64)Ptr)^
			Value = int(Length)
		}
		case .NULL, .LIST:
		{
			fmt.println("READING PTR FROM A NULL OR LIST")
		}
	}

	return Value
}

