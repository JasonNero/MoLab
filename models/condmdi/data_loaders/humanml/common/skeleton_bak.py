import warnings
from data_loaders.humanml.common.quaternion import *
import scipy.ndimage.filters as filters
import torch
import numpy as np

class Skeleton(object):
    def __init__(self, offset, kinematic_tree, device):
        self.device = device
        self._raw_offset_np = offset.numpy()
        self._raw_offset = offset.clone().detach().to(device).float()
        self._kinematic_tree = kinematic_tree
        self._offset = None
        self._parents = [0] * len(self._raw_offset)
        self._parents[0] = -1
        for chain in self._kinematic_tree:
            for j in range(1, len(chain)):
                self._parents[chain[j]] = chain[j-1]

    def njoints(self):
        return len(self._raw_offset)

    def offset(self):
        return self._offset

    def set_offset(self, offsets):
        self._offset = offsets.clone().detach().to(self.device).float()

    def kinematic_tree(self):
        return self._kinematic_tree

    def parents(self):
        return self._parents

    # joints (batch_size, joints_num, 3)
    def get_offsets_joints_batch(self, joints):
        assert len(joints.shape) == 3
        _offsets = self._raw_offset.expand(joints.shape[0], -1, -1).clone()
        for i in range(1, self._raw_offset.shape[0]):
            _offsets[:, i] = torch.norm(joints[:, i] - joints[:, self._parents[i]], p=2, dim=1)[:, None] * _offsets[:, i]

        self._offset = _offsets.detach()
        return _offsets

    # joints (joints_num, 3)
    def get_offsets_joints(self, joints):
        assert len(joints.shape) == 2
        _offsets = self._raw_offset.clone()
        for i in range(1, self._raw_offset.shape[0]):
            # print(joints.shape)
            _offsets[i] = torch.norm(joints[i] - joints[self._parents[i]], p=2, dim=0) * _offsets[i]

        self._offset = _offsets.detach()
        return _offsets

    # face_joint_idx should follow the order of right hip, left hip, right shoulder, left shoulder
    # joints (batch_size, joints_num, 3)
    def inverse_kinematics_np(self, joints, face_joint_idx, smooth_forward=False, fixed=False):
        assert len(face_joint_idx) == 4
        '''Get Forward Direction'''
        if not fixed:
            warnings.warn("Using legacy/incorrect order of face_joint_idx", RuntimeWarning, stacklevel=2)
            # Original but wrong order
            # see https://github.com/EricGuo5513/HumanML3D/issues/119
            l_hip, r_hip, sdr_r, sdr_l = face_joint_idx
        else:
            r_hip, l_hip, sdr_r, sdr_l = face_joint_idx

        across1 = joints[:, r_hip] - joints[:, l_hip]
        across2 = joints[:, sdr_r] - joints[:, sdr_l]
        across = across1 + across2
        across = across / np.sqrt((across**2).sum(axis=-1))[:, np.newaxis]
        # print(across1.shape, across2.shape)

        # forward (batch_size, 3)
        forward = np.cross(np.array([[0, 1, 0]]), across, axis=-1)
        if smooth_forward:
            forward = filters.gaussian_filter1d(forward, 20, axis=0, mode='nearest')
            # forward (batch_size, 3)
        forward = forward / np.sqrt((forward**2).sum(axis=-1))[..., np.newaxis]

        '''Get Root Rotation'''
        target = np.array([[0,0,1]]).repeat(len(forward), axis=0)
        root_quat = qbetween_np(forward, target)

        '''Inverse Kinematics'''
        # quat_params (batch_size, joints_num, 4)
        # print(joints.shape[:-1])
        quat_params = np.zeros(joints.shape[:-1] + (4,))
        # print(quat_params.shape)
        root_quat[0] = np.array([[1.0, 0.0, 0.0, 0.0]])
        quat_params[:, 0] = root_quat
        # quat_params[0, 0] = np.array([[1.0, 0.0, 0.0, 0.0]])
        for chain in self._kinematic_tree:
            if not fixed:
                warnings.warn("Using legacy/incorrect starting rotation for arm chains", RuntimeWarning, stacklevel=2)
                # Original but incorrect starting rotation for arm chains
                # see https://github.com/EricGuo5513/HumanML3D/issues/119
                R = root_quat
            else:
                R = quat_params[:, chain[0]]
            for j in range(len(chain) - 1):
                parent_idx = chain[j]
                joint_idx = chain[j+1]

                # (batch, 3)
                u = self._raw_offset_np[joint_idx][np.newaxis,...].repeat(len(joints), axis=0)
                # print(u.shape)
                # (batch, 3)
                v = joints[:, joint_idx] - joints[:, parent_idx]
                v = v / np.sqrt((v**2).sum(axis=-1))[:, np.newaxis]
                # print(u.shape, v.shape)
                rot_u_v = qbetween_np(u, v)

                R_loc = qmul_np(qinv_np(R), rot_u_v)

                quat_params[:, joint_idx, :] = R_loc
                R = qmul_np(R, R_loc)

        return quat_params

    # Be sure root joint is at the beginning of kinematic chains
    def forward_kinematics(self, quat_params, root_pos, skel_joints=None, do_root_R=True):
        # quat_params (batch_size, joints_num, 4)
        # joints (batch_size, joints_num, 3)
        # root_pos (batch_size, 3)
        if skel_joints is not None:
            offsets = self.get_offsets_joints_batch(skel_joints)
        if len(self._offset.shape) == 2:
            offsets = self._offset.expand(quat_params.shape[0], -1, -1)
        joints = torch.zeros(quat_params.shape[:-1] + (3,)).to(self.device)
        joints[:, 0] = root_pos
        for chain in self._kinematic_tree:
            if do_root_R:
                R = quat_params[:, 0]
            else:
                R = torch.tensor([[1.0, 0.0, 0.0, 0.0]]).expand(len(quat_params), -1).detach().to(self.device)
            for i in range(1, len(chain)):
                R = qmul(R, quat_params[:, chain[i]])
                offset_vec = offsets[:, chain[i]]
                joints[:, chain[i]] = qrot(R, offset_vec) + joints[:, chain[i-1]]
        return joints

    # Be sure root joint is at the beginning of kinematic chains
    def forward_kinematics_np(self, quat_params, root_pos, skel_joints=None, do_root_R=True):
        # quat_params (batch_size, joints_num, 4)
        # joints (batch_size, joints_num, 3)
        # root_pos (batch_size, 3)
        if skel_joints is not None:
            skel_joints = torch.from_numpy(skel_joints)
            offsets = self.get_offsets_joints_batch(skel_joints)
        if len(self._offset.shape) == 2:
            offsets = self._offset.expand(quat_params.shape[0], -1, -1)
        offsets = offsets.numpy()
        joints = np.zeros(quat_params.shape[:-1] + (3,))
        joints[:, 0] = root_pos
        for chain in self._kinematic_tree:
            if do_root_R:
                R = quat_params[:, 0]
            else:
                R = np.array([[1.0, 0.0, 0.0, 0.0]]).repeat(len(quat_params), axis=0)
            for i in range(1, len(chain)):
                R = qmul_np(R, quat_params[:, chain[i]])
                offset_vec = offsets[:, chain[i]]
                joints[:, chain[i]] = qrot_np(R, offset_vec) + joints[:, chain[i - 1]]
        return joints

    def forward_kinematics_cont6d_np(self, cont6d_params, root_pos, skel_joints=None, do_root_R=True):
        # cont6d_params (batch_size, joints_num, 6)
        # joints (batch_size, joints_num, 3)
        # root_pos (batch_size, 3)
        if skel_joints is not None:
            skel_joints = torch.from_numpy(skel_joints)
            offsets = self.get_offsets_joints_batch(skel_joints)
        if len(self._offset.shape) == 2:
            offsets = self._offset.expand(cont6d_params.shape[0], -1, -1)
        offsets = offsets.numpy()
        joints = np.zeros(cont6d_params.shape[:-1] + (3,))
        joints[:, 0] = root_pos
        for chain in self._kinematic_tree:
            if do_root_R:
                matR = cont6d_to_matrix_np(cont6d_params[:, 0])
            else:
                matR = np.eye(3)[np.newaxis, :].repeat(len(cont6d_params), axis=0)
            for i in range(1, len(chain)):
                matR = np.matmul(matR, cont6d_to_matrix_np(cont6d_params[:, chain[i]]))
                offset_vec = offsets[:, chain[i]][..., np.newaxis]
                # print(matR.shape, offset_vec.shape)
                joints[:, chain[i]] = np.matmul(matR, offset_vec).squeeze(-1) + joints[:, chain[i-1]]
        return joints

    def forward_kinematics_cont6d(self, cont6d_params, root_pos, skel_joints=None, do_root_R=True):
        # cont6d_params (batch_size, joints_num, 6)
        # joints (batch_size, joints_num, 3)
        # root_pos (batch_size, 3)
        if skel_joints is not None:
            # skel_joints = torch.from_numpy(skel_joints)
            offsets = self.get_offsets_joints_batch(skel_joints)
        if len(self._offset.shape) == 2:
            offsets = self._offset.expand(cont6d_params.shape[0], -1, -1)
        joints = torch.zeros(cont6d_params.shape[:-1] + (3,)).to(cont6d_params.device)
        joints[..., 0, :] = root_pos
        for chain in self._kinematic_tree:
            if do_root_R:
                matR = cont6d_to_matrix(cont6d_params[:, 0])
            else:
                matR = torch.eye(3).expand((len(cont6d_params), -1, -1)).detach().to(cont6d_params.device)
            for i in range(1, len(chain)):
                matR = torch.matmul(matR, cont6d_to_matrix(cont6d_params[:, chain[i]]))
                offset_vec = offsets[:, chain[i]].unsqueeze(-1)
                # print(matR.shape, offset_vec.shape)
                joints[:, chain[i]] = torch.matmul(matR, offset_vec).squeeze(-1) + joints[:, chain[i-1]]
        return joints








###############################################################################
# Fixed versions of IK and FK functions
# - Use correct order of face_joint_idx (IK)
# - Switch order of rotation and translation to be compatible with DCCs (IK&FK)
###############################################################################


    # face_joint_idx should follow the order of right hip, left hip, right shoulder, left shoulder
    # joints (batch_size, joints_num, 3)
    def inverse_kinematics_quat_standard_np(self, global_pos, face_joint_idx, smooth_forward=False):
        assert len(face_joint_idx) == 4

        '''Get Forward Direction'''
        r_hip, l_hip, sdr_r, sdr_l = face_joint_idx
        across1 = global_pos[:, r_hip] - global_pos[:, l_hip]
        across2 = global_pos[:, sdr_r] - global_pos[:, sdr_l]
        across = across1 + across2
        across = across / np.sqrt((across**2).sum(axis=-1))[:, np.newaxis]

        forward = np.cross(np.array([[0, 1, 0]]), across, axis=-1)
        if smooth_forward:
            forward = filters.gaussian_filter1d(forward, 20, axis=0, mode='nearest')

        forward = forward / np.sqrt((forward**2).sum(axis=-1))[..., np.newaxis]

        '''Get Root Rotation'''
        target = np.array([[0,0,1]]).repeat(len(forward), axis=0)
        root_quat = qbetween_np(forward, target)

        '''Inverse Kinematics'''
        # local_quat (batch_size, joints_num, 4)
        local_quat = np.zeros(global_pos.shape[:-1] + (4,))

        # The preprocessing for the dataset aligns the first frame exactly to Z+
        root_quat[0] = np.array([[1.0, 0.0, 0.0, 0.0]])
        local_quat[:, 0] = root_quat

        global_quat = np.zeros(global_pos.shape[:-1] + (4,))
        global_quat[..., 0, :] = root_quat

        for chain in self._kinematic_tree:
            for i in range(1, len(chain)):
                j = chain[i]
                p = chain[i-1]

                # Get the offset vector for the current joint
                joint_offset_vector = self._raw_offset_np[j]
                joint_offset_vector = joint_offset_vector[np.newaxis,...].repeat(len(global_pos), axis=0)

                # Calculate the current joint vector
                joint_vector = global_pos[:, j] - global_pos[:, p]
                joint_vector = joint_vector / np.sqrt((joint_vector**2).sum(axis=-1))[:, np.newaxis]

                # Calculate the rotation between them
                quat_between = qbetween_np(joint_offset_vector, joint_vector)

                # To actually get the local rotation, we need to multiply by
                # the inverse of the parent's global rotation
                local_quat[:, j] = qmul_np(qinv_np(global_quat[:, p]), quat_between)

                # Update the global rotation for the current joint
                global_quat[:, j] = qmul_np(global_quat[:, p], local_quat[:, j])

        return local_quat


    def forward_kinematics_cont6d_standard(
            self, cont6d_params, root_pos, skel_joints=None
        ):
        # cont6d_params (batch_size, joints_num, 6)
        # joints (batch_size, joints_num, 3)
        # root_pos (batch_size, 3)
        if skel_joints is not None:
            # skel_joints = torch.from_numpy(skel_joints)
            offsets = self.get_offsets_joints_batch(skel_joints)
        if len(self._offset.shape) == 2:
            offsets = self._offset.expand(cont6d_params.shape[0], -1, -1)

        global_pos = torch.zeros(cont6d_params.shape[:-1] + (3,1)).to(cont6d_params.device)
        global_rot = torch.zeros(cont6d_params.shape[:-1] + (3,3)).to(cont6d_params.device)

        global_pos[..., 0, :, :] = root_pos.unsqueeze(-1)  # convert to column vector
        global_rot[..., 0, :, :] = cont6d_to_matrix(cont6d_params[:, 0])

        # for reference, the t2m kinematic tree is as follows:
        # [[0, 2, 5, 8, 11], [0, 1, 4, 7, 10], [0, 3, 6, 9, 12, 15], [9, 14, 17, 19, 21], [9, 13, 16, 18, 20]]

        for chain in self._kinematic_tree:
            for i in range(1, len(chain)):
                j = chain[i]
                p = chain[i-1]

                local_pos = offsets[:, j].unsqueeze(-1)  # convert to column vector
                local_rot = cont6d_to_matrix(cont6d_params[:, j])

                global_pos[:, j] = global_rot[:, p] @ local_pos + global_pos[:, p]
                global_rot[:, j] = global_rot[:, p] @ local_rot

        return global_pos.squeeze(-1), global_rot


    def forward_kinematics_quat_standard(self, quat_params, root_pos, skel_joints=None):
        # quat_params (batch_size, joints_num, 4)
        # joints (batch_size, joints_num, 3)
        # root_pos (batch_size, 3)
        if skel_joints is not None:
            skel_joints = torch.from_numpy(skel_joints)
            offsets = self.get_offsets_joints_batch(skel_joints)
        if len(self._offset.shape) == 2:
            offsets = self._offset.expand(quat_params.shape[0], -1, -1)

        global_pos = torch.zeros(quat_params.shape[:-1] + (3,1))
        global_rot = torch.zeros(quat_params.shape[:-1] + (3,3))

        global_pos[..., 0, :, :] = root_pos[..., None]
        global_rot[..., 0, :, :] = quaternion_to_matrix(quat_params[:, 0])

        for chain in self._kinematic_tree:
            for i in range(1, len(chain)):
                j = chain[i]
                p = chain[i-1]

                local_pos = offsets.unsqueeze(-1)[:, j].numpy()
                local_rot = quaternion_to_matrix(quat_params[:, j])

                global_pos[:, j] = global_rot[:, p] @ local_pos + global_pos[:, p]
                global_rot[:, j] = global_rot[:, p] @ local_rot

        return global_pos.squeeze(-1)


    def forward_kinematics_quat_standard_np(self, quat_params, root_pos, skel_joints=None):
        # quat_params (batch_size, joints_num, 4)
        # joints (batch_size, joints_num, 3)
        # root_pos (batch_size, 3)
        if skel_joints is not None:
            skel_joints = np.from_numpy(skel_joints)
            offsets = self.get_offsets_joints_batch(skel_joints)
        if len(self._offset.shape) == 2:
            offsets = self._offset.expand(quat_params.shape[0], -1, -1)

        global_pos = np.zeros(quat_params.shape[:-1] + (3,1))
        global_rot = np.zeros(quat_params.shape[:-1] + (3,3))

        global_pos[..., 0, :, :] = root_pos[..., None]
        global_rot[..., 0, :, :] = quaternion_to_matrix_np(quat_params[:, 0])

        for chain in self._kinematic_tree:
            for i in range(1, len(chain)):
                j = chain[i]
                p = chain[i-1]

                local_pos = offsets.unsqueeze(-1)[:, j].numpy()
                local_rot = quaternion_to_matrix_np(quat_params[:, j])

                global_pos[:, j] = global_rot[:, p] @ local_pos + global_pos[:, p]
                global_rot[:, j] = global_rot[:, p] @ local_rot

        return global_pos.squeeze(-1)


    # Conversion function to standardize rotation
    def convert_to_standard_convention_rotation(self, non_standard_rotmats):
        # Convert the non-standard rotations to the standard convention
        # The original code does translation-first:     x' = (x + t) * R
        # The standard convention rotation-first:       x' = R * x + t
        standard_rotmats = torch.eye(3).repeat(*non_standard_rotmats.shape[:-2], 1, 1).to(non_standard_rotmats.device)
        standard_rotmats[:, 0, :, :] = non_standard_rotmats[:, 0, :, :]
        for chain in self._kinematic_tree:
            # Start from the root joint
            for j in range(1, len(chain)):
                parent_joint_idx = chain[j - 1]
                current_joint_idx = chain[j]

                # Non-standard local rotation of the current joint
                R_loc_non_standard = non_standard_rotmats[:, current_joint_idx]

                # Parent's global rotation matrix
                R_parent_global = standard_rotmats[:, parent_joint_idx]

                # Standard local rotation is the product of the inverse of the parent's global rotation
                # and the current non-standard local rotation
                R_standard_local = R_parent_global.mT @ R_loc_non_standard

                # Update the rotation matrix to the standard local rotation
                standard_rotmats[:, current_joint_idx, :, :] = R_standard_local

        return standard_rotmats


    # def convert_to_standard_convention_rotation_inplace(self, rot_params):
    # # Convert the non-standard local rotation matrices to standard local rotations
    #     for chain in self._kinematic_tree:
    #         # Start from the root joint
    #         for j in range(1, len(chain)):
    #             parent_joint_idx = chain[j - 1]
    #             current_joint_idx = chain[j]

    #             # Non-standard local rotation of the current joint
    #             R_loc_non_standard = rot_params[:, current_joint_idx]

    #             # Parent's global rotation matrix
    #             R_parent_global = rot_params[:, parent_joint_idx]

    #             # Standard local rotation is the product of the inverse of the parent's global rotation
    #             # and the current non-standard local rotation
    #             R_standard_local = R_parent_global.mT @ R_loc_non_standard

    #             # Update the rotation matrix to the standard local rotation
    #             rot_params[:, current_joint_idx, :, :] = R_standard_local

    #     return rot_params


    # def convert_to_rotation_first(self, quat_params):
    #     """
    #     Converts quaternions from translation-first convention to rotation-first convention.

    #     Parameters:
    #         quat_params (torch.Tensor): Original quaternion parameters of shape (batch_size, joints_num, 4).
    #         kinematic_tree (list of lists): The kinematic tree structure where each sublist represents a chain.

    #     Returns:
    #         torch.Tensor: Converted quaternion parameters of shape (batch_size, joints_num, 4).
    #     """
    #     # Initialize the converted quaternions
    #     converted_quat_params = torch.zeros_like(quat_params)

    #     # Iterate over each chain in the kinematic tree
    #     for chain in self._kinematic_tree:
    #         # Initialize the root rotation for the chain
    #         converted_quat_params[:, chain[0]] = quat_params[:, chain[0]]

    #         # Convert the rotations for each subsequent joint in the chain
    #         for i in range(1, len(chain)):
    #             # Multiply the previous quaternion with the current one
    #             converted_quat_params[:, chain[i]] = qmul(converted_quat_params[:, chain[i-1]], quat_params[:, chain[i]])

    #     return converted_quat_params


    # def convert_to_rotation_first_matrices(self, rot_mat_params):
    #     """
    #     Converts rotation matrices from translation-first convention to rotation-first convention.

    #     Parameters:
    #         rot_mat_params (torch.Tensor): Original rotation matrices of shape (batch_size, joints_num, 3, 3).
    #         kinematic_tree (list of lists): The kinematic tree structure where each sublist represents a chain.

    #     Returns:
    #         torch.Tensor: Converted rotation matrices of shape (batch_size, joints_num, 3, 3).
    #     """
    #     # Initialize the converted rotation matrices
    #     converted_rot_mat_params = torch.zeros_like(rot_mat_params)
    #     converted_rot_mat_params[:, 0] = rot_mat_params[:, 0]

    #     # Iterate over each chain in the kinematic tree
    #     for chain in self._kinematic_tree:
    #         # Initialize the root rotation for the chain

    #         # Convert the rotations for each subsequent joint in the chain
    #         for i in range(1, len(chain)):
    #             # Multiply the previous rotation matrix with the current one
    #             converted_rot_mat_params[:, chain[i]] = converted_rot_mat_params[:, chain[i-1]] @ rot_mat_params[:, chain[i]]

    #     return converted_rot_mat_params
