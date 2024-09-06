from pprint import pprint

import numpy as np
import pymel.core as pmc


def get_hierarchy(joint) -> list[str]:
    """This returns the hierarchy just like in the BVH file.
    (Uses a different approach than `pmc.listRelatives(allDescendents=True)`)
    """
    children = pmc.listRelatives(joint, children=True, type="joint")
    result = [joint.name()]

    for child in children:
        result.extend(get_hierarchy(child))
    return result


def get_transform_key_at_frame(joint, frame) -> dict[str, list]:
    """Get the keyframe values for the given joint at the given frame."""
    result = {}
    for attr in ["translate", "rotate", "scale"]:
        key = pmc.keyframe(
            joint,
            query=True,
            time=(frame, frame),
            attribute=attr,
            valueChange=True,  # return value
        )
        if key:
            result[attr] = key
    return result


def extract_keyframes() -> tuple[np.ndarray, np.ndarray]:
    """Extract the keyframes from the selected joint.

    Returns:
        positions: (N, 22, 3) array of joint positions
        rotations: (N, 22, 3) array of joint rotations
    """
    # Get the selected root joint
    selected_joints = pmc.ls(selection=True, type="joint")
    assert len(selected_joints) == 1
    root_obj = selected_joints[0]

    # Get the start and end frames
    start = pmc.playbackOptions(query=True, minTime=True)
    end = pmc.playbackOptions(query=True, maxTime=True)

    print(
        f"Extracting keyframes of skeleton with root '{root_obj}' in range {start} to {end}..."
    )

    # Get the hierarchy of the root joint
    names = get_hierarchy(root_obj)
    assert len(names) == 22, f"Expected 22 joints, got {len(names)}!"

    # Extract pos/rot for each joint at each frame, using np.nan for missing values
    positions = np.nan * np.ones((int(end) - int(start) + 1, 22, 3))
    rotations = np.nan * np.ones((int(end) - int(start) + 1, 22, 3))
    for frame in range(int(start), int(end) + 1):
        frame_idx = frame - int(start)
        for joint_idx, name in enumerate(names):
            # Check that the `rotateOrder` is 0 (XYZ) for all joints
            assert (
                pmc.getAttr(f"{name}.rotateOrder") == 0
            ), f"Expected `rotateOrder` XYZ in joint: {name}"

            keyframes = get_transform_key_at_frame(name, frame)
            positions[frame_idx, joint_idx] = keyframes.get(
                "translate", np.ones(3) * np.nan
            )
            rotations[frame_idx, joint_idx] = keyframes.get(
                "rotate", np.ones(3) * np.nan
            )

            assert (
                "scale" not in keyframes
            ), f"Unexpected scale keyframes in joint: {name}"
            assert (
                "translate" not in keyframes or joint_idx == 0
            ), f"Unexpected translate keyframes in non-root joint: {name}"

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

    # return packed_motion
    return {frame: packed_motion[frame].tolist() for frame in packed_motion}


keyframes = extract_keyframes()
packed_motion = pack_keyframes(*keyframes)
pprint(packed_motion)
