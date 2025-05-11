package main

import libc		"core:c/libc"
import fmt		"core:fmt"
import strings	"core:strings"
import mem		"core:mem"

bitmap_header :: struct #packed
{
	FileType		: u16,
	FileSize		: u32,
	Reserved1		: u16,
	Reserved2		: u16,
	BitmapOffset	: u32,
	Size			: u32,
	Width			: i32,
	Height			: i32,
	Planes			: u16,
	BitsPerPixel	: u16,
	Compression		: u32,
	SizeOfBitmap 	: u32,
	HorzResolution 	: i32,
	VertResolution 	: i32,
	ColorsUsed 		: u32,
	ColorsImportant : u32,
};

image_u32 :: struct
{
	Width : i32,
	Height : i32,
	Pixels : ^u32,
};

GetMemoryFootprint :: proc(Image : image_u32) -> u32
{
	// NOTE(matthew): 4 bytes per pixel
	return u32(Image.Width * Image.Height * 4)
}

AllocateImage :: proc(Width, Height : i32) -> image_u32
{
	Image : image_u32

	Image.Width = Width
	Image.Height = Height

	MemorySize := GetMemoryFootprint(Image)
	Image.Pixels = cast(^u32)libc.malloc(uint(MemorySize))

	return Image
}

WriteImage :: proc(Image : image_u32, OutputFileName : string)
{
	Header : bitmap_header
	MemorySize := GetMemoryFootprint(Image)

	Header.FileType = 0x4D42
	Header.FileSize = size_of(Header) + MemorySize
	Header.BitmapOffset = size_of(Header)
	Header.Size = size_of(Header) - 14
	Header.Width = Image.Width
	Header.Height = -Image.Height // make pixels top -> bottom
	Header.Planes = 1
	Header.BitsPerPixel = 32
	Header.SizeOfBitmap = MemorySize

	File := libc.fopen(strings.clone_to_cstring(OutputFileName), "wb")
	if File != nil
	{
		libc.fwrite(&Header, size_of(Header), 1, File)
		libc.fwrite(Image.Pixels, uint(MemorySize), 1, File)
		libc.fclose(File)
	}
	else
	{
		fmt.println("Failed to open file...!\r\n")
	}
}

PackRGBA :: proc(Red, Green, Blue, Alpha : u8) -> u32
{
	Output : u32
	R := u32(Red)
	G := u32(Green)
	B := u32(Blue)
	A := u32(Alpha)

	Output =  (A << 24) | (R << 16) | (G << 8) | B

	return Output
}

LinearTosRGB :: proc (LinearValue : f32) -> f32
{
	if LinearValue > 0
	{
		return SquareRoot(LinearValue)
	}

	return 0
}

WritePixel :: proc(Image : image_u32, X, Y : i32, PixelColor : v3)
{
	Out := Image.Pixels
	Color : v3

	Color.r = LinearTosRGB(PixelColor.r)
	Color.g = LinearTosRGB(PixelColor.g)
	Color.b = LinearTosRGB(PixelColor.b)

	Red := u8(f32(255.999) * Color.r)
	Green := u8(f32(255.999) * Color.g)
	Blue := u8(f32(255.999) * Color.b)

	Out = mem.ptr_offset(Out, X + Y * Image.Width)
	Out^ = PackRGBA(Red, Green, Blue, 0)
}

