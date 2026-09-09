from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from timesheet_app.ocr.preprocess import (
    MAX_PREPROCESSED_PIXELS,
    MAX_UPSCALE_FACTOR,
    TARGET_MIN_WIDTH,
    _bounded_upscale_factor,
    prepare_for_ocr,
)


class PreprocessSizingTest(unittest.TestCase):
    def test_normal_phone_screenshot_can_reach_target_width(self) -> None:
        scale = _bounded_upscale_factor(1080, 2400)
        self.assertAlmostEqual(scale, TARGET_MIN_WIDTH / 1080)

    def test_extreme_narrow_image_is_limited_by_scale_and_pixel_budget(self) -> None:
        width, height = 200, 10_000
        scale = _bounded_upscale_factor(width, height)
        self.assertLessEqual(scale, MAX_UPSCALE_FACTOR)
        self.assertLessEqual(width * height * scale * scale, MAX_PREPROCESSED_PIXELS + 1)

    def test_large_source_is_downscaled_to_pixel_budget(self) -> None:
        width, height = 1000, 50_000
        scale = _bounded_upscale_factor(width, height)
        self.assertLess(scale, 1.0)
        self.assertLessEqual(width * height * scale * scale, MAX_PREPROCESSED_PIXELS + 1)
        self.assertEqual(_bounded_upscale_factor(1600, 2000), 1.0)

    def test_source_over_hard_limit_is_rejected_before_processing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "small.png"
            Image.new("RGB", (20, 20), "white").save(source)
            with patch("timesheet_app.ocr.preprocess.MAX_SOURCE_PIXELS", 100):
                with self.assertRaises(Image.DecompressionBombError):
                    prepare_for_ocr(source)


if __name__ == "__main__":
    unittest.main()
