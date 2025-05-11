package main

camera :: struct
{
	Center : v3,
	FirstPixel : v3,
	PixelDeltaU : v3,
	PixelDeltaV : v3,

	LookFrom : v3,
	LookAt : v3,
	FocusDist : f32,
	FOV : f32,
};

InitializeCamera :: proc(Camera : ^camera, ImageWidth, ImageHeight : i32)
{
	// TODO(matthew): Bulletproof this. Might still be having issues depending
	// on aspect ratios, etc, but it seems to be fine right now.
	Theta : f32 = Degs2Rads(Camera.FOV)
	h : f32 = Tan(Theta / 2)
	ViewportHeight : f32 = 2 * h * Camera.FocusDist
	ViewportWidth : f32 = ViewportHeight * f32(ImageWidth) / f32(ImageHeight)
	Camera.Center = Camera.LookFrom

	if (ImageWidth > ImageHeight)
	{
		ViewportHeight = ViewportWidth * f32(ImageHeight) / f32(ImageWidth)
	}
	else
	{
		ViewportWidth = ViewportHeight * f32(ImageWidth) / f32(ImageHeight)
	}

	CameraW := Normalize(Camera.LookFrom - Camera.LookAt)
	CameraU := Normalize(Cross(v3{0, 1, 0}, CameraW))
	CameraV := Normalize(Cross(CameraW, CameraU))

	// Viewport
	ViewportU := ViewportWidth * CameraU
	ViewportV := -ViewportHeight * CameraV

	// Pixel deltas
	Camera.PixelDeltaU = ViewportU / f32(ImageWidth)
	Camera.PixelDeltaV = ViewportV / f32(ImageHeight)

	// First pixel
	ViewportUpperLeft := Camera.Center - (Camera.FocusDist * CameraW) - (ViewportU / 2) - (ViewportV / 2)
	Camera.FirstPixel = ViewportUpperLeft + 0.5 * (Camera.PixelDeltaU + Camera.PixelDeltaV)
}

