"""
This module provides functions to work with joint hierarchies and keyframe data in Maya.
It also supplies packing and unpacking of keyframe data.

Functions:
    get_hierarchy(joint) -> list[str]:
        Returns the hierarchy of joints starting from the given joint.

    get_transform_key_at_frame(joint, frame) -> dict[str, list]:
        Retrieves the keyframe values for the given joint at the specified frame.

    get_selected_skeleton():
        Gets and validates the selected skeleton in Maya.

    extract_keyframes() -> tuple[np.ndarray, np.ndarray]:
        Extracts keyframes from the selected joint and returns joint positions and rotations.

    pack_keyframes(positions: np.ndarray, rotations: np.ndarray, verbose=False) -> dict[int, list]:
        Packs the keyframes into a more compact format.

    unpack_motion(packed_motion: dict[int, list]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        Unpacks the packed motion input and returns joint positions and mask.

    apply_motion(root_pos: np.ndarray, rotations: np.ndarray, joint_mask: Optional[np.ndarray] = None, start_frame: int = 1, name: str = "sample"):
        Applies the motion data to the skeleton in Maya.

    import_motions(root_positions, joint_rotations, start_frame=1, name="sample"):
        Imports motions by applying root positions and joint rotations to the skeleton.

    _test():
        A test function to extract, pack, unpack, and apply keyframes.
"""

from typing import Optional

import numpy as np
import pymel.core as pmc


def get_hierarchy(joint) -> list[str]:
    """This returns the hierarchy just like in the BVH file.
    (Uses a different approach than `pmc.listRelatives(allDescendents=True)`)
    """
    children = pmc.listRelatives(joint, children=True, type="joint")
    result = [joint]

    for child in children:
        result.extend(get_hierarchy(child))
    return result


def get_transform_key_at_frame(joint, frame) -> dict[str, list]:
    """Get the keyframe values for the given joint at the given frame.
    The Euler order is assumed to be XYZ (see get_selected_skeleton).

    NOTE: Rotation keys are returned in as ZYX, not XYZ, not sure why.
          This has nothing to do with Euler order though, just how it's stored.

    Returns:
        result: A dictionary with the following keys:
            - translate: A list of [tX, tY, tZ] values
            - rotate: A list of [rZ, rY, rX] values (degrees)
            - scale: A list of [sX, sY, sZ] values
    """
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


def get_selected_skeleton():
    """Get and validate the selected skeleton."""
    selected_joints = pmc.ls(selection=True, type="joint")
    assert len(selected_joints) == 1, "Select a single root joint!"
    joints = get_hierarchy(selected_joints[0])

    assert len(joints) == 22, f"Expected 22 joints, got {len(joints)}!"
    for joint in joints:
        assert (
            joint.getAttr("rotateOrder") == 0
        ), f"Expected `rotateOrder` XYZ in joint: {joint}"

    return joints


def extract_keyframes() -> tuple[np.ndarray, np.ndarray]:
    """Extract the keyframes from the selected joint.

    Returns:
        positions: (N, 22, 3) array of joint positions
        rotations: (N, 22, 3) array of joint rotations
    """
    joints = get_selected_skeleton()

    # Get the start and end frames
    start = pmc.playbackOptions(query=True, minTime=True)
    end = pmc.playbackOptions(query=True, maxTime=True)

    print(f"Extracting keyframes of '{joints[0].getParent()}' [{start}-{end}]")

    # Extract pos/rot for each joint at each frame, using np.nan for missing values
    positions = np.nan * np.ones((int(end) - int(start) + 1, 22, 3))
    rotations = np.nan * np.ones((int(end) - int(start) + 1, 22, 3))
    for frame in range(int(start), int(end) + 1):
        frame_idx = frame - int(start)
        for joint_idx, joint in enumerate(joints):
            keyframes = get_transform_key_at_frame(joint, frame)
            positions[frame_idx, joint_idx] = keyframes.get(
                "translate", np.ones(3) * np.nan
            )
            rotations[frame_idx, joint_idx] = keyframes.get(
                "rotate", np.ones(3) * np.nan
            )

    return positions, rotations


def pack_keyframes(
    positions: np.ndarray, rotations: np.ndarray, verbose=False
) -> dict[int, list]:
    """Pack the keyframes into a more compact format."""
    root_pos = positions[:, 0]
    frame_mask_pos = ~np.isnan(root_pos).any(axis=(1))
    frame_mask_rot = ~np.isnan(rotations).any(axis=(1, 2))

    # Combine all frames that have non-nan values
    frame_mask = frame_mask_pos | frame_mask_rot
    valid_frames = np.where(frame_mask)[0]

    if verbose:
        print(f"Compacting to (partial) Keyposes on Frames:\n{valid_frames}")

    packed_motion: dict = {}
    for frame in valid_frames.tolist():
        packed_motion[frame] = np.ones((23, 3)) * np.nan
        packed_motion[frame][0] = root_pos[frame]
        packed_motion[frame][1:] = rotations[frame]

    # return packed_motion
    return {frame: packed_motion[frame].tolist() for frame in packed_motion}


def extract_and_pack_keyframes() -> dict[int, list]:
    keyframes = extract_keyframes()
    return pack_keyframes(*keyframes)


def unpack_motion(
    packed_motion: dict[int, list]
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Unpack the packed motion input and return the joint positions and mask.

    Packed Motion Format:
    - A dictionary mapping frame indices to packed poses
    - A packed pose contains the root position followed by all 22 joint rotations
    - Values stored as `nan` indicate sparse keyframes and are converted to a joint mask
    """
    packed_motion = {int(k): np.array(v) for k, v in packed_motion.items()}

    # We actually have 22 joints, but are piggybacking the root pos in the first index.
    assert next(iter(packed_motion.values())).shape[0] == 23, "Expected 22 joints + 1"

    input_frames = np.max(list(packed_motion.keys()))
    motion = np.zeros((input_frames + 1, 22 + 1, 3))
    joint_mask = np.zeros((input_frames + 1, 22 + 1, 1), dtype=bool)
    for frame, pose in packed_motion.items():
        _pose_mask = ~np.isnan(pose)
        motion[frame, _pose_mask] = pose[_pose_mask]
        joint_mask[frame] = _pose_mask.all(axis=-1).reshape(-1, 1)

    # Extract root position and mask
    root_pos = motion[:, 0].copy()
    root_mask = joint_mask[:, 0].copy()
    rotations = motion[:, 1:]
    joint_mask = joint_mask[:, 1:]

    # Theoretically, this should always hold true, otherwise we would
    # need separate joint and feature masks (which is possible).
    assert np.all(
        np.equal(root_mask, joint_mask[:, 0])
    ), "Root pos mask does not match root rot mask"

    return root_pos, rotations, joint_mask


def apply_motion(
    root_pos: np.ndarray,
    rotations: np.ndarray,
    joint_mask: Optional[np.ndarray] = None,
    start_frame: int = 1,
    name: str = "sample",
):
    # Get the original skeleton group
    orig_root_grp = get_selected_skeleton()[0].getParent()

    # Duplicate the source skeleton
    root_grp = pmc.duplicate(orig_root_grp, name=f"{name}_{orig_root_grp}")
    root_grp = pmc.ls(root_grp)[0]
    root_obj = root_grp.listRelatives(children=True, type="joint")[0]
    joints = get_hierarchy(root_obj)

    # Get the start and end frames
    start = start_frame
    end = start_frame + root_pos.shape[0] - 1

    print(f"Applying keyframes to '{joints[0].getParent()}' [{start}-{end}]")

    for frame_time in range(start, end + 1):
        frame_idx = frame_time - start
        for joint_idx, name in enumerate(joints):
            # Skip joints that are not part of the mask
            if joint_mask is not None and not joint_mask[frame_idx, joint_idx]:
                continue

            # Apply root position to the root joint
            if joint_idx == 0:
                pmc.setKeyframe(
                    name,
                    time=frame_time,
                    attribute="tx",
                    value=root_pos[frame_idx, 0],
                )
                pmc.setKeyframe(
                    name,
                    time=frame_time,
                    attribute="ty",
                    value=root_pos[frame_idx, 1],
                )
                pmc.setKeyframe(
                    name,
                    time=frame_time,
                    attribute="tz",
                    value=root_pos[frame_idx, 2],
                )

            # Apply joint rotations to the all joints
            pmc.setKeyframe(
                name,
                time=frame_time,
                attribute="rx",
                value=rotations[frame_idx, joint_idx, 0],
            )
            pmc.setKeyframe(
                name,
                time=frame_time,
                attribute="ry",
                value=rotations[frame_idx, joint_idx, 1],
            )
            pmc.setKeyframe(
                name,
                time=frame_time,
                attribute="rz",
                value=rotations[frame_idx, joint_idx, 2],
            )


def import_motions(root_positions, joint_rotations, start_frame=1, name="sample"):
    for root_pos, rotations in zip(root_positions, joint_rotations):
        apply_motion(np.array(root_pos), np.array(rotations), start_frame=start_frame, name=name)


###############################################################################


def _test():
    print("Extracting keyframes...")
    keyframes = extract_keyframes()
    print("Packing keyframes...")
    packed_motion = pack_keyframes(*keyframes)
    # pprint(packed_motion)
    print("Unpacking motion...")
    root_pos, rotations, joint_mask = unpack_motion(packed_motion)
    print("Applying motion...")
    apply_motion(root_pos, rotations, joint_mask, 1)
