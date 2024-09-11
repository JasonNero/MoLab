import numpy as np
import bpy






# TODO: THIS IS UNTESTED, CHATGPT-TRANSLATED CODE
#       Walk through, test, simplify, and refactor as needed






def get_hierarchy(bone) -> list[str]:
    """This returns the hierarchy of bones in the armature."""
    result = [bone.name]
    for child in bone.children:
        result.extend(get_hierarchy(child))
    return result


def get_fcurve_data(obj, bone_name, data_path, frame) -> list:
    """Helper function to fetch fcurve data for a specific attribute (location, rotation_euler, scale)."""
    anim_data = obj.animation_data
    if not anim_data or not anim_data.action:
        return None

    for fcurve in anim_data.action.fcurves:
        # Check if the fcurve corresponds to the bone and the specific attribute
        if fcurve.data_path == f'pose.bones["{bone_name}"].{data_path}':
            # Check if there is a keyframe at the specified frame
            for keyframe in fcurve.keyframe_points:
                if int(keyframe.co[0]) == frame:
                    # Return the value at the frame (from the fcurve's keyframe)
                    return fcurve.evaluate(frame)
    return None


def get_transform_key_at_frame(bone, frame) -> dict[str, list]:
    """Get the keyframe values for the given bone at the given frame, but only if keyed."""
    result = {}
    obj = bone.id_data  # The armature object

    # Check for location keyframes
    location_keyed = [
        get_fcurve_data(obj, bone.name, "location", frame) for i in range(3)
    ]
    if any(loc is not None for loc in location_keyed):
        result["location"] = location_keyed

    # Check for rotation_euler keyframes
    rotation_keyed = [
        get_fcurve_data(obj, bone.name, "rotation_euler", frame) for i in range(3)
    ]
    if any(rot is not None for rot in rotation_keyed):
        result["rotation_euler"] = rotation_keyed

    # Check for scale keyframes
    scale_keyed = [get_fcurve_data(obj, bone.name, "scale", frame) for i in range(3)]
    if any(scl is not None for scl in scale_keyed):
        result["scale"] = scale_keyed

    return result


def extract_keyframes() -> tuple[np.ndarray, np.ndarray]:
    """Extract keyframes from the selected armature and bones."""
    # Get the selected armature
    armature = bpy.context.object
    assert armature.type == 'ARMATURE', "Please select an armature."

    # Get the start and end frames
    start = bpy.context.scene.frame_start
    end = bpy.context.scene.frame_end

    print(
        f"Extracting keyframes of armature '{armature.name}' in range {start} to {end}..."
    )

    # Get the hierarchy of the root bone
    root_bone = armature.pose.bones[0]  # Assuming root is the first bone
    names = get_hierarchy(root_bone)
    assert len(names) == 22, f"Expected 22 bones, got {len(names)}!"

    # Extract pos/rot for each bone at each frame
    positions = np.nan * np.ones((int(end) - int(start) + 1, 22, 3))
    rotations = np.nan * np.ones((int(end) - int(start) + 1, 22, 3))
    for frame in range(int(start), int(end) + 1):
        frame_idx = frame - int(start)
        for bone_idx, name in enumerate(names):
            bone = armature.pose.bones.get(name)
            if bone:
                keyframes = get_transform_key_at_frame(bone, frame)

                # If keyed, set the position and rotation
                if "location" in keyframes:
                    positions[frame_idx, bone_idx] = keyframes.get(
                        "location", np.ones(3) * np.nan
                    )
                if "rotation_euler" in keyframes:
                    rotations[frame_idx, bone_idx] = keyframes.get(
                        "rotation_euler", np.ones(3) * np.nan
                    )

                # Check for unwanted scale keyframes
                assert (
                    "scale" not in keyframes
                ), f"Unexpected scale keyframes in bone: {name}"
                assert (
                    "location" not in keyframes or bone_idx == 0
                ), f"Unexpected location keyframes in non-root bone: {name}"

    return positions, rotations


def pack_keyframes(positions: np.ndarray, rotations: np.ndarray) -> dict[int, list]:
    """Pack the keyframes into a more compact format."""
    root_pos = positions[:, 0]
    frame_mask_pos = ~np.isnan(root_pos).any(axis=(1))
    frame_mask_rot = ~np.isnan(rotations).any(axis=(1, 2))

    # Combine all frames that have non-nan values
    frame_mask = frame_mask_pos | frame_mask_rot
    valid_frames = np.where(frame_mask)[0]

    packed_motion: dict = {}
    for frame in valid_frames.tolist():
        packed_motion[frame] = np.ones((23, 3)) * np.nan
        packed_motion[frame][0] = root_pos[frame]
        packed_motion[frame][1:] = rotations[frame]

    # Return packed motion in list format
    return {frame: packed_motion[frame].tolist() for frame in packed_motion}


# Ensure an armature is selected in Object Mode
if bpy.context.object and bpy.context.object.type == 'ARMATURE':
    keyframes = extract_keyframes()
    packed_motion = pack_keyframes(*keyframes)
    print(packed_motion)
else:
    print("Please select an armature in Object Mode.")
