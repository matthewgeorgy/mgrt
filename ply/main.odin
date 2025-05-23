package main

import fmt		"core:fmt"
import os      	"core:os"
import libc    	"core:c/libc"
import strings	"core:strings"
import strconv	"core:strconv"

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
	Data : [dynamic]string
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

	// Strip header of comments, etc.
	StringFile := string(Data)
	StrippedHeader : [dynamic]string
	Format : string

	ParsingHeader := true
	for Line in strings.split_lines_iterator(&StringFile)
   	{
		Tokens := strings.fields(Line)

		if len(Tokens) == 0
		{
			continue
		}

		if ParsingHeader
		{
			if strings.compare(Tokens[0], "end_header") == 0
			{
				ParsingHeader = false
			}
			else if strings.compare(Tokens[0], "format") == 0
			{
				Format = Tokens[1]
				if Format == "ascii"
				{
					File.Header.Format = .ASCII
				}
				else if Format == "binary_big_endian"
				{
					File.Header.Format = .BINARY_BIG_ENDIAN
				}
				else if Format == "little_big_endian"
				{
					File.Header.Format = .BINARY_LITTLE_ENDIAN
				}
			}
			else if (strings.compare(Tokens[0], "element") == 0) ||
					(strings.compare(Tokens[0], "property") == 0)
			{
				append(&StrippedHeader, Line)
			}
			else
			{
				continue
			}
		}
		else
		{
			append(&File.Data, Line)
		}
   	}

	CurrentElementIndex := 0

	for Entry in StrippedHeader
	{
		Tokens := strings.fields(Entry)

		if strings.compare(Tokens[0], "element") == 0
		{
			Name := Tokens[1]
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
				Property.Name = Tokens[4]
			}
			else
			{
				Property.Name = Tokens[2]
			}

			append(&File.Header.Elements[CurrentElementIndex].Properties, Property)
		}
		else
		{
			fmt.println("ERROR: UNRECOGNIZED FIELD TYPE", Tokens[0])
		}
	}

	return File
}

main :: proc()
{
	Filename := string("assets/ply/test.ply")
	File := OpenPLYFile(Filename)

	for Elem in File.Header.Elements
	{
		fmt.println(Elem.Name, Elem.Count)

		for Prop in Elem.Properties
		{
			fmt.println("    ", Prop)
		}

		fmt.println()
	}

	DataIdx := 0
	Vertices : [dynamic]v3
	Faces : [dynamic]v3i

	for Element in File.Header.Elements
	{
		if Element.Name == "vertex"
		{
			// Repeat for how many of these elements we have
			for ElemIdx := 0; ElemIdx < Element.Count; ElemIdx += 1
			{
				// Grab line of data
				Line := strings.fields(File.Data[DataIdx])

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
				append(&Vertices, Vertex)
				DataIdx += 1
			}
		}
		else if Element.Name == "face"
		{
			for ElemIdx := 0; ElemIdx < Element.Count; ElemIdx += 1
			{
				// Grab line of data
				Line := strings.fields(File.Data[DataIdx])
				FaceValues := Line[1 : len(Line)]

				TriangleCount := strconv.atoi(Line[0])

				for Offset := 0; Offset < TriangleCount - 2; Offset += 1
				{
					I0 := i32(strconv.atoi(FaceValues[0]))
					I1 := i32(strconv.atoi(FaceValues[Offset + 1]))
					I2 := i32(strconv.atoi(FaceValues[Offset + 2]))

					append(&Faces, v3i{I0, I1, I2})
				}

				DataIdx += 1
			}
		}
	}
	
	fmt.println("Vertices:")
	for V in Vertices
	{
		fmt.println(V)
	}

	fmt.println("\nFaces:")
	for F in Faces
	{
		fmt.println(F)
	}

	// for Line in File.Data
	// {
	// 	fmt.println(Line)
	// }
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

