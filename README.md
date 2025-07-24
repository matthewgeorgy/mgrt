# mgrt

This is my personal raytracer written in the Odin programming language.

## Build instructions

**1. Requirements**

You'll need the Odin compiler: https://odin-lang.org/.

**2. Build environment setup**

Ensure that the Odin compiler is properly installed and configured in your PATH. To check that the compiler is accessible from your command line, run:

```
odin
```

If everything is set up correctly, you should have output similar to the following:
```
odin is a tool for managing Odin source code.
Usage:
        odin command [arguments]
Commands:
        build             Compiles directory of .odin files, as an executable.
                          One must contain the program's entry point, all must be in the same package.
        run               Same as 'build', but also then runs the newly compiled executable.
        check             Parses, and type checks a directory of .odin files.
        strip-semicolon   Parses, type checks, and removes unneeded semicolons from the entire program.
        test              Builds and runs procedures with the attribute @(test) in the initial package.
        doc               Generates documentation on a directory of .odin files.
        version           Prints version.
        report            Prints information useful to reporting a bug.
        root              Prints the root path where Odin looks for the builtin collections.

For further details on a command, invoke command help:
        e.g. `odin build -help` or `odin help build`
```

**3. Building**

Start by cloning the repo:
```
git clone https://github.com/matthewgeorgy/mgrt
cd mgrt
```
Then, use the provided `make.bat` build script in the root of the directory to build the project:
```
make
```
This will produce two executables in the `build` directory:
1. `mgrt`: Optimized, multi-threaded.
2. `mgrt_dbg`: Unoptimized, single-threaded.

## Gallery

See [the following](./gallery/README.md).

## Features

### Integrators
- Backward path-tracing
- Photon mapping (diffuse and specular materials only)

### BxDFs / Materials
- Lambertian
- Metal
- Dieletric
- Oren-Nayar
- MERL

### Geometry
- Sphere
- Quad
- Plane
- Triangle
- Box
- Triangle mesh (OBJ, PLY) + BVH

### Misc
- Tiled multithreaded rendering
- Custom scene parser

### Future work
- Disney Principled BRDF
- NEE + MIS
- Bidirectional path tracing
- IBL / environment lighting
- Path guiding techniques

See the top comment block in `source\main.odin` for more details.

