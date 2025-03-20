from pathlib import Path

from maya.OpenMayaUI import MQtUtil
from qtpy import QtWidgets
from qtpy.shiboken import wrapInstance
from qtpy.uic import loadUi

from .. import motion_io
from ..qclient import MoLabQClient

maya_win = wrapInstance(int(MQtUtil.mainWindow()), QtWidgets.QWidget)

window = None


class MoLabWindow(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__(parent=maya_win)
        ui_path = Path(__file__).parent / "molab_window.ui"
        loadUi(ui_path.as_posix(), self)
        self.widget_advanced.setVisible(False)
        self.btn_generate.setEnabled(False)
        self.skeleton_valid = False
        self.client = MoLabQClient()
        self.connect_signals()
        self.client.open()

    def connect_signals(self):
        self.client.inference_received.connect(self.on_inference_received)
        self.client.connected.connect(self.on_connect)
        self.client.disconnected.connect(self.on_disconnect)

        self.grp_advanced.toggled.connect(self.widget_advanced.setVisible)
        self.le_backend.textChanged.connect(self.on_backend_changed)
        self.btn_connect.pressed.connect(self.on_connect_pressed)
        self.btn_pick_skeleton.pressed.connect(self.on_pick_skeleton)
        self.btn_generate.pressed.connect(self.on_generate)

    def on_backend_changed(self):
        self.client.close()

    def on_connect_pressed(self):
        self.client.close()
        self.client.backend_uri = self.le_backend.text()
        self.client.open()

    def on_pick_skeleton(self):
        try:
            self.joints = motion_io.get_selected_skeleton_joints()
            self.skeleton_group = self.joints[0].getParent()
            self.le_skeleton.setText(self.joints[0].longName())
            self.skeleton_valid = True
        except ValueError as e:
            QtWidgets.QMessageBox.warning(self, "Warning", str(e))
            self.skeleton_valid = False
        self.update_generate_button()

    def update_generate_button(self):
        generation_enabled = self.skeleton_valid and self.client.is_connected()
        self.btn_generate.setEnabled(generation_enabled)

    def on_generate(self):
        startframe = self.sb_startframe.value()
        endframe = self.sb_endframe.value()

        packed_motion = None
        if self.chkbx_input_motion.isChecked():
            try:
                packed_motion = motion_io.extract_and_pack_keyframes(
                    self.joints, startframe, endframe
                )
            except ValueError as e:
                QtWidgets.QMessageBox.warning(self, "Warning", str(e))
                return

        inference_args = {
            "packed_motion": packed_motion,
            "text_prompt": self.le_prompt.text(),
            "num_samples": self.sb_samples.value(),
            "editable_features": self.cbx_editable_features.currentText(),
            "unpack_mode": self.cbx_unpack_mode.currentText(),
            "unpack_randomness": self.sb_unpack_random.value(),
            "jacobian_ik": self.cbx_ik_method.currentText() == "Jacobian",
            "foot_ik": self.chkbx_foot_ik.isChecked(),
        }

        self.btn_generate.setEnabled(False)
        self.btn_generate.setText("Generating, please wait...")
        self.client.infer(inference_args)

    def on_connect(self):
        print("Connected to MoLab backend!")
        self.btn_connect.setEnabled(False)
        self.btn_connect.setText("Connected")
        self.update_generate_button()

    def on_disconnect(self):
        print("Disconnected from MoLab backend!")
        self.btn_connect.setEnabled(True)
        self.btn_connect.setText("Connect")
        self.update_generate_button()

    def on_inference_received(self, inference_result):
        motion_io.import_motions(
            self.skeleton_group,
            inference_result["root_positions"],
            inference_result["joint_rotations"],
            start_frame=self.sb_startframe.value(),
            name="sample",
        )
        self.btn_generate.setEnabled(True)
        self.btn_generate.setText("Generate")


def show_window():
    global window
    if window is None:
        window = MoLabWindow()
    window.show()
