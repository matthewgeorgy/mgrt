package main

import fmt 		"core:fmt"
import os 		"core:os"
import strings 	"core:strings"
import strconv	"core:strconv"
import ansi		"core:encoding/ansi"

/*
	TODO(matthew):
	- Be able to specify the quad normal explicitly
	- General cleanups

	NOTE(matthew): done:
	- Check if a name (shape, material, light) has been used more than once
	- More thorough error checking and handling
	- Stop from rendering if there were errors while parsing the scene file
	- Make Scale=1 the default value if it's not specified
	- Include the scene file name in error messages
*/

error :: struct
{
	Message : string,
	LineNumber : int,
}

parser :: struct
{
	Lines : [dynamic]string,
	CurrentLine : string,
	CurrentLineNumber : int,

	Errors : [dynamic]error,

	Shapes : [dynamic]shape,
	Materials : [dynamic]material,
	Lights : [dynamic]light,
	Primitives : [dynamic]primitive,

	ShapeTable : map[string]int,
	MaterialTable : map[string]int,
	LightTable : map[string]int,
}

ParseScene :: proc(Filename : string) -> (camera, image_u32, scene, integrator)
{
	File, ok := os.read_entire_file(Filename)
	defer delete(File)

	Parser : parser

	if ok
	{
		StringFile := string(File)

		for Line in strings.split_lines_iterator(&StringFile)
		{
			append(&Parser.Lines, Line)
		}
	}

	append(&Parser.Lights, light{}) // The 'null' light
	append(&Parser.Materials, lambertian{}) // The 'background' material

	Camera, TempImage, BVH, Integrator := ParseFile(&Parser)
	Scene : scene
	Image : image_u32

	if len(Parser.Errors) == 0
	{
		Image = AllocateImage(TempImage.Width, TempImage.Height)

		InitializeCamera(&Camera, Image.Width, Image.Height)

		Scene.Materials = Parser.Materials
		Scene.Lights = Parser.Lights
		Scene.Primitives = Parser.Primitives
		Scene.BVH = BVH

		GatherLightIndices(&Scene)
	}
	else
	{
		for Error in Parser.Errors
		{
			fmt.printf("%s(%d)", strings.clone_to_cstring(Filename), Error.LineNumber)
			fmt.print(ansi.CSI + ansi.FG_RED + ansi.SGR + string(" Error: ") + ansi.CSI + ansi.RESET + ansi.SGR)
			fmt.print(strings.clone_to_cstring(Error.Message), "\n")
		}

		os.exit(-1)
	}

	return Camera, Image, Scene, Integrator
}

ParseFile :: proc(Parser : ^parser) -> (camera, image_u32, bvh, integrator)
{
    Camera : camera
	Image : image_u32
	BVH : bvh
	Integrator : integrator

    for NextLine(Parser)
    {
        Tokens := ReadLine(Parser)

        if Tokens[0] == "BeginCamera"
        {
			if len(Tokens) == 1
			{
            	Camera = ParseCamera(Parser)
			}
			else
			{
				ReportError(Parser, "Too many symbols, BeginCamera is a standalone keyword")
			}
        }

		if Tokens[0] == "BeginShape"
		{
			if len(Tokens) == 2
			{
				ShapeName := Tokens[1]

				ShapeExists := ShapeName in Parser.ShapeTable

				if ShapeExists
				{
					ReportError(Parser, strings.concatenate([]string{"A shape with the name '", ShapeName, "' was already defined"}))
				}
				else
				{
					Shape := ParseShape(Parser)
					append(&Parser.Shapes, Shape)
					Parser.ShapeTable[ShapeName] = len(Parser.Shapes) - 1
				}
			}
			else
			{
				ReportError(Parser, "Invalid syntax, BeginShape takes a single name")
			}
		}

		if Tokens[0] == "BeginMaterial"
		{
			if len(Tokens) == 2
			{
				MaterialName := Tokens[1]
				Material : material

				if MaterialName == "background"
				{
					Material = ParseMaterial(Parser)

					if _, IsLambertian := Material.(lambertian); IsLambertian
					{
						Parser.Materials[0] = Material
					}
					else
					{
						ReportError(Parser, "The 'background' material must be lambertian")
					}
				}
				else
				{
					MaterialExists := MaterialName in Parser.MaterialTable

					if MaterialExists
					{
						ReportError(Parser, strings.concatenate([]string{"A material with the name '", MaterialName, "' was already defined"}))
					}
					else
					{
						Material = ParseMaterial(Parser)
						append(&Parser.Materials, Material)
						Parser.MaterialTable[MaterialName] = len(Parser.Materials) - 1
					}
				}
			}
			else
			{
				ReportError(Parser, "Invalid syntax, BeginMaterial takes a single name")
			}
		}

		if Tokens[0] == "BeginLight"
		{
			if len(Tokens) == 2
			{
				LightName := Tokens[1]

				LightExists := LightName in Parser.LightTable

				if LightExists
				{
					ReportError(Parser, strings.concatenate([]string{"A light with the name '", LightName, "' was already defined"}))
				}
				else
				{
					Light := ParseLight(Parser)
					append(&Parser.Lights, Light)
					Parser.LightTable[LightName] = len(Parser.Lights) - 1
				}
			}
			else
			{
				ReportError(Parser, "Invalid syntax, BeginLight takes a single name")
			}
		}

		if Tokens[0] == "BeginPrimitives"
		{
			if len(Tokens) == 1
			{
				Primitives := ParsePrimitives(Parser)

				for Primitive in Primitives
				{
					append(&Parser.Primitives, Primitive)
				}

				delete(Primitives)
			}
			else
			{
				ReportError(Parser, "BeginPrimitive takes no args")
			}
		}

		if Tokens[0] == "BeginImage"
		{
			if len(Tokens) == 1
			{
				Image = ParseImage(Parser)
			}
			else
			{
				ReportError(Parser, "BeginImage takes no args")
			}
		}

		if Tokens[0] == "BeginMesh"
		{
			if len(Tokens) == 1
			{
				BVH = ParseMesh(Parser)
			}
			else
			{
				ReportError(Parser, "BeginMesh takes no args")
			}
		}

		if Tokens[0] == "BeginIntegrator"
		{
			if len(Tokens) == 1
			{
				Integrator = ParseIntegrator(Parser)
			}
			else
			{
				ReportError(Parser, "BeginIntegrator takes no args")
			}
		}
    }

	return Camera, Image, BVH, Integrator
}

ParseCamera :: proc(Parser : ^parser) -> camera
{
	Camera : camera

    for NextLine(Parser)
    {
        Tokens := ReadLine(Parser)

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
			Camera.FocusDist = ReadFloat(Parser, Tokens[1:], "FocusDist", false)
		}
        else if Tokens[0] == "FOV"
        {
			Camera.FOV = ReadFloat(Parser, Tokens[1:], "FOV", false)
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
        Tokens := ReadLine(Parser)

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
			else if Tokens[1] == "box"
			{
				Shape = ParseShape_Box(Parser)
				break
			}
			else
			{
				ReportError(Parser, "Invalid shape type")
			}
		}
	}

	return Shape
}

ParseMaterial :: proc(Parser : ^parser) -> material
{
	Material : material

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

		if Tokens[0] == "EndMaterial"
		{
			break
		}

		if Tokens[0] == "Type"
		{
			if Tokens[1] == "lambertian"
			{
				Material = ParseMaterial_Lambertian(Parser)
				break
			}
			else if Tokens[1] == "metal"
			{
				Material = ParseMaterial_Metal(Parser)
				break
			}
			else if Tokens[1] == "dielectric"
			{
				Material = ParseMaterial_Dielectric(Parser)
				break
			}
			else if Tokens[1] == "merl"
			{
				Material = ParseMaterial_MERL(Parser)
				break
			}
			else if Tokens[1] == "oren_nayar"
			{
				Material = ParseMaterial_OrenNayar(Parser)
				break
			}
			else
			{
				ReportError(Parser, "Invalid material type")
			}
		}
	}

	return Material
}

ParseShape_Sphere :: proc(Parser : ^parser) -> sphere
{
	Sphere : sphere

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

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
			Sphere.Radius = ReadFloat(Parser, Tokens[1:], "Radius", false)
		}
		else
		{
			ReportError(Parser, "Invalid member for sphere")
		}
	}

	return Sphere
}

ParseShape_Quad :: proc(Parser : ^parser) -> quad
{
	TempQuad : quad

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

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
			TempQuad.Rotation = ReadFloat(Parser, Tokens[1:], "Rotation")
		}
		else
		{
			ReportError(Parser, "Invalid member for quad")
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
        Tokens := ReadLine(Parser)

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
			Plane.d = ReadFloat(Parser, Tokens[1:], "d")
		}
		else
		{
			ReportError(Parser, "Invalid member for plane")
		}
	}

	return Plane
}

ParseShape_Triangle :: proc(Parser : ^parser) -> triangle
{
	Triangle : triangle

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

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
			ReportError(Parser, "Invalid member for triangle")
		}
	}

	return Triangle
}

ParseShape_Box :: proc(Parser : ^parser) -> box
{
	Box : box

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

		if Tokens[0] == "EndShape"
		{
			break
		}

		if Tokens[0] == "Min"
		{
			Box.AABB.Min = ReadV3(Parser, Tokens[1:], "Min")
		}
		else if Tokens[0] == "Max"
		{
			Box.AABB.Max = ReadV3(Parser, Tokens[1:], "Max")
		}
		else if Tokens[0] == "Rotation"
		{
			Box.Rotation = Degs2Rads(ReadFloat(Parser, Tokens[1:], "Rotation"))
		}
		else if Tokens[0] == "Translation"
		{
			Box.Translation = ReadV3(Parser, Tokens[1:], "Translation")
		}
		else
		{
			ReportError(Parser, "Invalid member for triangle")
		}
	}

	return Box
}

ParseMaterial_Lambertian :: proc(Parser : ^parser) -> lambertian
{
	Lambertian : lambertian

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

		if Tokens[0] == "EndMaterial"
		{
			break
		}

		if Tokens[0] == "Rho"
		{
			Lambertian.Rho = ReadV3(Parser, Tokens[1:], "Rho", false)
		}
		else
		{
			ReportError(Parser, "Invalid member for lambertian")
		}
	}

	return Lambertian
}

ParseMaterial_Metal :: proc(Parser : ^parser) -> metal
{
	Metal : metal

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

		if Tokens[0] == "EndMaterial"
		{
			break
		}

		if Tokens[0] == "Color"
		{
			Metal.Color = ReadV3(Parser, Tokens[1:], "Color", false)
		}
		else if Tokens[0] == "Fuzz"
		{
			Metal.Fuzz = ReadFloat(Parser, Tokens[1:], "Fuzz", false)
		}
		else
		{
			ReportError(Parser, "Invalid member for metal")
		}
	}

	return Metal
}

ParseMaterial_Dielectric :: proc(Parser : ^parser) -> dielectric
{
	Dielectric : dielectric

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

		if Tokens[0] == "EndMaterial"
		{
			break
		}

		if Tokens[0] == "RefractionIndex"
		{
			Dielectric.RefractionIndex = ReadFloat(Parser, Tokens[1:], "RefractionIndex", false)
		}
		else
		{
			ReportError(Parser, "Invalid member for dielectric")
		}
	}

	return Dielectric
}

ParseMaterial_MERL :: proc(Parser : ^parser) -> merl
{
	MERL : merl

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

		if Tokens[0] == "EndMaterial"
		{
			break
		}

		if Tokens[0] == "File"
		{
			if len(Tokens[1:]) == 1
			{
				MERLFilename := ReadString(Parser, Tokens[1:], "Table", true)
				MERL = CreateMERL(MERLFilename)
			}
			else
			{
				ReportError(Parser, "merl takes a single string for the filename") 
			}
		}
		else
		{
			ReportError(Parser, "Invalid member for merl")
		}
	}

	return MERL
}

ParseMaterial_OrenNayar :: proc(Parser : ^parser) -> oren_nayar
{
	Rho : v3
	Sigma : f32

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

		if Tokens[0] == "EndMaterial"
		{
			break
		}

		if Tokens[0] == "Rho"
		{
			Rho = ReadV3(Parser, Tokens[1:], "Rho", false)
		}
		else if Tokens[0] == "Sigma"
		{
			Sigma = ReadFloat(Parser, Tokens[1:], "Sigma", false)
		}
		else
		{
			ReportError(Parser, "Invalid member for oren_nayar")
		}
	}

	OrenNayar := CreateOrenNayar(Rho, Sigma)

	return OrenNayar
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

            if len(Trimmed) > 0
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

ReadLine :: proc(Parser : ^parser) -> []string
{
	return strings.fields(Parser.CurrentLine)
}

LookupShapeIndex :: proc(Parser : ^parser, ShapeName : string) -> u32
{
	ShapeIndex : u32

	ShapeExists := ShapeName in Parser.ShapeTable

	if ShapeExists
	{
		ShapeIndex = cast(u32)Parser.ShapeTable[ShapeName]
	}
	else
	{
		ReportError(Parser, strings.concatenate([]string{"Shape '", ShapeName, "' not found"}))
	}

	return ShapeIndex
}

LookupMaterialIndex :: proc(Parser : ^parser, MaterialName : string) -> u32
{
	MaterialIndex : u32

	MaterialExists := MaterialName in Parser.MaterialTable

	if MaterialExists
	{
		MaterialIndex = cast(u32)Parser.MaterialTable[MaterialName]
	}
	else
	{
		ReportError(Parser, strings.concatenate([]string{"Material '", MaterialName, "' not found"}))
	}

	return MaterialIndex
}

LookupLightIndex :: proc(Parser : ^parser, LightName : string) -> u32
{
	LightIndex : u32

	LightExists := LightName in Parser.LightTable

	if LightExists
	{
		LightIndex = cast(u32)Parser.LightTable[LightName]
	}
	else
	{
		ReportError(Parser, strings.concatenate([]string{"Light '", LightName, "' not found"}))
	}

	return LightIndex
}

ParseLight :: proc(Parser : ^parser) -> light
{
	Light : light

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

		if Tokens[0] == "EndLight"
		{
			break
		}

		if Tokens[0] == "Le"
		{
			Light.Le = ReadV3(Parser, Tokens[1:], "Le", false)
		}
		else
		{
			ReportError(Parser, "Invalid field for 'Light'")
		}
	}

	return Light
}

ParsePrimitives :: proc(Parser : ^parser) -> []primitive
{
	Primitives : [dynamic]primitive

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

		if Tokens[0] == "EndPrimitives"
		{
			break
		}

		if len(Tokens) == 3
		{
			ShapeName := Tokens[0]
			MaterialName := Tokens[1]
			LightName := Tokens[2]

			ShapeIndex := LookupShapeIndex(Parser, ShapeName)
			MaterialIndex : u32
			LightIndex : u32

			if MaterialName != "nil"
			{
				MaterialIndex = LookupMaterialIndex(Parser, MaterialName)
			}
			if LightName != "nil"
			{
				LightIndex = LookupLightIndex(Parser, LightName)
			}

			Primitive := primitive {
				Shape = Parser.Shapes[ShapeIndex],
				MaterialIndex = MaterialIndex,
				LightIndex = LightIndex,
			}

			append(&Primitives, Primitive)
		}
		else
		{
			ReportError(Parser, "Primitive takes 3 args: [Shape] [MaterialIndex] [LightIndex]")
		}
	}

	return Primitives[:]
}

ParseImage :: proc(Parser : ^parser) -> image_u32
{
	Image : image_u32

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)
		
		if Tokens[0] == "EndImage"
		{
			break
		}

		if Tokens[0] == "Width"
		{
			Image.Width = cast(i32)ReadInt(Parser, Tokens[1:], "Width", false)
		}
		else if Tokens[0] == "Height"
		{
			Image.Height = cast(i32)ReadInt(Parser, Tokens[1:], "Height", false)
		}
		else
		{
			ReportError(Parser, "Invalid field for image")
		}
	}

	return Image
}

ParseMesh :: proc(Parser : ^parser) -> bvh
{
	BVH : bvh
	Mesh : mesh
	Scale : f32 = 1
	Translation : v3
	Rotation : f32
	MaterialIndex : u32

	for NextLine(Parser)
	{
        Tokens := ReadLine(Parser)

		if Tokens[0] == "EndMesh"
		{
			break
		}

		if Tokens[0] == "File"
		{
			Filename := ReadString(Parser, Tokens[1:], "File", true)
			if len(Filename) != 0
			{
				Mesh = LoadMesh(Filename)
			}
		}
		else if Tokens[0] == "Scale"
		{
			Scale = ReadFloat(Parser, Tokens[1:], "Scale", false)
		}
		else if Tokens[0] == "Material"
		{
			MaterialName := ReadString(Parser, Tokens[1:], "Material")
			MaterialIndex = LookupMaterialIndex(Parser, MaterialName)
		}
		else if Tokens[0] == "Translation"
		{
			Translation = ReadV3(Parser, Tokens[1:], "Translation")
		}
		else if Tokens[0] == "Rotation"
		{
			Rotation = ReadFloat(Parser, Tokens[1:], "Rotation")
		}
		else
		{
			ReportError(Parser, "Invalid member for mesh")
		}
	}

	MeshTriangles := AssembleTrianglesFromMesh(Mesh, Scale)
	if MeshTriangles != nil
	{
		BVH = BuildBVH(MeshTriangles)
	}

	BVH.MaterialIndex = MaterialIndex
	BVH.Translation = Translation
	BVH.Rotation = Degs2Rads(Rotation)

	return BVH
}

ParseIntegrator :: proc(Parser : ^parser) -> integrator
{
	Integrator : integrator

	for NextLine(Parser)
	{
		Tokens := ReadLine(Parser)

		if Tokens[0] == "EndIntegrator"
		{
			break
		}

		if Tokens[0] == "Type"
		{
			IntegratorType := ReadString(Parser, Tokens[1:], "Type")

			if IntegratorType == "path_tracing"
			{
				Integrator.Type = .PATH_TRACING
				Integrator.Proc = PathTracingIntegrator
			}
			else if IntegratorType == "photon_map"
			{
				Integrator.Type = .PHOTON_MAP
				Integrator.Proc = PhotonMapIntegrator
			}
			else if IntegratorType == "nee"
			{
				Integrator.Type = .NEE
				Integrator.Proc = NEEIntegrator
			}
			else
			{
				ReportError(Parser, "Invalid integrator type")
			}
		}
		else if Tokens[0] == "SamplesPerPixel"
		{
			Integrator.SamplesPerPixel = ReadInt(Parser, Tokens[1:], "SamplesPerPixel", false)
		}
		else if Tokens[0] == "MaxDepth"
		{
			Integrator.MaxDepth = ReadInt(Parser, Tokens[1:], "MaxDepth", false)
		}
		else
		{
			ReportError(Parser, "Invalid member for integrator")
		}
	}

	return Integrator
}

ReportError :: proc(Parser : ^parser, Message : string)
{
    Error := error{Message, Parser.CurrentLineNumber}
    append(&Parser.Errors, Error)
}

IsNumericInt :: proc(String : string) -> bool
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

IsNumericFloat :: proc(String : string) -> bool
{
	DecimalCount := 0

    for C in String
    {
        if !(C >= '0' && C <= '9')
        {
			if C == '.'
			{
				DecimalCount += 1
			}
			else
			{
            	return false
			}
        }
    }

    return DecimalCount <= 1
}

ReadFloat :: proc(Parser : ^parser, Tokens : []string, FieldName : string, NegativeAllowed : bool = true) -> f32
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
				ReportError(Parser, strings.concatenate([]string{"Field '", FieldName, "' must be a positive value"}))
			}
		}

		if IsNumericFloat(Component[Start:])
		{
			Value := cast(f32)strconv.atof(Component)
			Ret = Value
		}
	}
	else
	{
		ReportError(Parser, strings.concatenate([]string{"Field '", FieldName, "' is a single float"}))
	}

	return Ret
}

ReadInt :: proc(Parser : ^parser, Tokens : []string, FieldName : string, NegativeAllowed : bool = true) -> int
{
	Ret : int

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
				ReportError(Parser, strings.concatenate([]string{"Field '", FieldName, "' must be a positive value"}))
			}
		}

		if IsNumericInt(Component[Start:])
		{
			Value := strconv.atoi(Component)
			Ret = Value
		}
		else
		{
			ReportError(Parser, strings.concatenate([]string{"Invalid type value provided for field '", FieldName, "' (int)"}))
		}
	}
	else
	{
		ReportError(Parser, strings.concatenate([]string{"Field '", FieldName, "' is a single int"}))
	}

	return Ret
}

ReadV3 :: proc(Parser : ^parser, Tokens : []string, FieldName : string, NegativeAllowed : bool = true) -> v3
{
	Ret : v3

	if len(Tokens) == 3
	{
		for Component, Idx in Tokens
		{
			Ret[Idx] = ReadFloat(Parser, []string{Component}[:], FieldName, NegativeAllowed)
		}
	}
	else
	{
		ReportError(Parser, strings.concatenate([]string{"Field '", FieldName, "' takes 3 floats"}))
	}

	return Ret
}

ReadString :: proc(Parser : ^parser, Tokens : []string, FieldName : string, RequiresQuotes : bool = false) -> string
{
	Ret : string

	if len(Tokens) == 1
	{
		if RequiresQuotes
		{
			String := Tokens[0]

			if String[0] == '"' && String[len(String) - 1] == '"'
			{
				Ret = String[1 : len(String) - 1]
			}
			else
			{
				ReportError(Parser, "This string must be surrounded by quotation marks")
			}
		}
		else
		{
			Ret = Tokens[0]
		}
	}
	else
	{
		ReportError(Parser, strings.concatenate([]string{"Expected a single string for '", FieldName, "'"}))
	}

	return Ret
}

