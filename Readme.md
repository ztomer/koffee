# Koffee

Caffeine intake optimization tool with CLI and UI versions.

![Koffee UI](screenshot.png)
<!-- Take a screenshot of the UI with: ⌘⇧4 then select the window, save as screenshot.png -->

## Features

- Optimal caffeine dose scheduling based on weight and sensitivity
- Caffeine half-life modeling for realistic accumulation tracking
- "How many coffees?" mode - see how many drinks you can have
- Caffeine level visualization throughout the day
- Real-time bedtime caffeine meter
- Config persistence across sessions
- JSON output for scripting
- 16 beverages to choose from

## Quick Start

```bash
# Interactive setup
python koffee_cli.py

# One-shot with arguments
python koffee_cli.py --weight 70 --wake 07:00 --sleep 23:00 --sensitivity medium

# Show caffeine levels graph
python koffee_cli.py --profile

# Show beverage allowance
python koffee_cli.py --beverages

# JSON output for piping
python koffee_cli.py --json --weight 70 --wake 07:00 --sleep 23:00 --sensitivity medium
```

## Installation

### CLI
```bash
pip install -r requirements.txt
```

### UI (Mac)
```bash
brew install qt
pip install PyQt6
python koffee_ui.py
```

## Project Structure

```
koffee/
├── koffee_core.py      # Pure calculation logic, shared by CLI and UI
├── koffee_cli.py       # Command-line interface with argparse
├── koffee_ui.py        # PyQt6 GUI application
├── beverages.json      # Beverage definitions (caffeine content, categories, icons)
├── requirements.txt    # Python dependencies
└── tests/
    └── test_koffee_core.py
```

## Configuration

User settings are stored in `~/.config/koffee.json`:
- Weight, sensitivity, wake/sleep times
- Custom dose plan

## Development

```bash
# Run tests
python -m pytest tests/

# Type check
mypy koffee_core.py koffee_cli.py koffee_ui.py

# Lint
ruff check .
```

## Customizing Beverages

Edit `beverages.json` to add, remove, or modify beverages:

```json
{
  "beverages": [
    {"name": "Espresso (1 shot, 30ml)", "caffeine_mg": 63, "category": "Coffee", "icon": "☕"}
  ]
}
```

Fields:
- `name`: Display name with portion info
- `caffeine_mg`: Caffeine content in milligrams
- `category`: Grouping (Coffee, Tea, Energy, Other)
- `icon`: Emoji icon for UI display
