import sys
import datetime
from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout,
                             QLabel, QLineEdit, QPushButton, QComboBox,
                             QTextEdit, QTimeEdit, QDoubleSpinBox)
from PyQt6.QtCore import Qt, QTime


class CaffeineCalculator(QWidget):
    def __init__(self):
        super().__init__()
        self.initUI()

    def initUI(self):
        self.setWindowTitle('Caffeine Intake Calculator')
        layout = QVBoxLayout()

        # Weight input
        weight_layout = QHBoxLayout()
        weight_layout.addWidget(QLabel('Weight (kg):'))
        self.weight_input = QDoubleSpinBox()
        self.weight_input.setRange(20, 200)
        self.weight_input.setValue(70)
        weight_layout.addWidget(self.weight_input)
        layout.addLayout(weight_layout)

        # Wake time input
        wake_layout = QHBoxLayout()
        wake_layout.addWidget(QLabel('Wake-up time:'))
        self.wake_time_input = QTimeEdit()
        self.wake_time_input.setTime(QTime(7, 0))
        wake_layout.addWidget(self.wake_time_input)
        layout.addLayout(wake_layout)

        # Sleep time input
        sleep_layout = QHBoxLayout()
        sleep_layout.addWidget(QLabel('Bedtime:'))
        self.sleep_time_input = QTimeEdit()
        self.sleep_time_input.setTime(QTime(23, 0))
        sleep_layout.addWidget(self.sleep_time_input)
        layout.addLayout(sleep_layout)

        # Sensitivity input
        sensitivity_layout = QHBoxLayout()
        sensitivity_layout.addWidget(QLabel('Caffeine sensitivity:'))
        self.sensitivity_input = QComboBox()
        self.sensitivity_input.addItems(['Low', 'Medium', 'High'])
        sensitivity_layout.addWidget(self.sensitivity_input)
        layout.addLayout(sensitivity_layout)

        # Calculate button
        self.calculate_button = QPushButton('Calculate')
        self.calculate_button.clicked.connect(self.calculate)
        layout.addWidget(self.calculate_button)

        # Results display
        self.results_display = QTextEdit()
        self.results_display.setReadOnly(True)
        layout.addWidget(self.results_display)

        self.setLayout(layout)

    def calculate(self):
        weight = self.weight_input.value()
        wake_time = self.wake_time_input.time().toString("HH:mm")
        sleep_time = self.sleep_time_input.time().toString("HH:mm")
        sensitivity = self.sensitivity_input.currentText().lower()

        result = self.calculate_optimal_caffeine(
            weight, wake_time, sleep_time, sensitivity)

        self.display_results(result)

    def calculate_optimal_caffeine(self, weight, wake_time, sleep_time, sensitivity):
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

    def display_results(self, result):
        output = f"Daily caffeine limit: {result['daily_limit']:.2f} mg\n\n"
        output += f"First dose: {result['first_dose']
                                 ['amount']} mg at {result['first_dose']['time']}\n"
        output += f"Second dose: {result['second_dose']
                                  ['amount']} mg at {result['second_dose']['time']}\n"

        if result['third_dose']['time']:
            output += f"Third dose: {result['third_dose']
                                     ['amount']} mg at {result['third_dose']['time']}\n"
        else:
            output += "Third dose: Not recommended due to proximity to bedtime\n"

        output += "\nCaffeine Content of Common Beverages (in mg):\n"
        for beverage, content in self.caffeine_content().items():
            output += f"{beverage}: {content} mg\n"

        output += "\nNote: This is a general guideline. Individual responses to caffeine may vary."
        output += "\nConsult with a healthcare professional for personalized advice."

        self.results_display.setPlainText(output)

    def caffeine_content(self):
        return {
            "Espresso (1 shot, 30ml)": 63,
            "Brewed Coffee (240ml)": 95,
            "Instant Coffee (240ml)": 62,
            "Black Tea (240ml)": 47,
            "Green Tea (240ml)": 28,
            "Cola (355ml)": 40,
            "Energy Drink (240ml)": 80
        }


if __name__ == '__main__':
    app = QApplication(sys.argv)
    ex = CaffeineCalculator()
    ex.show()
    sys.exit(app.exec())
