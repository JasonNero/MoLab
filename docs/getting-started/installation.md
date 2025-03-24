# Installing MoLab

## Prerequisites

Before you begin, ensure you have the following installed:

=== "macOS and Linux"
    - [**uv**](https://docs.astral.sh/uv/getting-started/installation/) as Python Package Manager
    - [**Godot Engine 4**](https://godotengine.org) for the Frontend
    - [**just**](https://github.com/casey/just) as Command Runner
        - can be installed via `uv tool install rust-just`

=== "Windows"
    - [**uv**](https://docs.astral.sh/uv/getting-started/installation/) as Python Package Manager
    - [**Godot Engine 4**](https://godotengine.org) for the Frontend
    - [**just**](https://github.com/casey/just) as Command Runner
        - can be installed via `uv tool install rust-just`
    - **bash** (or any other shell) for the scripts downloading the pretrained models

## Installing Backend and Worker

First clone the MoLab repository:

```console
git clone https://github.com/JasonNero/MoLab.git
```

Then run the `install` task to setup the python environments followed by the `download` task to download the pretrained model checkpoints:

```console
cd MoLab
just install
just download
```

## Installing a Client

With the backend and worker set up, you can now install a client to connect to the backend. You have two options here: the frontend built with Godot or the Maya plugin.

### Building the Sequencer

MoLab Sequencer is using Mixamo characters for visualization.
Due to license restrictions, this repository does not distribute the required 3D character model.

First, please download the "Akai e espiritu" model from the [Mixamo Website](https://www.mixamo.com/#/?page=1&query=akai&type=Character) and save it under `frontend/res/models/akai_e_espiritu.fbx`.

Then you can open the `frontend` project in Godot and re-import the model by double-clicking the `akai_e_espiritu.fbx` file in the "File System" tab and hitting "Reimport".

Finally, you can either run from the editor or export the project to a standalone application.

> [!HINT]
> You might need to reset any changes to the `akai_e_espiritu.fbx.import` file since Godot might have changed the import settings if you started Godot before downloading the model.

### Installing the Maya Plugin

=== "macOS"

    First install the `qtpy` package via `pip` using Maya's Python interpreter, make sure to adapt the path to your Maya version:

    ```console
    /Applications/Autodesk/maya2024/Maya.app/Contents/bin/mayapy -m pip install qtpy
    ```

    Then copy the `dcc/molab_maya` folder to the Maya scripts directory, again adapt the path to your Maya version:

    ```console
    cp -r dcc/molab_maya ~/Library/Preferences/Autodesk/maya/2024/scripts
    ```

=== "Windows"

    First install the `qtpy` package via `pip` using Maya's Python interpreter, make sure to adapt the path to your Maya version:

    ```console
    "C:\Program Files\Autodesk\Maya2024\bin\mayapy.exe" -m pip install qtpy
    ```

    Then copy the `dcc/molab_maya` folder to the Maya scripts directory, again adapt the path to your Maya version:

    ```console
    cp -r dcc/molab_maya "C:\Users\%USERNAME%\Documents\maya\scripts"
    ```

## Next Steps

See the [First Steps](first-steps.md) guide to learn how to spin up the backend and worker, and how connect to the clients.
