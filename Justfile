# Display help for the tasks in the justfile
help:
  @echo "Available tasks:"
  @echo "  install        - Create virtual environments"
  @echo "  download       - Download required models and checkpoints"
  @echo "  check          - Run code quality tools"
  @echo "  test           - Run pytest tests"
  @echo "  build          - Build the wheel file"
  @echo "  clean-build    - Clean build artifacts"
  @echo "  run-backend    - Run the backend"
  @echo "  run-worker     - Run the worker"
  @echo "  run-frontend   - Run the frontend"
  @echo "  docs-test      - Test if documentation can be built"
  @echo "  docs           - Build and serve the documentation locally"
  @echo "  docs-ghdeploy  - Build and serve the documentation on GitHub Pages"

# Install virtual environments for backend and models
install:
  @echo "🚀 Creating virtual environments using uv"
  @cd backend && uv sync
  @cd models/condmdi && uv sync

# Download the required models and checkpoints
download:
  @echo "🚀 Downloading the required checkpoints"
  @cd models/condmdi/molab_condmdi && uv run bash prepare/download_pretrained.sh
  @cd models/condmdi/molab_condmdi && uv run bash prepare/download_glove.sh

# Run code quality tools
check:
  @echo "🚀 Checking lock file consistency with 'pyproject.toml'"
  @cd backend && uv sync --locked
  @cd models/condmdi && uv sync --locked
  @echo "🚀 Checking for obsolete dependencies: Running deptry"
  @cd backend && uv run deptry .
  @cd models/condmdi && uv run deptry -nb .

# Test the code with pytest
test:
  @echo "🚀 Testing code: Running pytest"
  @cd backend && uv run pytest
  @cd models/condmdi && uv run pytest

# Build wheel file
build:
  @clean-build
  @echo "🚀 Creating wheel file"
  @cd backend && uvx --from build pyproject-build --installer uv
  @cd models/condmdi && uvx --from build pyproject-build --installer uv

# Clean build artifacts
clean-build:
  @echo "🚀 Removing build artifacts"
  @cd backend && uv run python -c "import shutil; import os; shutil.rmtree('dist') if os.path.exists('dist') else None"
  @cd models/condmdi && uv run python -c "import shutil; import os; shutil.rmtree('dist') if os.path.exists('dist') else None"

# Run the backend
run-backend:
  @echo "🚀 Running the backend"
  @cd backend && uv run backend

# Run the worker
run-worker:
  @echo "🚀 Running the worker"
  @cd models/condmdi && uv run worker

# Run the frontend
# run-frontend:
#   @echo "🚀 Running the frontend"
#   @cd frontend/export && ./molab.dmg

# Test if documentation can be built without warnings or errors
docs-test:
  @echo "🚀 Testing documentation build"
  @uv tool run --with mkdocs-material --with mkdocstrings-python --with mkdocs-include-markdown-plugin --with mkdocs-github-admonitions-plugin mkdocs build -s

# Build and serve the documentation locally
docs:
  @echo "🚀 Serving documentation"
  @uv tool run --with mkdocs-material --with mkdocstrings-python --with mkdocs-include-markdown-plugin --with mkdocs-github-admonitions-plugin mkdocs serve -a localhost:8001

# Build and serve the documentation on GitHub Pages
[confirm]
docs-ghdeploy:
  @echo "🚀 Serving documentation"
  @uv tool run --with mkdocs-material --with mkdocstrings-python --with mkdocs-include-markdown-plugin --with mkdocs-github-admonitions-plugin mkdocs gh-deploy --force
