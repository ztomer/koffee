# Agent Guidelines for Koffee

Koffee is a Python project for calculating optimal caffeine intake. It has both CLI (`koffee_cli.py`) and UI (`koffee_ui.py`, PyQt6) versions. Core logic is in `koffee_core.py`.

## Build/Lint/Test Commands

### Running the CLI
```bash
python koffee_cli.py
```

### Running the UI
```bash
python koffee_ui.py
```

### Installing Dependencies
```bash
pip install -r requirements.txt
```

### Linting
Use `ruff` for linting and formatting:
```bash
ruff check .
ruff format .
```

### Type Checking
Use `mypy` for type checking:
```bash
mypy koffee_core.py koffee_cli.py koffee_ui.py
```

### Running Tests
This project uses `pytest`. Run all tests with:
```bash
python -m pytest tests/
```

Run a single test file:
```bash
python -m pytest tests/test_koffee_core.py
```

Run a single test:
```bash
python -m pytest tests/test_koffee_core.py::TestValidateTimeFormat::test_valid_times
```

### CLI Options
```bash
# Interactive mode (first run)
python koffee_cli.py

# With arguments
python koffee_cli.py --weight 70 --wake 07:00 --sleep 23:00 --sensitivity medium

# JSON output (for piping)
python koffee_cli.py --weight 70 --wake 07:00 --sleep 23:00 --sensitivity high --json

# Show beverage allowance
python koffee_cli.py --beverages

# Show caffeine level graph
python koffee_cli.py --profile

# Re-run setup
python koffee_cli.py --setup
```

## Code Style Guidelines

### General
- Python 3 compatible code (3.10+ for union types)
- Two-blank lines between top-level definitions
- One-blank line between method definitions within a class

### Imports
- Standard library imports first
- Third-party imports second (PyQt6, etc.)
- Local application imports last
- Use absolute imports when possible
- Sort imports alphabetically within each group
- Group imports by type with blank lines between groups

```python
# Correct
import datetime
import math

from PyQt6.QtWidgets import QApplication, QWidget
from PyQt6.QtCore import Qt, QTime

from koffee_core import calculate_optimal_caffeine
```

### Formatting
- 4 spaces per indentation level
- Line length: 88 characters (Black default)
- Use implicit string concatenation for long strings
- f-strings for string formatting (Python 3.6+)
- Use parentheses for line continuations

### Types
- Add type hints to function signatures
- Use `mypy` for type checking
- Common types: `str`, `int`, `float`, `bool`, `dict`, `list`, `tuple`, `Optional`, `Union`

```python
def calculate_optimal_caffeine(
    weight_kg: float,
    wake_time: str,
    sleep_time: str,
    sensitivity: str,
) -> CaffeineResult:
    ...
```

### Naming Conventions
- Functions/methods: `snake_case`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Variables: `snake_case`
- Private members: `_single_underscore_prefix`

### Dataclasses for Structured Data
Use `@dataclass(frozen=True)` for structured return values:

```python
from dataclasses import dataclass, field

@dataclass(frozen=True)
class Dose:
    time: str | None
    amount: float

@dataclass(frozen=True)
class CaffeineResult:
    daily_limit: float
    first_dose: Dose
    second_dose: Dose
    third_dose: Dose
    warnings: list[str] = field(default_factory=list)
```

### Enums for Fixed Choices
Use `Enum` for fixed sets of choices instead of string comparisons:

```python
from enum import Enum

class Sensitivity(Enum):
    LOW = 1.2
    MEDIUM = 1.0
    HIGH = 0.8
```

### Named Constants
Extract magic numbers to named constants at module level:

```python
KG_TO_LBS = 2.20462
MAX_DAILY_CAFFEINE_MG = 400.0
FIRST_DOSE_PERCENT = 0.4
CAFFEINE_HALF_LIFE_HOURS = 5.0
```

### Docstrings
- Use triple quotes for docstrings
- Google-style docstrings for public functions

```python
def validate_time_format(time_str: str) -> bool:
    """Validate time is in HH:MM format.
    
    Args:
        time_str: Time string in HH:MM format.
        
    Returns:
        True if valid, False otherwise.
    """
    return re.match(r'^([01]\d|2[0-3]):([0-5]\d)$', time_str) is not None
```

### Error Handling
- Use specific exception types
- Include meaningful error messages
- Validate inputs and raise `ValueError` with clear messages

```python
# Correct
if not validate_weight(weight_kg):
    raise ValueError(f"Invalid weight: {weight_kg}. Must be positive kg.")
```

### Testing Guidelines
- Use `pytest` framework
- Test files go in `tests/` directory
- Name test files `test_<module_name>.py`
- Use class-based test organization for related tests
- Use `@pytest.mark.parametrize` for multiple test cases

```python
import pytest
from koffee_core import validate_time_format

class TestValidateTimeFormat:
    @pytest.mark.parametrize("time_str,expected", [
        ("07:30", True),
        ("23:59", True),
    ])
    def test_valid_times(self, time_str, expected):
        assert validate_time_format(time_str) is expected
```

## Project Structure
```
koffee/
├── koffee_core.py      # Shared calculation logic, types, constants
├── koffee_cli.py       # Command-line interface (argparse)
├── koffee_ui.py        # PyQt6 GUI (custom frameless window)
├── beverages.json       # Beverage definitions (caffeine, category, icon)
├── requirements.txt     # Python dependencies
├── Readme.md           # Project documentation
└── tests/
    └── test_koffee_core.py  # Core module tests
```

## Beverages Configuration
Beverages are defined in `beverages.json`. Each beverage has:
- `name`: Display name with portion
- `caffeine_mg`: Caffeine content
- `category`: Coffee, Tea, Energy, Other
- `icon`: Emoji for UI

## Config Persistence
User settings are stored in `~/.config/koffee/config.json`. Includes weight, sensitivity, wake/sleep times, and dose plan.

## Running the Application
```bash
# CLI version
python koffee_cli.py

# GUI version
python koffee_ui.py
```

## UI Features
- Custom frameless window with traffic light controls (close/minimize/maximize)
- Real-time caffeine-at-bedtime meter (green/yellow/red arc gauge)
- Editable dose cards with time picker and beverage combo
- "Optimize" button - preserves user's first dose if it fits the budget
- Remove button per dose card
- Dark theme with orange accent (#FF9800)
