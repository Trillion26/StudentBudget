#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cwchar>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Opens the app in a phone-sized window (iPhone 14/15 by default).
// Set STUDENT_BUDGET_WINDOW_SIZE=375x667 (iPhone SE) or 430x932 (Pro Max)
// to try other sizes; .vscode/launch.json has ready-made entries.
Win32Window::Size PhoneWindowSize() {
  unsigned int width = 390;
  unsigned int height = 844;
  wchar_t value[32] = {0};
  DWORD length = ::GetEnvironmentVariableW(L"STUDENT_BUDGET_WINDOW_SIZE", value, 32);
  if (length > 0 && length < 32) {
    unsigned int w = 0;
    unsigned int h = 0;
    if (swscanf_s(value, L"%ux%u", &w, &h) == 2 && w >= 320 && h >= 480 && w <= 2000 && h <= 2000) {
      width = w;
      height = h;
    }
  }
  return Win32Window::Size(width, height);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size = PhoneWindowSize();
  if (!window.Create(L"Emily\u2019s Budget", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
