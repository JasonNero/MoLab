# WebSocket Worker

The [`WebSocketWorker`][models.condmdi.molab_condmdi.websocket_worker.WebSocketWorker] encapsulates and serves a single instance of the [`MotionInferenceWorker`][models.condmdi.molab_condmdi.inference_worker.MotionInferenceWorker].

For setup, it requires the `backend_host` and `backend_port`, as well as which `checkpoint` to load for the inference worker.

We plan to add more checkpoints in the future, currently there are only two checkpoints available, both from the original [CondMDI repository](https://github.com/setarehc/diffusion-motion-inbetweening?tab=readme-ov-file#3-download-the-pretrained-models):

- `random_frames` (Default)
    - Trained on in-betweening full poses on random frames.
    - Good for full-body in-betweening.
- `random_joints`
    - Trained on in-betweening random joints (partial poses) on random frames.
    - Good for in-betweening partial poses.

::: models.condmdi.molab_condmdi.websocket_worker
    options:
      heading_level: 2
      show_root_heading: true
      show_source: false
