import datetime
import re


def validate_time_format(time_str):
    """Validate the time format."""
    return re.match(r'^([01]\d|2[0-3]):([0-5]\d)$', time_str) is not None


def get_valid_input(prompt, validation_func, error_message):
    """Get and validate user input."""
    while True:
        user_input = input(prompt)
        if validation_func(user_input):
            return user_input
        print(error_message)


def calculate_optimal_caffeine(weight, wake_time, sleep_time, sensitivity):
    # Convert weight from kg to lbs
    weight_lbs = weight * 2.20462

    # Calculate daily limit based on body weight and sensitivity
    base_limit = min(weight_lbs * 2.72, 400)
    sensitivity_factors = {'low': 1.2, 'medium': 1.0, 'high': 0.8}
    daily_limit = base_limit * sensitivity_factors[sensitivity]

    # Calculate optimal intake times
    wake_datetime = datetime.datetime.strptime(wake_time, "%H:%M")
    sleep_datetime = datetime.datetime.strptime(sleep_time, "%H:%M")

    if sleep_datetime < wake_datetime:
        sleep_datetime += datetime.timedelta(days=1)

    awake_hours = (sleep_datetime - wake_datetime).total_seconds() / 3600

    # First dose: 30-60 minutes after waking up
    first_dose_time = wake_datetime + datetime.timedelta(minutes=45)
    first_dose = daily_limit * 0.4  # 40% of daily limit

    # Second dose: 4-6 hours after waking up
    second_dose_time = wake_datetime + datetime.timedelta(hours=5)
    second_dose = daily_limit * 0.3  # 30% of daily limit

    # Third dose (if applicable): No later than 6 hours before bedtime
    third_dose_time = sleep_datetime - datetime.timedelta(hours=6)
    third_dose = daily_limit * 0.3  # 30% of daily limit

    # Adjust if third dose is too close to second dose or after bedtime
    min_dose_interval = datetime.timedelta(hours=3)
    if third_dose_time - second_dose_time < min_dose_interval or third_dose_time >= sleep_datetime:
        third_dose_time = None
        third_dose = 0
        second_dose = daily_limit * 0.6  # Redistribute to second dose

    return {
        "daily_limit": daily_limit,
        "first_dose": {
            "time": first_dose_time.strftime("%H:%M"),
            "amount": round(first_dose, 2)
        },
        "second_dose": {
            "time": second_dose_time.strftime("%H:%M"),
            "amount": round(second_dose, 2)
        },
        "third_dose": {
            "time": third_dose_time.strftime("%H:%M") if third_dose_time else None,
            "amount": round(third_dose, 2)
        }
    }


def caffeine_content():
    """Return a dictionary of common caffeinated beverages and their caffeine content."""
    return {
        "Espresso (1 shot, 30ml)": 63,
        "Brewed Coffee (240ml)": 95,
        "Instant Coffee (240ml)": 62,
        "Black Tea (240ml)": 47,
        "Green Tea (240ml)": 28,
        "Cola (355ml)": 40,
        "Energy Drink (240ml)": 80
    }


def print_caffeine_content():
    """Print the caffeine content of common beverages."""
    print("\nCaffeine Content of Common Beverages (in mg):")
    for beverage, content in caffeine_content().items():
        print(f"{beverage}: {content} mg")


def main():
    print("Optimal Caffeine Intake Calculator")
    print("----------------------------------")

    weight = float(get_valid_input("Enter your weight in kg: ",
                                   lambda x: float(x) > 0,
                                   "Please enter a valid weight."))

    wake_time = get_valid_input("Enter your wake-up time (HH:MM): ",
                                validate_time_format,
                                "Please enter a valid time in HH:MM format.")

    sleep_time = get_valid_input("Enter your bedtime (HH:MM): ",
                                 validate_time_format,
                                 "Please enter a valid time in HH:MM format.")

    sensitivity = get_valid_input("Enter your caffeine sensitivity (low/medium/high): ",
                                  lambda x: x.lower() in [
                                      'low', 'medium', 'high'],
                                  "Please enter 'low', 'medium', or 'high'.")

    result = calculate_optimal_caffeine(
        weight, wake_time, sleep_time, sensitivity.lower())

    print("\nResults:")
    print(f"Daily caffeine limit: {result['daily_limit']:.2f} mg")
    print(f"First dose: {result['first_dose']['amount']} mg at {
          result['first_dose']['time']}")
    print(f"Second dose: {result['second_dose']['amount']} mg at {
          result['second_dose']['time']}")
    if result['third_dose']['time']:
        print(f"Third dose: {result['third_dose']['amount']} mg at {
              result['third_dose']['time']}")
    else:
        print("Third dose: Not recommended due to proximity to bedtime")

    print_caffeine_content()

    print("\nNote: This is a general guideline. Individual responses to caffeine may vary.")
    print("Consult with a healthcare professional for personalized advice.")


if __name__ == "__main__":
    main()
