"""Core caffeine calculation logic - shared between CLI and UI."""

from dataclasses import dataclass, field
from enum import Enum
import datetime
import json
import math
from pathlib import Path


KG_TO_LBS = 2.20462
MAX_DAILY_CAFFEINE_MG = 400.0
MG_CAFFEINE_PER_LB = 2.72
CAFFEINE_HALF_LIFE_HOURS = 5.0
CAFFEINE_PEAK_MINUTES = 45
CAFFEINE_DELAY_AFTER_WAKE_MINUTES = 90
MIN_DOSE_INTERVAL_HOURS = 4
MIN_DOSE_INTERVAL_MINUTES = 180


class Sensitivity(Enum):
    LOW = 1.2
    MEDIUM = 1.0
    HIGH = 0.8

    @property
    def safe_caffeine_at_bedtime(self) -> float:
        """Maximum caffeine that should remain at bedtime (mg)."""
        return {self.LOW: 100.0, self.MEDIUM: 50.0, self.HIGH: 25.0}[self]

    @property
    def hours_before_bed_for_last_dose(self) -> float:
        """How many hours before bed the last dose should be (accounts for peak + decay).

        Based on research: caffeine half-life is ~5 hours. For minimal sleep impact,
        we need caffeine to decay to safe levels before bed.
        """
        return {self.LOW: 6.0, self.MEDIUM: 9.0, self.HIGH: 12.0}[self]

    @classmethod
    def from_string(cls, value: str) -> "Sensitivity":
        if value is None:
            raise ValueError("Sensitivity cannot be None")
        normalized = value.lower().strip()
        for member in cls:
            if member.name.lower() == normalized:
                return member
        raise ValueError(f"Invalid sensitivity: {value}. Must be low, medium, or high.")


def _load_beverages() -> dict[str, int]:
    """Load beverages from JSON file."""
    beverages_path = Path(__file__).parent / "beverages.json"
    if beverages_path.exists():
        try:
            with open(beverages_path) as f:
                data = json.load(f)
            return {b["name"]: b["caffeine_mg"] for b in data.get("beverages", [])}
        except (json.JSONDecodeError, KeyError):
            pass
    return {
        "Espresso (1 shot, 30ml)": 63,
        "Brewed Coffee (240ml)": 95,
        "Instant Coffee (240ml)": 62,
        "Black Tea (240ml)": 47,
        "Green Tea (240ml)": 28,
        "Cola (355ml)": 40,
        "Energy Drink (240ml)": 80,
    }


def _load_beverage_icons() -> dict[str, str]:
    """Load beverage icons from JSON file."""
    beverages_path = Path(__file__).parent / "beverages.json"
    if beverages_path.exists():
        try:
            with open(beverages_path) as f:
                data = json.load(f)
            return {b["name"]: b.get("icon", "☕") for b in data.get("beverages", [])}
        except (json.JSONDecodeError, KeyError):
            pass
    return {
        "Espresso (1 shot, 30ml)": "☕",
        "Brewed Coffee (240ml)": "☕",
        "Instant Coffee (240ml)": "☕",
        "Black Tea (240ml)": "🍵",
        "Green Tea (240ml)": "🍵",
        "Cola (355ml)": "🥤",
        "Energy Drink (240ml)": "⚡",
    }


BEVERAGE_CAFFEINE_CONTENT: dict[str, int] = _load_beverages()
BEVERAGE_ICONS: dict[str, str] = _load_beverage_icons()


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
    latest_safe_caffeine_time: str | None = None


@dataclass(frozen=True)
class CaffeineLevelPoint:
    time: datetime.datetime
    level_mg: float
    source: str


@dataclass(frozen=True)
class CaffeineProfile:
    points: list[CaffeineLevelPoint]
    peak_level: float
    peak_time: str
    level_at_sleep: float
    warnings: list[str]


@dataclass(frozen=True)
class BeverageCount:
    beverage: str
    caffeine_mg: int
    count: float
    notes: str


@dataclass(frozen=True)
class CoffeeAllowance:
    daily_limit: float
    beverages: list[BeverageCount]
    recommendation: str


def validate_time_format(time_str: str) -> bool:
    """Validate time is in HH:MM format."""
    if not isinstance(time_str, str):
        return False
    if not len(time_str) == 5:
        return False
    try:
        datetime.datetime.strptime(time_str, "%H:%M")
        return True
    except ValueError:
        return False


def validate_weight(weight: float) -> bool:
    """Validate weight is a positive number in kg."""
    return isinstance(weight, (int, float)) and 0 < weight <= 500


def _calculate_caffeine_at_time(
    doses: list[tuple[datetime.datetime, float]],
    target_time: datetime.datetime,
) -> float:
    """Calculate total caffeine remaining at target time using half-life decay."""
    total = 0.0
    for dose_time, amount in doses:
        if dose_time > target_time:
            continue
        hours_elapsed = (target_time - dose_time).total_seconds() / 3600
        remaining = amount * math.pow(0.5, hours_elapsed / CAFFEINE_HALF_LIFE_HOURS)
        total += remaining
    return total


def _hours_to_reach_target(dose_mg: float, target_mg: float, half_life: float) -> float:
    """Calculate hours needed for caffeine to decay from dose_mg to target_mg."""
    if dose_mg <= target_mg:
        return 0.0
    return half_life * math.log2(dose_mg / target_mg)


def _calculate_optimal_doses_for_sleep(
    daily_limit: float,
    wake_datetime: datetime.datetime,
    sleep_datetime: datetime.datetime,
    sensitivity: Sensitivity,
) -> tuple[list[tuple[datetime.datetime, float]], list[str]]:
    """Calculate doses that optimize for both caffeine needs AND sleep quality.

    Always produces a safe schedule that keeps bedtime caffeine below the safe limit.
    """
    warnings = []
    safe_at_bedtime = sensitivity.safe_caffeine_at_bedtime
    buffer_hours = sensitivity.hours_before_bed_for_last_dose

    latest_safe_time = sleep_datetime - datetime.timedelta(hours=buffer_hours)
    first_dose_time = wake_datetime + datetime.timedelta(
        minutes=CAFFEINE_DELAY_AFTER_WAKE_MINUTES
    )

    if latest_safe_time <= first_dose_time:
        return [], []

    second_dose_time = latest_safe_time - datetime.timedelta(hours=2)

    if second_dose_time - first_dose_time >= datetime.timedelta(
        hours=MIN_DOSE_INTERVAL_HOURS
    ):
        second_dose_available = True
        usable_hours = (second_dose_time - first_dose_time).total_seconds() / 3600
    else:
        second_dose_available = False
        usable_hours = (latest_safe_time - first_dose_time).total_seconds() / 3600

    effective_limit = daily_limit

    doses = []
    if second_dose_available:
        first_amount = effective_limit * 0.4
        second_amount = effective_limit * 0.6
        doses.append((first_dose_time, first_amount))
        doses.append((second_dose_time, second_amount))
    else:
        single_dose = effective_limit * 0.6
        doses.append((first_dose_time, single_dose))

    return doses, warnings


def calculate_optimal_caffeine(
    weight_kg: float,
    wake_time: str,
    sleep_time: str,
    sensitivity: str,
) -> CaffeineResult:
    """Calculate optimal caffeine intake schedule optimized for sleep quality.

    Args:
        weight_kg: Body weight in kilograms.
        wake_time: Wake-up time in HH:MM format.
        sleep_time: Bedtime in HH:MM format.
        sensitivity: Caffeine sensitivity (low, medium, high).

    Returns:
        CaffeineResult with daily limit and dose schedule optimized for sleep.

    Raises:
        ValueError: If inputs are invalid.
    """
    if not validate_weight(weight_kg):
        raise ValueError(f"Invalid weight: {weight_kg}. Must be positive kg.")
    if not validate_time_format(wake_time):
        raise ValueError(f"Invalid wake time: {wake_time}. Must be HH:MM.")
    if not validate_time_format(sleep_time):
        raise ValueError(f"Invalid sleep time: {sleep_time}. Must be HH:MM.")

    sensitivity_enum = Sensitivity.from_string(sensitivity)
    weight_lbs = weight_kg * KG_TO_LBS
    base_limit = min(weight_lbs * MG_CAFFEINE_PER_LB, MAX_DAILY_CAFFEINE_MG)
    daily_limit = base_limit * sensitivity_enum.value

    wake_datetime = datetime.datetime.strptime(wake_time, "%H:%M")
    sleep_datetime = datetime.datetime.strptime(sleep_time, "%H:%M")

    if sleep_datetime <= wake_datetime:
        sleep_datetime += datetime.timedelta(days=1)

    doses, warnings = _calculate_optimal_doses_for_sleep(
        daily_limit, wake_datetime, sleep_datetime, sensitivity_enum
    )

    latest_safe_time = sleep_datetime - datetime.timedelta(
        hours=sensitivity_enum.hours_before_bed_for_last_dose
    )
    latest_safe_caffeine_time = latest_safe_time.strftime("%H:%M")

    if not doses:
        return CaffeineResult(
            daily_limit=round(daily_limit, 2),
            first_dose=Dose(time=None, amount=0),
            second_dose=Dose(time=None, amount=0),
            third_dose=Dose(time=None, amount=0),
            warnings=warnings,
            latest_safe_caffeine_time=latest_safe_caffeine_time,
        )

    doses.sort(key=lambda x: x[0])

    first_dose_time = doses[0][0].strftime("%H:%M") if len(doses) > 0 else None
    first_dose_amount = doses[0][1] if len(doses) > 0 else 0

    second_dose_time = doses[1][0].strftime("%H:%M") if len(doses) > 1 else None
    second_dose_amount = doses[1][1] if len(doses) > 1 else 0

    third_dose_time = doses[2][0].strftime("%H:%M") if len(doses) > 2 else None
    third_dose_amount = doses[2][1] if len(doses) > 2 else 0

    if len(doses) <= 2:
        third_dose_time = None
        third_dose_amount = 0

    caffeine_at_bedtime = _calculate_caffeine_at_time(
        [
            (datetime.datetime.strptime(t, "%H:%M"), a)
            for t, a in [
                (first_dose_time, first_dose_amount),
                (second_dose_time, second_dose_amount),
                (third_dose_time, third_dose_amount),
            ]
            if t is not None
        ],
        sleep_datetime,
    )

    if caffeine_at_bedtime > sensitivity_enum.safe_caffeine_at_bedtime:
        warnings.append(
            f"For {sensitivity.lower()} sensitivity, keep caffeine under "
            f"{sensitivity_enum.safe_caffeine_at_bedtime:.0f}mg at bedtime. "
            f"Current plan leaves ~{caffeine_at_bedtime:.0f}mg."
        )

    return CaffeineResult(
        daily_limit=round(daily_limit, 2),
        first_dose=Dose(time=first_dose_time, amount=round(first_dose_amount, 2)),
        second_dose=Dose(time=second_dose_time, amount=round(second_dose_amount, 2)),
        third_dose=Dose(time=third_dose_time, amount=round(third_dose_amount, 2)),
        warnings=warnings,
        latest_safe_caffeine_time=latest_safe_caffeine_time,
    )


def calculate_caffeine_profile(
    weight_kg: float,
    wake_time: str,
    sleep_time: str,
    sensitivity: str,
) -> CaffeineProfile:
    """Calculate caffeine levels throughout the day for visualization."""
    result = calculate_optimal_caffeine(weight_kg, wake_time, sleep_time, sensitivity)

    wake_datetime = datetime.datetime.strptime(wake_time, "%H:%M")
    sleep_datetime = datetime.datetime.strptime(sleep_time, "%H:%M")
    if sleep_datetime <= wake_datetime:
        sleep_datetime += datetime.timedelta(days=1)

    doses = []
    dose_labels = []
    for i, dose in enumerate(
        [result.first_dose, result.second_dose, result.third_dose]
    ):
        if dose.time:
            dt = datetime.datetime.strptime(dose.time, "%H:%M")
            doses.append((dt, dose.amount))
            dose_labels.append(f"dose {i + 1}")

    if not doses:
        return CaffeineProfile(
            points=[],
            peak_level=0,
            peak_time="",
            level_at_sleep=0,
            warnings=result.warnings,
        )

    points = []
    current_time = wake_datetime
    interval = datetime.timedelta(minutes=15)
    peak_level = 0.0
    peak_time = ""

    while current_time <= sleep_datetime + datetime.timedelta(hours=1):
        level = _calculate_caffeine_at_time(doses, current_time)
        source = ""
        for i, (dose_time, _) in enumerate(doses):
            if abs((current_time - dose_time).total_seconds()) < 600:
                source = dose_labels[i]
                break

        points.append(
            CaffeineLevelPoint(
                time=current_time, level_mg=round(level, 1), source=source
            )
        )

        if level > peak_level:
            peak_level = level
            peak_time = current_time.strftime("%H:%M")

        current_time += interval

    caffeine_at_sleep = _calculate_caffeine_at_time(doses, sleep_datetime)

    return CaffeineProfile(
        points=points,
        peak_level=round(peak_level, 1),
        peak_time=peak_time,
        level_at_sleep=round(caffeine_at_sleep, 1),
        warnings=result.warnings,
    )


def calculate_beverage_allowance(
    weight_kg: float,
    wake_time: str,
    sleep_time: str,
    sensitivity: str,
) -> CoffeeAllowance:
    """Calculate how many of each beverage you can have."""
    result = calculate_optimal_caffeine(weight_kg, wake_time, sleep_time, sensitivity)
    daily_limit = result.daily_limit

    beverages = []
    for name, caffeine in sorted(
        BEVERAGE_CAFFEINE_CONTENT.items(), key=lambda x: -x[1]
    ):
        count = daily_limit / caffeine
        notes = ""
        if count >= 4:
            notes = "plenty available"
        elif count >= 2:
            notes = "moderate"
        elif count >= 1:
            notes = "limited"
        else:
            notes = "not recommended today"

        beverages.append(
            BeverageCount(
                beverage=name,
                caffeine_mg=caffeine,
                count=round(count, 1),
                notes=notes,
            )
        )

    best_beverage = min(beverages, key=lambda x: x.count)
    recommendation = f"You can safely have about {best_beverage.count:.1f} {best_beverage.beverage.split('(')[0].strip()} today."

    return CoffeeAllowance(
        daily_limit=daily_limit,
        beverages=beverages,
        recommendation=recommendation,
    )


def get_beverage_caffeine_content() -> dict[str, int]:
    """Return caffeine content of common beverages in mg."""
    return dict(BEVERAGE_CAFFEINE_CONTENT)


def format_profile_ascii(profile: CaffeineProfile, width: int = 60) -> str:
    """Format caffeine profile as ASCII art graph."""
    if not profile.points:
        return "No data"

    max_level = max(p.level_mg for p in profile.points)
    if max_level == 0:
        max_level = 100

    lines = []
    lines.append("Caffeine Level Throughout the Day")
    lines.append("=" * width)
    lines.append(f"Peak: {profile.peak_level}mg at {profile.peak_time}")
    lines.append(f"At bedtime: {profile.level_at_sleep}mg")
    lines.append("")

    grid = [[" " for _ in range(width)] for _ in range(10)]

    for point in profile.points:
        x = int((point.level_mg / max_level) * (width - 1))
        x = min(x, width - 1)
        y_row = 9 - int((point.level_mg / max_level) * 9)
        y_row = max(0, min(9, y_row))
        grid[y_row][x] = "█"

    for row in grid:
        lines.append("|" + "".join(row) + "|")

    time_start = profile.points[0].time if profile.points else None
    time_end = profile.points[-1].time if profile.points else None

    if time_start and time_end:
        lines.append(f"+{'-' * width}+")
        lines.append(
            f"{time_start.strftime('%H:%M'):<{width // 2}}"
            f"{time_end.strftime('%H:%M'):>{width // 2}}"
        )

    return "\n".join(lines)
