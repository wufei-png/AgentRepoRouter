# OrchAI

AI coding agent orchestrator.

## Development

### Running Tests
```bash
pytest tests/
```

### Type Checking
```bash
mypy orchai/
```

### Code Formatting
```bash
ruff check orchai/
ruff format orchai/
```

### Full CI Pipeline
```bash
# Run all checks
ruff check orchai/ && ruff format --check orchai/ && mypy orchai/ && pytest tests/
```

## Requirements
- Python 3.10+
