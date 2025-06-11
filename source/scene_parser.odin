package main

import fmt 		"core:fmt"
import os 		"core:os"
import strings 	"core:strings"
import strconv	"core:strconv"

/* General config hierarchy

* Scene :
    - Materials
        - Lambertian
        - Metal
        - Dielectric
        - MERL
        - OrenNayar
    - Lights
    - Primitives
        - Shape
            - Sphere
            - Quad
            - Plane
            - Triangle
            - AABB
            - Box (not actually a shape, array of 6 quads)
        - MaterialIndex
        - LightIndex

* Camera :
    - LookFrom
    - LookAt
    - FocusDist
    - FOV
    - Samples per pixel
    - Max depth

* Image :
    - Width
    - Height


Will probably do something like this:

At the start, specify all lights, materials, and shapes each in their own array:
    Lights : [dynamic]light
    Materials : [dynamic]material
    Shapes : [dynamic]shape

We will specify a resource by its name as a string, followed by a description.

When one is created, we add it to its array, and store its index and name in a map:
    MaterialTable : map[string]int

    Material : material = ...
    append(&Materials, Material)
    Index := len(Materials) - 1

    Name := ... specified in the file

    MaterialTable[Name] = MaterialIndex

When we then go to specify primitives, all they will take is the name used in
the file. We will then look up these names to get the internal index, and then
fill out the primitive data struct accordingly.
*/

error :: struct
{
	Message : string,
	LineNumber : int,
}

parser :: struct
{
	Lines : []string,
	CurrentLine : string,
	CurrentLineNumber : int,

	Errors : [dynamic]error,

	Shapes : [dynamic]shape,
	ShapeTable : map[string]int,
}

main :: proc()
{
	Filename := string("test.mgrt")
	
	File, ok := os.read_entire_file(Filename)
	defer delete(File)

	Lines : [dynamic]string

	if ok
	{
		StringFile := string(File)

		for Line in strings.split_lines_iterator(&StringFile)
		{
			Trimmed := strings.trim(Line, " ")
			Trimmed = strings.trim(Trimmed, "\t")

			if len(Trimmed) != 0
			{
				append(&Lines, Trimmed)
			}
		}
	}

	Parser := parser {
		Lines = Lines[:],
	}

	ParseFile(&Parser)

	for Shape in Parser.Shapes
	{
		fmt.println("    ", Shape)
	}

	fmt.println(Parser.ShapeTable)
}

ParseFile :: proc(Parser : ^parser)
{
    Camera : camera

    for NextLine(Parser)
    {
        Tokens := strings.fields(Parser.CurrentLine)

        if Tokens[0] == "BeginCamera"
        {
			if len(Tokens) == 1
			{
            	Camera = ParseCamera(Parser)
			}
			else
			{
				ReportError(Parser, "ERROR: Too many symbols, BeginCamera is a standalone keyword")
			}
        }

		if Tokens[0] == "BeginShape"
		{
			if len(Tokens) == 2
			{
				ShapeName := Tokens[1]
				Shape := ParseShape(Parser)

				append(&Parser.Shapes, Shape)

				// TODO(matthew): report error here if two shapes have the same name
				Parser.ShapeTable[ShapeName] = len(Parser.Shapes) - 1
			}
			else
			{
				ReportError(Parser, "ERROR: invalid syntax, BeginShape takes a single name")
			}
		}
    }

    fmt.println(Camera)
}

ParseCamera :: proc(Parser : ^parser) -> camera
{
	Camera : camera

    for NextLine(Parser)
    {
		Tokens := strings.fields(Parser.CurrentLine)

        if Tokens[0] == "EndCamera"
        {
            break
        }

        if Tokens[0] == "LookFrom"
        {
			Camera.LookFrom = ReadV3(Parser, Tokens[1:], "LookFrom")
		}
        else if Tokens[0] == "LookAt"
        {
			Camera.LookAt = ReadV3(Parser, Tokens[1:], "LookAt")
		}
        else if Tokens[0] == "FocusDist"
        {
			Camera.FocusDist = ReadF32(Parser, Tokens[1:], "FocusDist", false)
		}
        else if Tokens[0] == "FOV"
        {
			Camera.FOV = ReadF32(Parser, Tokens[1:], "FOV", false)
        }
        else
        {
            fmt.println("Invalid field", Tokens[0], "for CAMERA")
        }
    }

	return Camera
}

ParseShape :: proc(Parser : ^parser) -> shape
{
	Shape : shape

	for NextLine(Parser)
	{
		Tokens := strings.fields(Parser.CurrentLine)

		if Tokens[0] == "EndShape"
		{
			break
		}

		if Tokens[0] == "Type"
		{
			if Tokens[1] == "sphere"
			{
				Shape = ParseShape_Sphere(Parser)
				break
			}
			else if Tokens[1] == "quad"
			{
				Shape = ParseShape_Quad(Parser)
				break
			}
			else if Tokens[1] == "plane"
			{
				Shape = ParseShape_Plane(Parser)
				break
			}
			else if Tokens[1] == "triangle"
			{
				Shape = ParseShape_Triangle(Parser)
				break
			}
			else
			{
				ReportError(Parser, "ERROR: Invalid shape type")
			}
		}
	}

	return Shape
}

ParseShape_Sphere :: proc(Parser : ^parser) -> sphere
{
	Sphere : sphere

	for NextLine(Parser)
	{
		Tokens := strings.fields(Parser.CurrentLine)

		if Tokens[0] == "EndShape"
		{
			break
		}

		if Tokens[0] == "Center"
		{
			Sphere.Center = ReadV3(Parser, Tokens[1:], "Center")
		}
		else if Tokens[0] == "Radius"
		{
			Sphere.Radius = ReadF32(Parser, Tokens[1:], "Radius", false)
		}
		else
		{
			ReportError(Parser, "ERROR: Invalid member for sphere")
		}
	}

	return Sphere
}

ParseShape_Quad :: proc(Parser : ^parser) -> quad
{
	TempQuad : quad

	for NextLine(Parser)
	{
		Tokens := strings.fields(Parser.CurrentLine)

		if Tokens[0] == "EndShape"
		{
			break
		}

		if Tokens[0] == "Q"
		{
			TempQuad.Q = ReadV3(Parser, Tokens[1:], "Q")
		}
		else if Tokens[0] == "u"
		{
			TempQuad.u = ReadV3(Parser, Tokens[1:], "u")
		}
		else if Tokens[0] == "v"
		{
			TempQuad.v = ReadV3(Parser, Tokens[1:], "v")
		}
		else if Tokens[0] == "Translation"
		{
			TempQuad.Translation = ReadV3(Parser, Tokens[1:], "Translation")
		}
		else if Tokens[0] == "Rotation"
		{
			TempQuad.Rotation = ReadF32(Parser, Tokens[1:], "Rotation")
		}
		else
		{
			ReportError(Parser, "ERROR: Invalid member for quad")
		}
	}

	Quad := CreateQuadTransformed(TempQuad.Q, TempQuad.u, TempQuad.v, TempQuad.Translation, TempQuad.Rotation)

	return Quad
}

ParseShape_Plane :: proc(Parser : ^parser) -> plane
{
	Plane : plane

	for NextLine(Parser)
	{
		Tokens := strings.fields(Parser.CurrentLine)

		if Tokens[0] == "EndShape"
		{
			break
		}

		if Tokens[0] == "N"
		{
			Plane.N = ReadV3(Parser, Tokens[1:], "N")
		}
		else if Tokens[0] == "d"
		{
			Plane.d = ReadF32(Parser, Tokens[1:], "d")
		}
		else
		{
			ReportError(Parser, "ERROR: Invalid member for plane")
		}
	}

	return Plane
}

ParseShape_Triangle :: proc(Parser : ^parser) -> triangle
{
	Triangle : triangle

	for NextLine(Parser)
	{
		Tokens := strings.fields(Parser.CurrentLine)

		if Tokens[0] == "EndShape"
		{
			break
		}

		if Tokens[0] == "v0"
		{
			Triangle.Vertices[0] = ReadV3(Parser, Tokens[1:], "v0")
		}
		else if Tokens[0] == "v1"
		{
			Triangle.Vertices[1] = ReadV3(Parser, Tokens[1:], "v1")
		}
		else if Tokens[0] == "v2"
		{
			Triangle.Vertices[2] = ReadV3(Parser, Tokens[1:], "v2")
		}
		else
		{
			ReportError(Parser, "ERROR: Invalid member for triangle")
		}
	}

	return Triangle
}

NextLine :: proc(Parser : ^parser) -> bool
{
    for
    {
        if Parser.CurrentLineNumber < len(Parser.Lines)
        {
            Line := Parser.Lines[Parser.CurrentLineNumber]
            Trimmed := strings.split(Line, "#")[0]
            Trimmed = strings.trim(Trimmed, " ")
            Trimmed = strings.trim(Trimmed, "\t")

            Parser.CurrentLine = Trimmed
            Parser.CurrentLineNumber += 1

            if len(Trimmed) == 0
            {
                continue
            }
            else
            {
                return true
            }
        }
        else
        {
            return false
        }
    }
}

ReportError :: proc(Parser : ^parser, Message : string)
{
    Error := error{Message, Parser.CurrentLineNumber}
    append(&Parser.Errors, Error)
}

IsNumeric :: proc(String : string) -> bool
{
    for C in String
    {
        if !(C >= '0' && C <= '9')
        {
            return false
        }
    }

    return true
}

ReadF32 :: proc(Parser : ^parser, Tokens : []string, FieldName : string, NegativeAllowed : bool = true) -> f32
{
	Ret : f32

	if len(Tokens) == 1
	{
		Component := Tokens[0]

		Start : int

		if Component[0] == '-'
		{
			if NegativeAllowed
			{
				Start = 1
			}
			else
			{
				ReportError(Parser, strings.concatenate([]string{"ERROR: field '", FieldName, "' must be a positive value"}))
			}
		}

		if IsNumeric(Component[Start:])
		{
			Value := cast(f32)strconv.atof(Component)
			Ret = Value
		}
	}
	else
	{
		ReportError(Parser, strings.concatenate([]string{"ERROR: field '", FieldName, "' is a single float"}))
	}

	return Ret
}

ReadV3 :: proc(Parser : ^parser, Tokens : []string, FieldName : string) -> v3
{
	Ret : v3

	// TODO(matthew): validate that all 3 tokens are proper numeric values
	if len(Tokens) == 3
	{
		for Component, Idx in Tokens
		{
			Start : int

			if Component[0] == '-'
			{
				Start = 1
			}

			if IsNumeric(Component[Start:])
			{
				Value := cast(f32)strconv.atof(Component)
				Ret[Idx] = Value
			}
			else
			{
				ReportError(Parser, strings.concatenate([]string{"ERROR: non-numeric value specified in field '", FieldName, "'"}))
			}
		}
	}
	else
	{
		ReportError(Parser, strings.concatenate([]string{"ERROR: field '", FieldName, "' takes 3 floats"}))
	}

	return Ret
}

