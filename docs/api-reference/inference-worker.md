# Inference Worker

The [`MotionInferenceWorker`][models.condmdi.molab_condmdi.inference_worker.MotionInferenceWorker] is the core of MoLab's inference system.
It is responsible for generating motion sequences based on the given inference parameters as defined in the [`InferenceArgs`][models.condmdi.molab_condmdi.inference_worker.InferenceArgs].
The output is defined by the [`InferenceResults`][models.condmdi.molab_condmdi.inference_worker.InferenceResults] and contains both the input and output motion sequences.

As underlying motion generation model we use a fork of [`setarehc/diffusion-motion-inbetweening`](https://github.com/setarehc/diffusion-motion-inbetweening) aka [CondMDI](https://setarehc.github.io/CondMDI/).

::: models.condmdi.molab_condmdi.inference_worker
    options:
      heading_level: 2
      show_root_heading: true
      show_source: false
