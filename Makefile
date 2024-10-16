.PHONY: install
install: ## Install the virtual environments for backend and models
	@echo "🚀 Creating virtual environments using uv"
	@cd backend && uv sync
	@cd models/condmdi && uv sync

.PHONY: check
check: ## Run code quality tools.
	@echo "🚀 Checking lock file consistency with 'pyproject.toml'"
	@cd backend && uv sync --locked
	@cd models/condmdi && uv sync --locked
	@echo "🚀 Checking for obsolete dependencies: Running deptry"
	@cd backend && uv run deptry .
	@cd models/condmdi && uv run deptry .

.PHONY: test
test: ## Test the code with pytest
	@echo "🚀 Testing code: Running pytest"
	@cd backend && uv run pytest
	@cd models/condmdi && uv run pytest

.PHONY: build
build: clean-build ## Build wheel file
	@echo "🚀 Creating wheel file"
	@cd backend && uvx --from build pyproject-build --installer uv
	@cd models/condmdi && uvx --from build pyproject-build --installer uv

.PHONY: clean-build
clean-build: ## Clean build artifacts
	@echo "🚀 Removing build artifacts"
	@cd backend && uv run python -c "import shutil; import os; shutil.rmtree('dist') if os.path.exists('dist') else None"
	@cd models/condmdi && uv run python -c "import shutil; import os; shutil.rmtree('dist') if os.path.exists('dist') else None"

.PHONY: run-backend
run-backend: ## Run the backend
	@echo "🚀 Running the backend"
	@cd backend && uv run backend

.PHONY: run-worker
run-worker: ## Run the worker
	@echo "🚀 Running the worker"
	@cd models/condmdi && uv run worker

.PHONY: run-frontend
run-frontend: ## Run the frontend
	@echo "🚀 Running the frontend"
	@cd frontend && echo "TODO"

.PHONY: docs-test
docs-test: ## Test if documentation can be built without warnings or errors
	@uv tool run --with mkdocs-material --with mkdocstrings mkdocs build -s

.PHONY: docs
docs: ## Build and serve the documentation
	@uv tool run --with mkdocs-material --with mkdocstrings mkdocs serve

.PHONY: help
help:
	@uv run python -c "import re; \
	[[print(f'\033[36m{m[0]:<20}\033[0m {m[1]}') for m in re.findall(r'^([a-zA-Z_-]+):.*?## (.*)$$', open(makefile).read(), re.M)] for makefile in ('$(MAKEFILE_LIST)').strip().split()]"

.DEFAULT_GOAL := help
