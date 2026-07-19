#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Keep the compact navigation rail, workspace header, and composer usable on
// small desktop windows. Values describe the Flutter client area at 100% DPI.
constexpr int kMinimumClientWidth = 600;
constexpr int kMinimumClientHeight = 720;

void ApplyMinimumWindowSize(HWND hwnd, LPARAM lparam) {
  auto* minmax_info = reinterpret_cast<MINMAXINFO*>(lparam);
  const UINT dpi = GetDpiForWindow(hwnd);
  RECT frame = {
      0,
      0,
      MulDiv(kMinimumClientWidth, dpi, USER_DEFAULT_SCREEN_DPI),
      MulDiv(kMinimumClientHeight, dpi, USER_DEFAULT_SCREEN_DPI),
  };
  const DWORD style = static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_STYLE));
  const DWORD extended_style =
      static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_EXSTYLE));
  if (AdjustWindowRectExForDpi(&frame, style, FALSE, extended_style, dpi)) {
    minmax_info->ptMinTrackSize.x = frame.right - frame.left;
    minmax_info->ptMinTrackSize.y = frame.bottom - frame.top;
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_GETMINMAXINFO) {
    ApplyMinimumWindowSize(hwnd, lparam);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
