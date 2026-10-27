from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("configure_platforms.py")


class ConfigurePlatformsTest(unittest.TestCase):
    def _run_with_app_delegate(self, source: str) -> str:
        with tempfile.TemporaryDirectory() as temp_dir:
            app_root = Path(temp_dir) / "app"
            tool_dir = app_root / "tool"
            delegate_path = app_root / "ios" / "Runner" / "AppDelegate.swift"
            tool_dir.mkdir(parents=True)
            delegate_path.parent.mkdir(parents=True)
            shutil.copy2(SCRIPT, tool_dir / SCRIPT.name)
            delegate_path.write_text(source, encoding="utf-8")

            command = [sys.executable, str(tool_dir / SCRIPT.name)]
            subprocess.run(command, check=True, cwd=app_root)
            subprocess.run(command, check=True, cwd=app_root)
            return delegate_path.read_text(encoding="utf-8")

    def test_configures_implicit_engine_app_delegate_idempotently(self) -> None:
        source = """import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
"""
        configured = self._run_with_app_delegate(source)
        delegate = (
            "UNUserNotificationCenter.current().delegate = "
            "self as UNUserNotificationCenterDelegate"
        )

        self.assertIn("import UserNotifications", configured)
        self.assertEqual(configured.count(delegate), 1)
        self.assertLess(
            configured.index(delegate),
            configured.index("return super.application"),
        )

    def test_configures_legacy_app_delegate(self) -> None:
        source = """import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
"""
        configured = self._run_with_app_delegate(source)

        self.assertEqual(configured.count("UNUserNotificationCenter.current()"), 1)
        self.assertLess(
            configured.index("UNUserNotificationCenter.current()"),
            configured.index("return super.application"),
        )


if __name__ == "__main__":
    unittest.main()
