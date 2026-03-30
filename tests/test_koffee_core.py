"""Tests for koffee_core module."""

import datetime

import pytest
from koffee_core import (
    CaffeineProfile,
    CaffeineResult,
    Dose,
    Sensitivity,
    calculate_beverage_allowance,
    calculate_caffeine_profile,
    calculate_optimal_caffeine,
    format_profile_ascii,
    get_beverage_caffeine_content,
    validate_time_format,
    validate_weight,
)


class TestValidateTimeFormat:
    @pytest.mark.parametrize(
        "time_str,expected",
        [
            ("07:30", True),
            ("00:00", True),
            ("23:59", True),
            ("12:00", True),
        ],
    )
    def test_valid_times(self, time_str, expected):
        assert validate_time_format(time_str) is expected

    @pytest.mark.parametrize(
        "time_str",
        [
            "25:00",
            "12:60",
            "7:30",
            "0730",
            "",
            "12:0",
            "1:30",
            "12:000",
            None,
        ],
    )
    def test_invalid_times(self, time_str):
        assert validate_time_format(time_str) is False


class TestValidateWeight:
    @pytest.mark.parametrize(
        "weight,expected",
        [
            (70.0, True),
            (1.0, True),
            (500.0, True),
            (0.1, True),
            (0, False),
            (-10.0, False),
            (-0.1, False),
            (500.1, False),
            (None, False),
            ("70", False),
        ],
    )
    def test_weight_validation(self, weight, expected):
        assert validate_weight(weight) is expected


class TestSensitivity:
    @pytest.mark.parametrize(
        "input_str,sensitivity",
        [
            ("low", Sensitivity.LOW),
            ("LOW", Sensitivity.LOW),
            ("Low", Sensitivity.LOW),
            ("  low  ", Sensitivity.LOW),
            ("medium", Sensitivity.MEDIUM),
            ("MEDIUM", Sensitivity.MEDIUM),
            ("Medium", Sensitivity.MEDIUM),
            ("high", Sensitivity.HIGH),
            ("HIGH", Sensitivity.HIGH),
            ("High", Sensitivity.HIGH),
        ],
    )
    def test_valid_sensitivity(self, input_str, sensitivity):
        assert Sensitivity.from_string(input_str) is sensitivity

    @pytest.mark.parametrize(
        "invalid_input",
        [
            "invalid",
            "",
            "lowh",
            "med",
            "very high",
            None,
        ],
    )
    def test_invalid_sensitivity(self, invalid_input):
        with pytest.raises(ValueError):
            Sensitivity.from_string(invalid_input)

    def test_safe_caffeine_at_bedtime(self):
        assert Sensitivity.HIGH.safe_caffeine_at_bedtime == 25.0
        assert Sensitivity.MEDIUM.safe_caffeine_at_bedtime == 50.0
        assert Sensitivity.LOW.safe_caffeine_at_bedtime == 100.0

    def test_hours_before_bed_for_last_dose(self):
        assert Sensitivity.HIGH.hours_before_bed_for_last_dose == 12.0
        assert Sensitivity.MEDIUM.hours_before_bed_for_last_dose == 9.0
        assert Sensitivity.LOW.hours_before_bed_for_last_dose == 6.0


class TestCalculateOptimalCaffeine:
    def test_basic_calculation(self):
        result = calculate_optimal_caffeine(
            weight_kg=70.0,
            wake_time="07:00",
            sleep_time="23:00",
            sensitivity="medium",
        )

        assert isinstance(result, CaffeineResult)
        assert result.daily_limit > 0

    def test_high_sensitivity_has_stricter_timing(self):
        result_high = calculate_optimal_caffeine(
            weight_kg=70.0,
            wake_time="07:00",
            sleep_time="23:00",
            sensitivity="high",
        )
        result_low = calculate_optimal_caffeine(
            weight_kg=70.0,
            wake_time="07:00",
            sleep_time="23:00",
            sensitivity="low",
        )

        assert result_high.latest_safe_caffeine_time == "11:00"
        assert result_low.latest_safe_caffeine_time == "17:00"

    def test_short_awake_time_returns_no_doses(self):
        result = calculate_optimal_caffeine(
            weight_kg=70.0,
            wake_time="07:00",
            sleep_time="14:00",
            sensitivity="high",
        )

        assert result.first_dose.time is None
        assert result.first_dose.amount == 0

    def test_invalid_weight_raises(self):
        with pytest.raises(ValueError, match="Invalid weight"):
            calculate_optimal_caffeine(
                weight_kg=-10.0,
                wake_time="07:00",
                sleep_time="23:00",
                sensitivity="medium",
            )

    def test_invalid_wake_time_raises(self):
        with pytest.raises(ValueError, match="Invalid wake time"):
            calculate_optimal_caffeine(
                weight_kg=70.0,
                wake_time="25:00",
                sleep_time="23:00",
                sensitivity="medium",
            )

    def test_invalid_sleep_time_raises(self):
        with pytest.raises(ValueError, match="Invalid sleep time"):
            calculate_optimal_caffeine(
                weight_kg=70.0,
                wake_time="07:00",
                sleep_time="25:00",
                sensitivity="medium",
            )

    def test_dose_is_dataclass(self):
        result = calculate_optimal_caffeine(
            weight_kg=70.0,
            wake_time="07:00",
            sleep_time="23:00",
            sensitivity="medium",
        )

        assert isinstance(result.first_dose, Dose)
        assert isinstance(result.second_dose, Dose)
        assert isinstance(result.third_dose, Dose)

    def test_doses_include_latest_safe_time(self):
        result = calculate_optimal_caffeine(
            weight_kg=70.0,
            wake_time="07:00",
            sleep_time="23:00",
            sensitivity="medium",
        )

        assert result.latest_safe_caffeine_time is not None
        assert result.latest_safe_caffeine_time == "14:00"


class TestCalculateCaffeineProfile:
    def test_profile_generates_points(self):
        profile = calculate_caffeine_profile(
            weight_kg=70.0,
            wake_time="07:00",
            sleep_time="23:00",
            sensitivity="medium",
        )

        assert isinstance(profile, CaffeineProfile)
        assert len(profile.points) > 0
        assert profile.peak_level > 0
        assert profile.peak_time is not None

    def test_profile_caffeine_decay(self):
        profile = calculate_caffeine_profile(
            weight_kg=70.0,
            wake_time="07:00",
            sleep_time="23:00",
            sensitivity="medium",
        )

        levels = [p.level_mg for p in profile.points]
        max_level = max(levels)
        assert profile.peak_level == max_level


class TestCalculateBeverageAllowance:
    def test_beverage_allowance(self):
        allowance = calculate_beverage_allowance(
            weight_kg=70.0,
            wake_time="07:00",
            sleep_time="23:00",
            sensitivity="medium",
        )

        assert allowance.daily_limit > 0
        assert len(allowance.beverages) > 0
        for bev in allowance.beverages:
            assert bev.count > 0
            assert bev.caffeine_mg > 0


class TestFormatProfileAscii:
    def test_format_returns_string(self):
        profile = calculate_caffeine_profile(
            weight_kg=70.0,
            wake_time="07:00",
            sleep_time="23:00",
            sensitivity="medium",
        )

        output = format_profile_ascii(profile)
        assert isinstance(output, str)
        assert len(output) > 0
        assert "Peak:" in output


class TestBeverageCaffeineContent:
    def test_returns_dict(self):
        content = get_beverage_caffeine_content()
        assert isinstance(content, dict)

    def test_has_expected_beverages(self):
        content = get_beverage_caffeine_content()
        assert "Espresso (1 shot, 30ml)" in content
        assert "Brewed Coffee (240ml)" in content
        assert "Green Tea (240ml)" in content

    def test_caffeine_values_are_positive_integers(self):
        content = get_beverage_caffeine_content()
        for beverage, caffeine in content.items():
            assert isinstance(caffeine, int)
            assert caffeine > 0
