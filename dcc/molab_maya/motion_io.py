"""
This module provides functions to work with joint hierarchies and keyframe data in Maya.
It also supplies packing and unpacking of keyframe data.
"""

from typing import Optional

import numpy as np
import pymel.core as pmc


def _get_hierarchy(joint) -> list[str]:
    """This returns the hierarchy just like in the BVH file.
    (Uses a different approach than `pmc.listRelatives(allDescendents=True)`)
    """
    children = pmc.listRelatives(joint, children=True, type="joint")
    result = [joint]

    for child in children:
        result.extend(_get_hierarchy(child))
    return result


def _get_transform_key_at_frame(joint, frame) -> dict[str, list]:
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


def get_selected_skeleton_joints() -> list[str]:
    """Get and validate the selected skeleton.

    Returns:
        joints: A list of joint names, first joint being the root joint.

    Raises:
        ValueError: If the selected joint/skeleton is not a valid.
    """
    selected_joints = pmc.ls(selection=True, type="joint")
    if len(selected_joints) != 1:
        raise ValueError("Select a single root joint!")
    joints = _get_hierarchy(selected_joints[0])

    if len(joints) != 22:
        raise ValueError(f"Expected 22 joints, got {len(joints)}!")
    for joint in joints:
        if joint.getAttr("rotateOrder") != 0:
            raise ValueError(f"Expected `rotateOrder` XYZ in joint: {joint}")

    return joints


def extract_keyframes(
    joints: list[str], start: Optional[int] = None, end: Optional[int] = None
) -> tuple[np.ndarray, np.ndarray]:
    """Extract the keyframes from the supplied joint list.

    Arguments:
        joints: A list of joint names, first joint should be the root joint.
        start: The start frame for the keyframe extraction. Defaults to the playback start.
        end: The end frame for the keyframe extraction. Defaults to the playback end.

    Returns:
        positions: (N, 22, 3) array of joint positions
        rotations: (N, 22, 3) array of joint rotations

    Raises:
        ValueError: If the framerange is too large (197 frames max).
    """
    # Get the start and end frames
    if start is None:
        start = pmc.playbackOptions(query=True, minTime=True)
    if end is None:
        end = pmc.playbackOptions(query=True, maxTime=True)

    if end - start > 197:
        raise ValueError(f"Framerange too large: {end - start}>197")

    print(f"Extracting keyframes of '{joints[0].getParent()}' [{start}-{end}]")

    # Extract pos/rot for each joint at each frame, using np.nan for missing values
    positions = np.nan * np.ones((int(end) - int(start) + 1, 22, 3))
    rotations = np.nan * np.ones((int(end) - int(start) + 1, 22, 3))
    for frame in range(int(start), int(end) + 1):
        frame_idx = frame - int(start)
        for joint_idx, joint in enumerate(joints):
            keyframes = _get_transform_key_at_frame(joint, frame)
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
    """Pack the keyframes into a more compact format.

    Arguments:
        positions: (N, 22, 3) array of joint positions
        rotations: (N, 22, 3) array of joint rotations
        verbose: Whether to print the compacted frames.

    Returns:
        packed_motion: A dictionary mapping frame indices to packed poses.
    """
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


def extract_and_pack_keyframes(
    joints: list[str], start: Optional[int] = None, end: Optional[int] = None
) -> dict[int, list]:
    """Extract and pack the keyframes from the supplied joint list.

    Arguments:
        joints: A list of joint names, first joint should be the root joint.
        start: The start frame for the keyframe extraction. Defaults to the playback start.
        end: The end frame for the keyframe extraction. Defaults to the playback end.

    Returns:
        packed_motion: A dictionary mapping frame indices to packed poses.
    """
    keyframes = extract_keyframes(joints, start, end)
    return pack_keyframes(*keyframes)


def unpack_motion(
    packed_motion: dict[str, list],
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Unpack the packed motion input and return the joint positions and mask.

    Packed Motion Format:
    - A dictionary mapping frame indices to packed poses
    - A packed pose contains the root position followed by all 22 joint rotations
    - Values stored as `nan` indicate sparse keyframes and are converted to a joint mask

    Arguments:
        packed_motion: A dictionary mapping frame indices to packed poses.

    Returns:
        root_pos: The root positions for each frame.
        rotations: The joint rotations for each frame.
        joint_mask: The mask for each joint and frame.

    Raises:
        ValueError: If the packed motion does not contain 22 joints + 1 root pos.
    """
    packed_motion = {int(k): np.array(v) for k, v in packed_motion.items()}

    # We actually have 22 joints, but are piggybacking the root pos in the first index.
    if next(iter(packed_motion.values())).shape[0] != 23:
        raise ValueError("Expected 22 joints + 1")

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
    assert np.all(np.equal(root_mask, joint_mask[:, 0])), (
        "Root pos mask does not match root rot mask"
    )

    return root_pos, rotations, joint_mask


def _apply_motion(
    skeleton_group: pmc.nodetypes.Transform,
    root_pos: np.ndarray,
    rotations: np.ndarray,
    joint_mask: Optional[np.ndarray] = None,
    start_frame: int = 1,
    name: str = "sample",
):
    """Apply the motion to the skeleton.

    Args:
        skeleton_group: The skeleton group to duplicate and apply the motion to.
        root_pos: The root positions for each frame.
        rotations: The joint rotations for each frame.
        joint_mask: The mask for each joint and frame.
        start_frame: The starting frame for the motion.
        name: A prefix for the duplicated skeleton.
    """
    # Duplicate the source skeleton
    root_grp = pmc.duplicate(skeleton_group, name=f"{name}_{skeleton_group}")
    root_grp = pmc.ls(root_grp)[0]
    root_obj = root_grp.listRelatives(children=True, type="joint")[0]
    joints = _get_hierarchy(root_obj)

    # Get the start and end frames
    start = start_frame
    end = start_frame + root_pos.shape[0] - 1

    print(f"Applying keyframes to '{joints[0].getParent()}' [{start}-{end}]")

    for frame_time in range(start, end + 1):
        frame_idx = frame_time - start
        for joint_idx, joint_name in enumerate(joints):
            # Skip joints that are not part of the mask
            if joint_mask is not None and not joint_mask[frame_idx, joint_idx]:
                continue

            # Apply root position to the root joint
            if joint_idx == 0:
                pmc.setKeyframe(
                    joint_name,
                    time=frame_time,
                    attribute="tx",
                    value=root_pos[frame_idx, 0],
                )
                pmc.setKeyframe(
                    joint_name,
                    time=frame_time,
                    attribute="ty",
                    value=root_pos[frame_idx, 1],
                )
                pmc.setKeyframe(
                    joint_name,
                    time=frame_time,
                    attribute="tz",
                    value=root_pos[frame_idx, 2],
                )

            # Apply joint rotations to the all joints
            pmc.setKeyframe(
                joint_name,
                time=frame_time,
                attribute="rx",
                value=rotations[frame_idx, joint_idx, 0],
            )
            pmc.setKeyframe(
                joint_name,
                time=frame_time,
                attribute="ry",
                value=rotations[frame_idx, joint_idx, 1],
            )
            pmc.setKeyframe(
                joint_name,
                time=frame_time,
                attribute="rz",
                value=rotations[frame_idx, joint_idx, 2],
            )


def import_motions(
    skeleton_group: pmc.nodetypes.Transform,
    root_positions: np.ndarray,
    joint_rotations: np.ndarray,
    start_frame=1,
    name="sample",
):
    """Import the inferred motions onto the skeleton.

    Args:
        root_positions: The root positions for each frame per sample.
        joint_rotations: The joint rotations for each frame per sample.
        start_frame: The starting frame for the motion.
        name: A prefix for the duplicated skeleton.
    """
    for root_pos, rotations in zip(root_positions, joint_rotations):
        _apply_motion(
            skeleton_group,
            np.array(root_pos),
            np.array(rotations),
            start_frame=start_frame,
            name=name,
        )
