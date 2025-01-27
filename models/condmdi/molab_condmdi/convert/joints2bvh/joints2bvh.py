import sys
from pathlib import Path

import numpy as np
import tqdm

from . import BVH, Animation
from .InverseKinematics import BasicInverseKinematics, BasicJacobianIK
from .Quaternions import Quaternions
from .remove_fs import remove_fs

template_path = Path(__file__).parent / "data" / "template.bvh"

re_order = [0, 1, 4, 7, 10, 2, 5, 8, 11, 3, 6, 9, 12, 15, 13, 16, 18, 20, 14, 17, 19, 21]
re_order_inv = [0, 1, 5, 9, 2, 6, 10, 3, 7, 11, 4, 8, 12, 14, 18, 13, 15, 19, 16, 20, 17, 21]


class Joint2BVHConvertor:
    def __init__(self):
        self.template = BVH.load(template_path, need_quater=True)

        self.end_points = [4, 8, 13, 17, 21]
        self.parents = [-1, 0, 1, 2, 3, 0, 5, 6, 7, 0, 9, 10, 11, 12, 11, 14, 15, 16, 11, 18, 19, 20]

    def convert(self, positions, filename, iterations=10, foot_ik=True, use_jacobian=False):
        '''
        Convert the SMPL joint positions to Mocap BVH
        :param positions: (N, 22, 3)
        :param filename: Save path for resulting BVH
        :param iterations: iterations for optimizing rotations, 10 is usually enough
        :param foot_ik: whether to enforce foot inverse kinematics, removing foot slide issue.
        :param use_jacobian: whether to use JacobianIK solver instead of BasicIK.
        :return:
        '''
        positions = positions[:, re_order]
        new_anim = self.template.copy()
        new_anim.rotations = Quaternions.id(positions.shape[:-1])
        new_anim.positions = new_anim.positions[0:1].repeat(positions.shape[0], axis=-0)
        new_anim.positions[:, 0] = positions[:, 0]

        if foot_ik:
            positions = remove_fs(positions, None, fid_l=(3, 4), fid_r=(7, 8), interp_length=5,
                                  force_on_floor=True)
        if use_jacobian:
            ik_solver = BasicJacobianIK(new_anim, positions, iterations=iterations, silent=True)
        else:
            ik_solver = BasicInverseKinematics(new_anim, positions, iterations=iterations, silent=True)
        new_anim = ik_solver()

        glb = Animation.positions_global(new_anim)[:, re_order_inv]
        if filename is not None:
            BVH.save(filename, new_anim, names=new_anim.names, frametime=1 / 20, order='zyx', quater=True)
        return new_anim, glb


if __name__ == "__main__":
    path = Path(sys.argv[1])
    if not path.is_file():
        raise FileNotFoundError(f"File {path} not found.")

    results = np.load(path, allow_pickle=True).item()
    motion = results["motion"]

    print(f"Loaded results from '{path.parent.name}'")
    print(f"Motion shape: {motion.shape}")

    converter = Joint2BVHConvertor()

    for i_rep in tqdm.trange(results["num_repetitions"], position=0, desc="Repetitions"):
        for i_sample in tqdm.trange(results["num_samples"], position=1, desc="Samples"):
            joints = motion[i_rep, i_sample].transpose(2, 0, 1)  # (J, 3, F) -> (F, J, 3)

            file_name = f"sample{i_sample:02d}_rep{i_rep:02d}"
            bvh_path = path.parent / (file_name + ".bvh")
            bvh_ik_path = path.parent / (file_name + "_ik.bvh")

            new_anim = converter.convert(joints, bvh_path, foot_ik=False)
            new_anim = converter.convert(joints, bvh_ik_path, foot_ik=True)

    print("Conversion complete.")
