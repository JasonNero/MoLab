# MoLab: Motion Lab

[![Release](https://img.shields.io/github/v/release/JasonNero/MoLab)](https://img.shields.io/github/v/release/JasonNero/MoLab)
[![Build status](https://img.shields.io/github/actions/workflow/status/JasonNero/MoLab/main.yml?branch=main)](https://github.com/JasonNero/MoLab/actions/workflows/main.yml?query=branch%3Amain)
[![Commit activity](https://img.shields.io/github/commit-activity/m/JasonNero/MoLab)](https://img.shields.io/github/commit-activity/m/JasonNero/MoLab)
[![License](https://img.shields.io/github/license/JasonNero/MoLab)](https://img.shields.io/github/license/JasonNero/MoLab)

> A toolbox for **human motion generation and inbetweening**, developed during the [Kollani](https://ai.hdm-stuttgart.de/research/kollani/) project.

- **Github repository**: <https://github.com/JasonNero/MoLab/>
- **Documentation** <https://JasonNero.github.io/MoLab/>


## Overview

```
MoLab/
├── backend/            # FastAPI WebSocket endpoint for inference
├── models/condmdi/     # CondMDI fork with new features and improvements
├── frontend/           # Godot User Interface for MoLab Sequencer
├── experiments/        # Notebooks/scripts for experiments and demos
├── dcc/                # DCC plugins (Maya, Blender, etc.)
├── tests/              # System-level tests involving all components
├── docs/               # Documentation for the project
├── Makefile            # Automate build/test tasks across components
└── README.md           # Project description and setup instructions
```

## Getting started

1. Make sure the `uv` package manager is installed on your system. If not, follow the instructions [here](https://docs.astral.sh/uv/)
2. Run `make install` to setup the backend and model environments
3. Run `make run-backend` to start the FastAPI server
4. Run `make run-worker` to start the Inference worker
5. Run `make run-frontend` to start the Godot frontend

See `make help` for a list of available commands.

## Acknowledgements

## License
