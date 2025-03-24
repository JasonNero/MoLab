# Welcome to MoLab's documentation!

<div align="center">
  <img src="assets/MoLab_demo.gif" alt="MoLab Demo" style="max-width: 80%; height: auto;" />
</div>

## Overview

Motion Lab (MoLab) is an innovative framework that supports producers and animators in the pre-production of character animations through machine learning. Traditional animation and motion capture are often time-consuming or have specific limitations, which is why MoLab envisions translating text descriptions into animated sequences and editing existing sequences. By utilizing the CondMDI model, efficient and consistent generation of movements is enabled. The layer-based concept of the MoLab Sequencer allows for intuitive and non-destructive work with both hand-animated and generated motion sequences.

### Features

- **Text To Motion**: Describe the motion you want to see
- **In-Betweening**: Input your keyposes and let AI fill the gaps
- **Motion Composition**: Compose sequences and generate transitions

### Limitations

- Fixed skeleton with 22 joints
- Maximum sequence length of 196 frames and a fixed framerate of 20 Hz
- Text conditioning is limited to the entire sequence and the entire body

## Next Steps

See the [Installation Guide](getting-started/installation.md) to set up the backend and worker components.
