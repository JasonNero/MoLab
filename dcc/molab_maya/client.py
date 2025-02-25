import json

from websockets.sync.client import connect


class MoLabClient:
    """
    A client for interacting with the MoLab backend for motion inference.
    """

    def __init__(self, backend_uri="ws://localhost:8000"):
        """
        Initializes the MoLabClient with the given backend URI.

        Args:
            backend_uri (str): The URI of the MoLab backend server.
        """
        self.backend_uri = backend_uri

    def infer(self, data):
        """
        Sends an inference request to the backend and returns the result.

        Args:
            data (dict): The data to be sent for inference.

        Returns:
            dict: The result of the inference.
        """
        data["type"] = "infer"
        with connect(f"{self.backend_uri}/register_client", max_size=2**21) as websocket:
            print(f"Sending inference dict:\n{data}")
            websocket.send(json.dumps(data))
            print("Waiting for response...")
            message = websocket.recv()
            result = json.loads(message)
            print(f"Received:\n{result}")
        return result

    def infer_and_import(
        self, inference_args, start_frame=1, name="sample", import_observed=False
    ):
        """
        Sends an inference request and directly imports the results onto the skeleton.

        Args:
            inference_args (dict): The arguments for the inference request.
            start_frame (int): The starting frame for the motion.
            name (str): The name for the imported motion.
            import_observed (bool): Whether to also import the input motion.
                (For debugging purposes)
        """
        inference_result = self.infer(inference_args)
        from . import motion_io

        motion_io.import_motions(
            inference_result["root_positions"],
            inference_result["joint_rotations"],
            start_frame=start_frame,
            name=name,
        )

        if import_observed:
            motion_io.import_motions(
                inference_result["obs_root_positions"][:1],
                inference_result["obs_joint_rotations"][:1],
                start_frame=0,
                name=f"{name}_input",
            )
