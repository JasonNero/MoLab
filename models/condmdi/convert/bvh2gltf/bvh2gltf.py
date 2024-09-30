"""Convert BVH files to glTF using Blender.

Usage: `blender --background --python bvh2gltf.py -- [BVH files or directories containing them]`
"""

import argparse
import sys
from pathlib import Path

import bpy


def main():
    parser = argparse.ArgumentParser(description="Convert BVH files to glTF.")
    parser.add_argument(
        "paths",
        nargs="*",
        help="Paths to BVH files or folders containing them.",
        type=Path,
    )

    # The -- is a separator between arguments passed to Blender and script
    argv = sys.argv
    if "--" not in argv:
        argv = ["."]  # Default to current directory if no paths are provided.
    else:
        argv = argv[argv.index("--") + 1 :]

    args = parser.parse_args(argv)

    bvh_files = []
    for path in args.paths:
        if path.is_file():
            bvh_files.append(path)
        elif path.is_dir():
            bvh_files.extend(list(path.glob("*.bvh")))
        else:
            print(f"Skipping {path}: not a valid file or directory.")

    print(f"Found a total {len(bvh_files)} BVH files to convert.")

    # TODO: Make Blender less verbose here or highlight the progress better.
    for i, bvh_path in enumerate(bvh_files):
        print(f"Converting {bvh_path.name} ({i + 1}/{len(bvh_files)})")

        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_anim.bvh(
            filepath=bvh_path.as_posix(),
            update_scene_fps=True,
            update_scene_duration=True,
        )
        bpy.ops.export_scene.gltf(
            filepath=bvh_path.with_suffix(".gltf").as_posix(),
            export_format="GLTF_SEPARATE",
        )

    print(f"Successfully converted {len(bvh_files)} BVH files to glTF.")


if __name__ == "__main__":
    main()
