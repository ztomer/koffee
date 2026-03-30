"""Koffee CLI - Command-line interface for caffeine intake calculator."""

import argparse
import json
import os
import sys
from pathlib import Path

from koffee_core import (
    BEVERAGE_ICONS,
    CaffeineProfile,
    CoffeeAllowance,
    calculate_beverage_allowance,
    calculate_caffeine_profile,
    calculate_optimal_caffeine,
    format_profile_ascii,
    get_beverage_caffeine_content,
    validate_time_format,
    validate_weight,
)


CONFIG_DIR = Path.home() / ".config" / "koffee"
CONFIG_FILE = CONFIG_DIR / "config.json"


def ensure_config_dir() -> None:
    """Ensure config directory exists."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)


def load_config() -> dict:
    """Load user config from ~/.config/koffee/config.json."""
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE) as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            pass
    return {}


def save_config(config: dict) -> None:
    """Save user config to ~/.config/koffee/config.json."""
    ensure_config_dir()
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f, indent=2)


def get_default_or_input(
    config: dict,
    key: str,
    prompt: str,
    validator,
    error_msg: str,
    is_numeric: bool = False,
) -> str | float:
    """Get value from config or prompt user."""
    default = config.get(key, "")
    if default:
        prompt_with_default = f"{prompt} [{default}]: "
    else:
        prompt_with_default = f"{prompt}: "

    while True:
        user_input = input(prompt_with_default).strip()
        if not user_input and default:
            return default
        if is_numeric:
            try:
                value = float(user_input)
                if validator(value):
                    return value
            except ValueError:
                pass
        else:
            if validator(user_input):
                return user_input
        print(error_msg)


def interactive_mode() -> None:
    """Run koffee in interactive mode with config persistence."""
    config = load_config()

    print("Optimal Caffeine Intake Calculator")
    print("-" * 40)

    weight = get_default_or_input(
        config,
        "weight",
        "Enter your weight in kg",
        lambda x: x > 0,
        "Enter a valid weight.",
        True,
    )

    wake_time = get_default_or_input(
        config,
        "wake_time",
        "Enter your wake-up time (HH:MM)",
        validate_time_format,
        "Enter a valid time in HH:MM format.",
    )

    sleep_time = get_default_or_input(
        config,
        "sleep_time",
        "Enter your bedtime (HH:MM)",
        validate_time_format,
        "Enter a valid time in HH:MM format.",
    )

    sensitivity = get_default_or_input(
        config,
        "sensitivity",
        "Enter caffeine sensitivity (low/medium/high)",
        lambda x: x.lower() in ["low", "medium", "high"],
        "Enter 'low', 'medium', or 'high'.",
    )

    save = input("Save these settings? [Y/n]: ").strip().lower()
    if save != "n":
        save_config(
            {
                "weight": weight,
                "wake_time": wake_time,
                "sleep_time": sleep_time,
                "sensitivity": sensitivity,
            }
        )
        print("Settings saved.")

    print_recommended_plan(weight, wake_time, sleep_time, sensitivity)


def print_recommended_plan(weight, wake_time, sleep_time, sensitivity) -> None:
    """Print the recommended caffeine plan."""
    result = calculate_optimal_caffeine(weight, wake_time, sleep_time, sensitivity)

    print(f"\nDaily caffeine limit: {result.daily_limit:.2f} mg")

    if result.first_dose.time:
        print(f"First dose: {result.first_dose.amount} mg at {result.first_dose.time}")
        if result.second_dose.time:
            print(
                f"Second dose: {result.second_dose.amount} mg at {result.second_dose.time}"
            )
    else:
        print("No caffeine recommended for good sleep.")

    if result.latest_safe_caffeine_time:
        print(
            f"\n[Sleep Tip] Finish caffeine by {result.latest_safe_caffeine_time} "
            f"for {sensitivity.lower()} sensitivity."
        )

    for warning in result.warnings:
        print(f"\n{warning}")

    print_caffeine_content()


def print_caffeine_content() -> None:
    """Print the caffeine content of common beverages."""
    print("\nCaffeine Content of Common Beverages (in mg):")
    for beverage, content in get_beverage_caffeine_content().items():
        icon = BEVERAGE_ICONS.get(beverage, "🍺")
        print(f"  {icon} {beverage}: {content} mg")


def beverages_mode() -> None:
    """Show how many beverages you can have."""
    config = load_config()

    weight = config.get("weight")
    wake_time = config.get("wake_time")
    sleep_time = config.get("sleep_time")
    sensitivity = config.get("sensitivity")

    if not all([weight, wake_time, sleep_time, sensitivity]):
        print("Run without --beverages first to set up your profile.")
        print("Usage: python koffee_cli.py --setup")
        return

    allowance = calculate_beverage_allowance(weight, wake_time, sleep_time, sensitivity)

    print(f"\nYour daily caffeine limit: {allowance.daily_limit:.0f} mg")
    print(f"\nHow many of each can you have?")
    print("-" * 50)

    for bev in allowance.beverages:
        icon = BEVERAGE_ICONS.get(bev.beverage, "🍺")
        bar = "█" * min(int(bev.count), 10)
        print(f"{icon} {bev.beverage:<30} {bev.count:>5.1f} {bar} ({bev.notes})")

    print(f"\n{allowance.recommendation}")


def profile_mode() -> None:
    """Show caffeine level visualization."""
    config = load_config()

    weight = config.get("weight")
    wake_time = config.get("wake_time")
    sleep_time = config.get("sleep_time")
    sensitivity = config.get("sensitivity")

    if not all([weight, wake_time, sleep_time, sensitivity]):
        print("Run without --profile first to set up your profile.")
        print("Usage: python koffee_cli.py --setup")
        return

    profile = calculate_caffeine_profile(weight, wake_time, sleep_time, sensitivity)

    print(format_profile_ascii(profile))

    for warning in profile.warnings:
        print(f"\n{warning}")


def json_mode(weight: float, wake_time: str, sleep_time: str, sensitivity: str) -> None:
    """Output results as JSON."""
    result = calculate_optimal_caffeine(weight, wake_time, sleep_time, sensitivity)
    profile = calculate_caffeine_profile(weight, wake_time, sleep_time, sensitivity)
    allowance = calculate_beverage_allowance(weight, wake_time, sleep_time, sensitivity)

    output = {
        "daily_limit_mg": result.daily_limit,
        "doses": [
            {"time": result.first_dose.time, "amount_mg": result.first_dose.amount},
            {"time": result.second_dose.time, "amount_mg": result.second_dose.amount},
            {"time": result.third_dose.time, "amount_mg": result.third_dose.amount},
        ],
        "warnings": result.warnings,
        "profile": {
            "peak_level_mg": profile.peak_level,
            "peak_time": profile.peak_time,
            "level_at_sleep_mg": profile.level_at_sleep,
            "points": [
                {
                    "time": p.time.isoformat(),
                    "level_mg": p.level_mg,
                    "source": p.source,
                }
                for p in profile.points
            ],
        },
        "beverages": [
            {"name": b.beverage, "caffeine_mg": b.caffeine_mg, "count": b.count}
            for b in allowance.beverages
        ],
    }

    print(json.dumps(output, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Koffee - Optimal Caffeine Intake Calculator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  koffee_cli.py                    Run interactive setup
  koffee_cli.py --weight 70 --wake 07:00 --sleep 23:00 --sensitivity medium
  koffee_cli.py --json --weight 70 --wake 07:00 --sleep 23:00 --sensitivity high
  koffee_cli.py --beverages        Show beverage allowance
  koffee_cli.py --profile          Show caffeine level graph
  koffee_cli.py --setup            Re-run interactive setup
        """,
    )

    parser.add_argument("--weight", type=float, help="Weight in kg")
    parser.add_argument("--wake", dest="wake_time", help="Wake-up time (HH:MM)")
    parser.add_argument("--sleep", dest="sleep_time", help="Bedtime (HH:MM)")
    parser.add_argument(
        "--sensitivity", choices=["low", "medium", "high"], help="Caffeine sensitivity"
    )
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument(
        "--beverages", action="store_true", help="Show beverage allowance"
    )
    parser.add_argument(
        "--profile", action="store_true", help="Show caffeine level graph"
    )
    parser.add_argument("--setup", action="store_true", help="Run interactive setup")

    args = parser.parse_args()

    if args.setup:
        interactive_mode()
        return

    if args.beverages:
        beverages_mode()
        return

    if args.profile:
        profile_mode()
        return

    config = load_config()

    weight = args.weight if args.weight else config.get("weight")
    wake_time = args.wake_time if args.wake_time else config.get("wake_time")
    sleep_time = args.sleep_time if args.sleep_time else config.get("sleep_time")
    sensitivity = args.sensitivity if args.sensitivity else config.get("sensitivity")

    if not all([weight, wake_time, sleep_time, sensitivity]):
        interactive_mode()
        return

    if not validate_weight(weight):
        print(f"Invalid weight: {weight}", file=sys.stderr)
        sys.exit(1)
    if not validate_time_format(wake_time):
        print(f"Invalid wake time: {wake_time}", file=sys.stderr)
        sys.exit(1)
    if not validate_time_format(sleep_time):
        print(f"Invalid sleep time: {sleep_time}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        json_mode(weight, wake_time, sleep_time, sensitivity)
    else:
        print_recommended_plan(weight, wake_time, sleep_time, sensitivity)


if __name__ == "__main__":
    main()
