# Using the MoLab Plugin for Maya

The Maya Plugin serves a similar functionality like the MoLab Sequencer, but is focused more on in-betweening than on generating animations from scratch.
It is aimed at animators who want to speed up their workflow by generating in-betweens for key poses.

## Setup

To use the MoLab Maya Plugin, you need to install it first (see the [installation guide](../getting-started/installation.md)).
Then you can start up the UI using the snippet in `dcc/maya_shelf_script.py` in the Maya Script Editor. Feel free to add this script to your shelf for easy access.

## Usage

The basic workflow is as follows:

- Provide a backend URI
- Select the Hip bone of the skeleton and hit the "Pick" button
- Decide whether to use input motion and if so, provide start and end frames
- Decide whether to use a text prompt or not
- Finally supply the amount of samples and hit the "Generate" button

There are also advanced options available, which are explained further in the [Inference Parameter Guide](inference-parameters.md).

![Advanced Options of the MoLab Maya Plugin](../assets/MoLab_maya_plugin_advanced.png)
