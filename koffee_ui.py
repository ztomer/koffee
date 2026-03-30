"""Koffee UI - Joyful PyQt6 GUI for caffeine intake calculator."""

import datetime
import math
import sys
from math import pi, cos, sin
from pathlib import Path


def _check_pyqt6() -> None:
    """Check if PyQt6 is installed."""
    try:
        from PyQt6.QtWidgets import QApplication
    except ImportError:
        print("Error: PyQt6 is not installed.")
        print("Install it with: pip install PyQt6")
        sys.exit(1)


_check_pyqt6()

from PyQt6.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QGraphicsView,
    QGraphicsScene,
    QGraphicsEllipseItem,
    QGraphicsTextItem,
    QDoubleSpinBox,
    QTimeEdit,
    QComboBox,
    QSizePolicy,
)
from PyQt6.QtCore import Qt, QPoint, QTime, pyqtSignal
from PyQt6.QtGui import QColor, QPen, QBrush, QFont, QLinearGradient, QMouseEvent

from koffee_core import (
    BEVERAGE_CAFFEINE_CONTENT,
    calculate_caffeine_profile,
    calculate_optimal_caffeine,
    Sensitivity,
)


def _load_beverages_ui() -> list[tuple[str, int, str, str]]:
    """Load beverages from JSON with category and icon."""
    import json
    from pathlib import Path

    beverages_path = Path(__file__).parent / "beverages.json"
    if beverages_path.exists():
        try:
            with open(beverages_path) as f:
                data = json.load(f)
            return [
                (
                    b["name"],
                    b["caffeine_mg"],
                    b.get("category", "Other"),
                    b.get("icon", "☕"),
                )
                for b in data.get("beverages", [])
            ]
        except (json.JSONDecodeError, KeyError):
            pass
    return [(name, mg, "Other", "☕") for name, mg in BEVERAGE_CAFFEINE_CONTENT.items()]


BEVERAGES = _load_beverages_ui()


class TitleBar(QWidget):
    """Custom titlebar with window controls."""

    close_requested = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent_window = parent
        self.setFixedHeight(44)
        self.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self.setStyleSheet("background: #252525; border-bottom: 1px solid #333333;")

        self._drag_start = QPoint()

        layout = QHBoxLayout(self)
        layout.setContentsMargins(16, 0, 16, 0)

        controls = QHBoxLayout()
        controls.setSpacing(8)

        self.close_btn = QPushButton()
        self.close_btn.setFixedSize(12, 12)
        self.close_btn.setStyleSheet("""
            QPushButton { background: #FF5F56; border-radius: 6px; border: none; }
            QPushButton:hover { background: #FF3B30; }
        """)
        self.close_btn.clicked.connect(
            lambda: self.close_requested.emit() if self.parent_window else None
        )

        self.minimize_btn = QPushButton()
        self.minimize_btn.setFixedSize(12, 12)
        self.minimize_btn.setStyleSheet("""
            QPushButton { background: #FFBD2E; border-radius: 6px; border: none; }
            QPushButton:hover { background: #FFCC00; }
        """)
        self.minimize_btn.clicked.connect(
            lambda: self.parent_window.showMinimized() if self.parent_window else None
        )

        self.maximize_btn = QPushButton()
        self.maximize_btn.setFixedSize(12, 12)
        self.maximize_btn.setStyleSheet("""
            QPushButton { background: #27CA40; border-radius: 6px; border: none; }
            QPushButton:hover { background: #34C759; }
        """)
        self.maximize_btn.clicked.connect(self._toggle_maximize)

        controls.addWidget(self.close_btn)
        controls.addWidget(self.minimize_btn)
        controls.addWidget(self.maximize_btn)

        icon_label = QLabel("☕")
        icon_label.setFont(QFont("", 14))
        icon_label.setStyleSheet("background: transparent; padding-top: 2px;")

        title = QLabel("Koffee")
        title.setFont(QFont(".AppleSystemUIFont", 13, QFont.Weight.DemiBold))
        title.setStyleSheet("color: #FF9800; background: transparent;")
        title.setAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)

        title_layout = QHBoxLayout()
        title_layout.setSpacing(6)
        title_layout.addWidget(icon_label)
        title_layout.addWidget(title)
        title_layout.addStretch()

        layout.addLayout(controls)
        layout.addLayout(title_layout)
        layout.addSpacing(60)

    def _toggle_maximize(self) -> None:
        if self.parent_window:
            if self.parent_window.isMaximized():
                self.parent_window.showNormal()
            else:
                self.parent_window.showMaximized()

    def mousePressEvent(self, event: QMouseEvent) -> None:
        if event.button() == Qt.MouseButton.LeftButton:
            self._drag_start = (
                event.globalPosition().toPoint() - self.parent_window.pos()
            )

    def mouseMoveEvent(self, event: QMouseEvent) -> None:
        if event.buttons() == Qt.MouseButton.LeftButton:
            if self.parent_window:
                self.parent_window.move(
                    event.globalPosition().toPoint() - self._drag_start
                )


class CaffeineMeter(QGraphicsView):
    """A beautiful gauge showing caffeine level at bedtime."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)
        self.setFixedWidth(280)
        self.setMinimumHeight(120)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setFrameShape(QGraphicsView.Shape.NoFrame)
        self.setStyleSheet("background: transparent; border: none;")

        self.level = 0.0
        self.safe_limit = 50.0
        self._draw()

    def _draw(self) -> None:
        """Draw the meter with arc on top, text on bottom."""
        self.scene.clear()

        width = max(self.width(), 280)
        center_x = width / 2
        center_y = 70
        radius = 55

        arc_item = QGraphicsEllipseItem(
            center_x - radius, center_y - radius, radius * 2, radius * 2
        )
        arc_item.setStartAngle(0 * 16)
        arc_item.setSpanAngle(180 * 16)

        low_color = QColor("#4CAF50")
        mid_color = QColor("#FFC107")
        high_color = QColor("#F44336")

        gradient = QLinearGradient(
            center_x - radius, center_y, center_x + radius, center_y
        )
        gradient.setColorAt(0, low_color)
        gradient.setColorAt(0.5, mid_color)
        gradient.setColorAt(1, high_color)

        arc_item.setBrush(QBrush(gradient))
        arc_item.setPen(QPen(Qt.PenStyle.NoPen))
        self.scene.addItem(arc_item)

        inner_radius = 42
        inner = QGraphicsEllipseItem(
            center_x - inner_radius,
            center_y - inner_radius,
            inner_radius * 2,
            inner_radius * 2,
        )
        inner.setBrush(QBrush(QColor("#1A1A1A")))
        inner.setPen(QPen(Qt.PenStyle.NoPen))
        self.scene.addItem(inner)

        if self.safe_limit > 0:
            level_ratio = min(self.level / (self.safe_limit * 2), 1.0)
            angle = 180 * level_ratio
            angle_rad = angle * pi / 180
            needle_len = 35
            needle_x = center_x + needle_len * cos(angle_rad)
            needle_y = center_y - needle_len * sin(angle_rad)

            from PyQt6.QtWidgets import QGraphicsLineItem

            needle = QGraphicsLineItem(center_x, center_y, needle_x, needle_y)
            needle.setPen(QPen(QColor("#FFFFFF"), 3))
            self.scene.addItem(needle)

        center_dot = QGraphicsEllipseItem(center_x - 4, center_y - 4, 8, 8)
        center_dot.setBrush(QBrush(QColor("#FFFFFF")))
        center_dot.setPen(QPen(Qt.PenStyle.NoPen))
        self.scene.addItem(center_dot)

        low_label = QGraphicsTextItem("Low")
        low_label.setFont(QFont(".AppleSystemUIFont", 8))
        low_label.setDefaultTextColor(QColor("#666666"))
        low_label.setPos(center_x - radius + 5, center_y + 8)
        self.scene.addItem(low_label)

        high_label = QGraphicsTextItem("High")
        high_label.setFont(QFont(".AppleSystemUIFont", 8))
        high_label.setDefaultTextColor(QColor("#666666"))
        high_label.setPos(center_x + radius - 30, center_y + 8)
        self.scene.addItem(high_label)

        status_y = center_y + 25

        if self.level <= self.safe_limit * 0.5:
            status_text = "Sleep well"
            status_color = QColor("#4CAF50")
        elif self.level <= self.safe_limit:
            status_text = "Okay"
            status_color = QColor("#FFC107")
        else:
            status_text = "Too high"
            status_color = QColor("#F44336")

        status = QGraphicsTextItem(status_text)
        status.setFont(QFont(".AppleSystemUIFont", 12, QFont.Weight.Bold))
        status.setDefaultTextColor(status_color)
        status.setPos(center_x - status.boundingRect().width() / 2, status_y)
        self.scene.addItem(status)

        level_text = QGraphicsTextItem(f"~{self.level:.0f}mg at bedtime")
        level_text.setFont(QFont(".AppleSystemUIFont", 9))
        level_text.setDefaultTextColor(QColor("#888888"))
        level_text.setPos(
            center_x - level_text.boundingRect().width() / 2, status_y + 18
        )
        self.scene.addItem(level_text)

    def set_level(self, level: float, safe_limit: float) -> None:
        """Update the meter with new level."""
        self.level = level
        self.safe_limit = safe_limit
        self._draw()

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._draw()


class DoseEditor(QWidget):
    """Editable dose with time and beverage selection."""

    changed = pyqtSignal()
    removed = pyqtSignal()

    def __init__(self, default_time: QTime, default_beverage: int, parent=None):
        super().__init__(parent)
        self.setFixedHeight(50)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        self.setStyleSheet("""
            background: #252525;
            border-left: 3px solid #FF9800;
            border-radius: 10px;
        """)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(10, 0, 10, 0)
        layout.setSpacing(8)
        layout.setAlignment(Qt.AlignmentFlag.AlignVCenter)

        self.time_edit = QTimeEdit()
        self.time_edit.setDisplayFormat("HH:mm")
        self.time_edit.setTime(default_time)
        self.time_edit.setFixedWidth(75)
        self.time_edit.setStyleSheet("""
            QTimeEdit {
                background: #333333;
                border: none;
                border-radius: 6px;
                padding: 4px 8px;
                color: #FFFFFF;
                font-size: 13px;
                font-weight: bold;
            }
        """)
        self.time_edit.timeChanged.connect(self._on_changed)
        layout.addWidget(self.time_edit)

        self.beverage_combo = QComboBox()
        for name, caffeine, _, icon in BEVERAGES:
            self.beverage_combo.addItem(f"{icon} {name} ({caffeine}mg)", caffeine)
        self.beverage_combo.setCurrentIndex(default_beverage)
        self.beverage_combo.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )
        self.beverage_combo.setMinimumWidth(160)
        self.beverage_combo.setStyleSheet("""
            QComboBox {
                background: #333333;
                border: none;
                border-radius: 6px;
                padding: 4px 8px;
                color: #FFFFFF;
                font-size: 11px;
            }
            QComboBox::drop-down {
                width: 0px;
                border: none;
            }
        """)
        self.beverage_combo.currentIndexChanged.connect(self._on_changed)
        layout.addWidget(self.beverage_combo)

        self.remove_btn = QPushButton("−")
        self.remove_btn.setFixedSize(28, 28)
        self.remove_btn.setStyleSheet("""
            QPushButton {
                background: #3D2020;
                border: none;
                border-radius: 14px;
                color: #F44336;
                font-size: 18px;
                font-weight: bold;
            }
            QPushButton:hover {
                background: #F44336;
                color: #FFFFFF;
            }
        """)
        self.remove_btn.clicked.connect(self._on_removed)
        layout.addWidget(self.remove_btn)

        self.setLayout(layout)

    def _on_changed(self) -> None:
        self.changed.emit()

    def _on_removed(self) -> None:
        self.removed.emit()

    def get_caffeine(self) -> float:
        """Get caffeine amount for this dose."""
        return float(self.beverage_combo.currentData())

    def get_time_str(self) -> str:
        """Get time as string."""
        return self.time_edit.time().toString("HH:mm")


class KoffeeUI(QWidget):
    """The main Koffee UI - joyful and simple."""

    CONFIG_PATH = Path.home() / ".config" / "koffee.json"

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Koffee")
        self.setFixedSize(320, 600)
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint)

        self.weight = 70.0
        self.sensitivity = Sensitivity.MEDIUM
        self.wake_time_initial = (7, 0)
        self.sleep_time_initial = (23, 0)
        self.dose_editors = []
        self._initialized = False
        self._saved_doses = None

        self._load_config()
        self._build_ui()
        self._apply_config_to_ui()

        if self._saved_doses:
            self._load_saved_doses()
        else:
            self._add_optimal_doses()

        self._initialized = True
        self._update_display()

    def _load_config(self) -> None:
        """Load configuration from file."""
        if self.CONFIG_PATH.exists():
            try:
                import json

                with open(self.CONFIG_PATH) as f:
                    config = json.load(f)
                self.weight = config.get("weight", 70.0)
                sens_str = config.get("sensitivity", "MEDIUM")
                self.sensitivity = Sensitivity[sens_str]
                self.wake_time_initial = (
                    config.get("wake_hour", 7),
                    config.get("wake_minute", 0),
                )
                self.sleep_time_initial = (
                    config.get("sleep_hour", 23),
                    config.get("sleep_minute", 0),
                )
                self._saved_doses = config.get("doses", None)
            except (json.JSONDecodeError, KeyError):
                self._saved_doses = None
        else:
            self._saved_doses = None

    def _save_config(self) -> None:
        """Save configuration to file."""
        try:
            import json

            self.CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
            doses = []
            for editor in self.dose_editors:
                time_str = editor.get_time_str()
                bev_idx = editor.beverage_combo.currentIndex()
                doses.append({"time": time_str, "beverage": bev_idx})

            config = {
                "weight": self.weight,
                "sensitivity": self.sensitivity.name,
                "wake_hour": self.wake_time.time().hour(),
                "wake_minute": self.wake_time.time().minute(),
                "sleep_hour": self.sleep_time.time().hour(),
                "sleep_minute": self.sleep_time.time().minute(),
                "doses": doses,
            }
            with open(self.CONFIG_PATH, "w") as f:
                json.dump(config, f, indent=2)
        except Exception:
            pass

    def _apply_config_to_ui(self) -> None:
        """Apply loaded config to UI widgets."""
        self.weight_spin.setValue(self.weight)
        for sens, btn in self.sens_buttons.items():
            btn.setChecked(self.sensitivity.name == sens)
        if self.wake_time_initial:
            self.wake_time.setTime(QTime(*self.wake_time_initial))
        if self.sleep_time_initial:
            self.sleep_time.setTime(QTime(*self.sleep_time_initial))

    def _load_saved_doses(self) -> None:
        """Load saved doses from config."""
        self._clear_doses()
        for dose in self._saved_doses:
            time_parts = dose["time"].split(":")
            time = QTime(int(time_parts[0]), int(time_parts[1]))
            bev_idx = min(dose["beverage"], len(BEVERAGES) - 1)
            editor = DoseEditor(time, bev_idx)
            editor.changed.connect(self._on_doses_changed)
            editor.removed.connect(lambda: self._remove_dose(editor))
            self.dose_editors.append(editor)
            self.doses_layout.addWidget(editor)

    def _build_ui(self) -> None:
        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        self.title_bar = TitleBar(self)
        self.title_bar.close_requested.connect(self.close)
        main_layout.addWidget(self.title_bar)

        content = QWidget()
        content.setStyleSheet("background: #1A1A1A;")
        layout = QVBoxLayout(content)
        layout.setSpacing(10)
        layout.setContentsMargins(16, 10, 16, 14)

        body_section = QLabel("YOUR BODY")
        body_section.setFont(QFont(".AppleSystemUIFont", 10, QFont.Weight.Medium))
        body_section.setStyleSheet("color: #666666; background: transparent;")
        layout.addWidget(body_section)

        body_row = QHBoxLayout()
        body_row.setSpacing(12)

        weight_widget = QWidget()
        weight_widget.setFixedHeight(50)
        weight_layout = QVBoxLayout(weight_widget)
        weight_layout.setContentsMargins(0, 0, 0, 0)
        weight_layout.setSpacing(2)

        weight_label = QLabel("Weight")
        weight_label.setFont(QFont(".AppleSystemUIFont", 9))
        weight_label.setStyleSheet("color: #888888; background: transparent;")
        weight_layout.addWidget(weight_label)

        self.weight_spin = QDoubleSpinBox()
        self.weight_spin.setMinimum(40)
        self.weight_spin.setMaximum(150)
        self.weight_spin.setValue(70)
        self.weight_spin.setSuffix(" kg")
        self.weight_spin.setStyleSheet("""
            QDoubleSpinBox {
                background: #252525;
                border: none;
                border-radius: 8px;
                padding: 6px 10px;
                color: #FFFFFF;
                font-size: 14px;
                font-weight: bold;
            }
        """)
        self.weight_spin.valueChanged.connect(self._on_weight_changed)
        weight_layout.addWidget(self.weight_spin)
        body_row.addWidget(weight_widget)

        sens_widget = QWidget()
        sens_widget.setFixedHeight(50)
        sens_layout = QVBoxLayout(sens_widget)
        sens_layout.setContentsMargins(0, 0, 0, 0)
        sens_layout.setSpacing(2)

        sens_label = QLabel("Sensitivity")
        sens_label.setFont(QFont(".AppleSystemUIFont", 9))
        sens_label.setStyleSheet("color: #888888; background: transparent;")
        sens_layout.addWidget(sens_label)

        sens_btn_layout = QHBoxLayout()
        sens_btn_layout.setSpacing(4)
        self.sens_buttons = {}
        for sens, label in [("Low", "L"), ("Medium", "M"), ("High", "H")]:
            btn = QPushButton(label)
            btn.setFixedSize(32, 28)
            btn.setStyleSheet("""
                QPushButton {
                    background: #252525;
                    border: none;
                    border-radius: 6px;
                    color: #888888;
                    font-weight: bold;
                }
                QPushButton:checked {
                    background: #FF9800;
                    color: #FFFFFF;
                }
            """)
            btn.setCheckable(True)
            btn.clicked.connect(
                lambda checked, s=sens: (
                    self._on_sensitivity_changed(s) if checked else None
                )
            )
            sens_btn_layout.addWidget(btn)
            self.sens_buttons[sens] = btn
            if sens == "Medium":
                btn.setChecked(True)
        sens_layout.addLayout(sens_btn_layout)
        body_row.addWidget(sens_widget)

        layout.addLayout(body_row)

        schedule_section = QLabel("SCHEDULE")
        schedule_section.setFont(QFont(".AppleSystemUIFont", 10, QFont.Weight.Medium))
        schedule_section.setStyleSheet("color: #666666; background: transparent;")
        layout.addWidget(schedule_section)

        schedule_row = QHBoxLayout()
        schedule_row.setSpacing(12)

        wake_widget = QWidget()
        wake_widget.setFixedHeight(50)
        wake_layout = QVBoxLayout(wake_widget)
        wake_layout.setContentsMargins(0, 0, 0, 0)
        wake_layout.setSpacing(2)

        wake_label = QLabel("Wake up")
        wake_label.setFont(QFont(".AppleSystemUIFont", 9))
        wake_label.setStyleSheet("color: #888888; background: transparent;")
        wake_layout.addWidget(wake_label)

        self.wake_time = QTimeEdit()
        self.wake_time.setDisplayFormat("HH:mm")
        self.wake_time.setTime(QTime(7, 0))
        self.wake_time.setStyleSheet("""
            QTimeEdit {
                background: #252525;
                border: none;
                border-radius: 8px;
                padding: 6px 10px;
                color: #FFFFFF;
                font-size: 14px;
                font-weight: bold;
            }
        """)
        self.wake_time.timeChanged.connect(self._on_time_changed)
        wake_layout.addWidget(self.wake_time)
        schedule_row.addWidget(wake_widget)

        sleep_widget = QWidget()
        sleep_widget.setFixedHeight(50)
        sleep_layout = QVBoxLayout(sleep_widget)
        sleep_layout.setContentsMargins(0, 0, 0, 0)
        sleep_layout.setSpacing(2)

        sleep_label = QLabel("Sleep")
        sleep_label.setFont(QFont(".AppleSystemUIFont", 9))
        sleep_label.setStyleSheet("color: #888888; background: transparent;")
        sleep_layout.addWidget(sleep_label)

        self.sleep_time = QTimeEdit()
        self.sleep_time.setDisplayFormat("HH:mm")
        self.sleep_time.setTime(QTime(23, 0))
        self.sleep_time.setStyleSheet("""
            QTimeEdit {
                background: #252525;
                border: none;
                border-radius: 8px;
                padding: 6px 10px;
                color: #FFFFFF;
                font-size: 14px;
                font-weight: bold;
            }
        """)
        self.sleep_time.timeChanged.connect(self._on_time_changed)
        sleep_layout.addWidget(self.sleep_time)
        schedule_row.addWidget(sleep_widget)

        layout.addLayout(schedule_row)

        self.meter = CaffeineMeter()
        self.meter.setMinimumWidth(200)
        layout.addWidget(self.meter, alignment=Qt.AlignmentFlag.AlignHCenter)

        doses_label = QLabel("YOUR DOSE PLAN")
        doses_label.setFont(QFont(".AppleSystemUIFont", 10, QFont.Weight.Medium))
        doses_label.setStyleSheet("color: #666666; background: transparent;")
        layout.addWidget(doses_label)

        self.doses_layout = QVBoxLayout()
        self.doses_layout.setSpacing(8)
        layout.addLayout(self.doses_layout)

        add_dose_btn = QPushButton("+ Add dose")
        add_dose_btn.setFixedHeight(36)
        add_dose_btn.setStyleSheet("""
            QPushButton {
                background: #252525;
                border: none;
                border-radius: 8px;
                color: #888888;
                font-size: 12px;
            }
            QPushButton:hover {
                background: #333333;
                color: #FFFFFF;
            }
        """)
        add_dose_btn.clicked.connect(self._add_user_dose)
        layout.addWidget(add_dose_btn)

        self.recommendation_label = QLabel()
        self.recommendation_label.setFont(QFont(".AppleSystemUIFont", 11))
        self.recommendation_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.recommendation_label.setWordWrap(True)
        self.recommendation_label.setStyleSheet(
            "color: #4CAF50; background: #1A2A1A; padding: 10px; border-radius: 8px;"
        )
        layout.addWidget(self.recommendation_label)

        self.reset_btn = QPushButton("✨ Optimize")
        self.reset_btn.setFixedHeight(32)
        self.reset_btn.setStyleSheet("""
            QPushButton {
                background: #252525;
                border: none;
                border-radius: 8px;
                color: #FF9800;
                font-size: 12px;
            }
            QPushButton:hover {
                background: #333333;
            }
        """)
        self.reset_btn.clicked.connect(self._optimize_doses)
        layout.addWidget(self.reset_btn)

        main_layout.addWidget(content)
        self.setLayout(main_layout)

    def _add_dose(self, time: QTime, beverage_index: int) -> None:
        """Add a dose editor with specified time and beverage (for initialization)."""
        editor = DoseEditor(time, beverage_index)
        editor.changed.connect(self._on_doses_changed)
        editor.removed.connect(lambda: self._remove_dose(editor))
        self.dose_editors.append(editor)
        self.doses_layout.addWidget(editor)

    def _add_user_dose(self) -> None:
        """Add a new dose editor for user interaction."""
        wake = self.wake_time.time()
        default_time = wake.addSecs(4 * 3600)
        editor = DoseEditor(default_time, 0)
        editor.changed.connect(self._on_doses_changed)
        editor.removed.connect(lambda: self._remove_dose(editor))
        self.dose_editors.append(editor)
        self.doses_layout.addWidget(editor)
        self._update_display()

    def _remove_dose(self, editor: DoseEditor) -> None:
        """Remove a dose editor."""
        if editor in self.dose_editors:
            self.dose_editors.remove(editor)
            editor.deleteLater()
            self._update_display()

    def _clear_doses(self) -> None:
        """Clear all dose editors."""
        for editor in self.dose_editors:
            editor.deleteLater()
        self.dose_editors = []

    def _add_optimal_doses(self) -> None:
        """Add optimal doses based on current parameters."""
        self._clear_doses()

        result = calculate_optimal_caffeine(
            self.weight,
            self.wake_time.time().toString("HH:mm"),
            self.sleep_time.time().toString("HH:mm"),
            self.sensitivity.name.lower(),
        )

        if result.first_dose.time and result.first_dose.amount > 0:
            time_parts = result.first_dose.time.split(":")
            first_time = QTime(int(time_parts[0]), int(time_parts[1]))
            first_bev = self._find_best_beverage_index(result.first_dose.amount)
            self._add_dose(first_time, first_bev)

        if result.second_dose.time and result.second_dose.amount > 0:
            time_parts = result.second_dose.time.split(":")
            second_time = QTime(int(time_parts[0]), int(time_parts[1]))
            second_bev = self._find_best_beverage_index(result.second_dose.amount)
            self._add_dose(second_time, second_bev)

    def _optimize_doses(self) -> None:
        """Optimize doses: keep first if it fits, adjust rest."""
        safe_limit = self.sensitivity.safe_caffeine_at_bedtime

        result = calculate_optimal_caffeine(
            self.weight,
            self.wake_time.time().toString("HH:mm"),
            self.sleep_time.time().toString("HH:mm"),
            self.sensitivity.name.lower(),
        )

        optimal_first_amount = (
            result.first_dose.amount if result.first_dose.amount else 0
        )
        optimal_second_amount = (
            result.second_dose.amount if result.second_dose.amount else 0
        )
        optimal_total = optimal_first_amount + optimal_second_amount

        saved_first = None
        if self.dose_editors:
            first_editor = self.dose_editors[0]
            saved_first = {
                "time": first_editor.time_edit.time(),
                "caffeine": first_editor.get_caffeine(),
            }

        self._clear_doses()

        doses_to_add = []
        total_caffeine = 0

        if saved_first and saved_first["caffeine"] <= optimal_total * 1.1:
            first_bev = self._find_best_beverage_index(saved_first["caffeine"])
            editor = DoseEditor(saved_first["time"], first_bev)
            editor.changed.connect(self._on_doses_changed)
            editor.removed.connect(lambda: self._remove_dose(editor))
            doses_to_add.append(editor)
            total_caffeine += saved_first["caffeine"]

        if result.first_dose.time:
            time_parts = result.first_dose.time.split(":")
            first_time = QTime(int(time_parts[0]), int(time_parts[1]))

            if not doses_to_add or total_caffeine < optimal_first_amount * 0.9:
                first_bev = self._find_best_beverage_index(result.first_dose.amount)
                editor = DoseEditor(first_time, first_bev)
                editor.changed.connect(self._on_doses_changed)
                editor.removed.connect(lambda: self._remove_dose(editor))
                doses_to_add.append(editor)
                total_caffeine += result.first_dose.amount

        if result.second_dose.time and total_caffeine < safe_limit * 1.5:
            time_parts = result.second_dose.time.split(":")
            second_time = QTime(int(time_parts[0]), int(time_parts[1]))
            second_bev = self._find_best_beverage_index(result.second_dose.amount)
            editor = DoseEditor(second_time, second_bev)
            editor.changed.connect(self._on_doses_changed)
            editor.removed.connect(lambda: self._remove_dose(editor))
            doses_to_add.append(editor)

        for editor in doses_to_add:
            self.dose_editors.append(editor)
            self.doses_layout.addWidget(editor)

        self._update_display()

    def _find_best_beverage_index(self, amount: float) -> int:
        """Find the beverage index that best matches the amount."""
        best_idx = 0
        best_diff = float("inf")

        for i, (_, caffeine, _, _) in enumerate(BEVERAGES):
            count = amount / caffeine
            diff = abs(count - 1.0)
            if diff < best_diff:
                best_diff = diff
                best_idx = i

        return best_idx

    def _on_doses_changed(self) -> None:
        """Handle dose changes."""
        if self._initialized:
            self._update_display()

    def _on_weight_changed(self, value: float) -> None:
        self.weight = value
        if self._initialized:
            self._add_optimal_doses()
            self._update_display()
            self._save_config()

    def _on_time_changed(self) -> None:
        """Handle time parameter changes."""
        if self._initialized:
            self._add_optimal_doses()
            self._update_display()
            self._save_config()

    def _on_sensitivity_changed(self, sens: str) -> None:
        sens_map = {
            "Low": Sensitivity.LOW,
            "Medium": Sensitivity.MEDIUM,
            "High": Sensitivity.HIGH,
        }
        self.sensitivity = sens_map[sens]
        for s, btn in self.sens_buttons.items():
            btn.setChecked(s == sens)
        if self._initialized:
            self._add_optimal_doses()
            self._update_display()
            self._save_config()

    def _calculate_caffeine_at_bedtime(self) -> float:
        """Calculate total caffeine at bedtime from user doses."""
        sleep_str = self.sleep_time.time().toString("HH:mm")
        sleep_dt = datetime.datetime.strptime(sleep_str, "%H:%M")
        wake_str = self.wake_time.time().toString("HH:mm")
        wake_dt = datetime.datetime.strptime(wake_str, "%H:%M")

        if sleep_dt <= wake_dt:
            sleep_dt += datetime.timedelta(days=1)

        total = 0.0
        half_life = 5.0

        for editor in self.dose_editors:
            dose_time_str = editor.get_time_str()
            dose_dt = datetime.datetime.strptime(dose_time_str, "%H:%M")
            amount = editor.get_caffeine()

            if dose_dt <= wake_dt:
                dose_dt += datetime.timedelta(days=1)

            hours_elapsed = (sleep_dt - dose_dt).total_seconds() / 3600
            if hours_elapsed < 0:
                continue

            remaining = amount * math.pow(0.5, hours_elapsed / half_life)
            total += remaining

        return total

    def _update_display(self) -> None:
        safe_limit = self.sensitivity.safe_caffeine_at_bedtime
        caffeine_at_bedtime = self._calculate_caffeine_at_bedtime()
        self.meter.set_level(caffeine_at_bedtime, safe_limit)

        result = calculate_optimal_caffeine(
            self.weight,
            self.wake_time.time().toString("HH:mm"),
            self.sleep_time.time().toString("HH:mm"),
            self.sensitivity.name.lower(),
        )

        optimal_total = result.first_dose.amount + result.second_dose.amount
        user_total = sum(editor.get_caffeine() for editor in self.dose_editors)
        total_diff = abs(user_total - optimal_total)

        if not self.dose_editors:
            self.recommendation_label.setText("No doses planned")
            self.recommendation_label.setStyleSheet(
                "color: #888888; background: #252525; padding: 10px; border-radius: 8px;"
            )
        elif caffeine_at_bedtime <= safe_limit * 0.5 and total_diff < 20:
            self.recommendation_label.setText(
                "✅ Optimal - great caffeine plan for sleep"
            )
            self.recommendation_label.setStyleSheet(
                "color: #4CAF50; background: #1A2A1A; padding: 10px; border-radius: 8px;"
            )
        elif caffeine_at_bedtime <= safe_limit * 0.5:
            self.recommendation_label.setText("✅ Sleep well - under limit")
            self.recommendation_label.setStyleSheet(
                "color: #4CAF50; background: #1A2A1A; padding: 10px; border-radius: 8px;"
            )
        elif caffeine_at_bedtime <= safe_limit:
            self.recommendation_label.setText("⚠️ Okay - some caffeine at bedtime")
            self.recommendation_label.setStyleSheet(
                "color: #FFC107; background: #2A2A1A; padding: 10px; border-radius: 8px;"
            )
        else:
            excess = caffeine_at_bedtime - safe_limit
            self.recommendation_label.setText(
                f"❌ Too high - {excess:.0f}mg over limit"
            )
            self.recommendation_label.setStyleSheet(
                "color: #F44336; background: #2A1A1A; padding: 10px; border-radius: 8px;"
            )

    def showEvent(self, event) -> None:
        """Apply rounded corners after window is shown."""
        super().showEvent(event)
        self._apply_rounded_corners()

    def _apply_rounded_corners(self) -> None:
        """Apply rounded corners for macOS."""
        from PyQt6.QtCore import QRectF
        from PyQt6.QtGui import QPainterPath, QRegion

        radius = 12
        rect = QRectF(self.rect())
        path = QPainterPath()
        path.addRoundedRect(rect, radius, radius)
        region = QRegion(path.toFillPolygon().toPolygon())
        self.setMask(region)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setFont(QFont(".AppleSystemUIFont", 12))
    window = KoffeeUI()
    window.show()
    sys.exit(app.exec())
