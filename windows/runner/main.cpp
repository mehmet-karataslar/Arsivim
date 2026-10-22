#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {
// All copies of this application in the current Windows session use the same
// Documents archive, even if their executable folders differ.
class ArchiveInstance {
 public:
  ArchiveInstance() {
    handle_ = ::CreateMutexW(nullptr, FALSE, L"Local\\Arsivim.Archive.Instance");
    already_running_ = handle_ && ::GetLastError() == ERROR_ALREADY_EXISTS;
  }
  ~ArchiveInstance() { if (handle_) ::CloseHandle(handle_); }
  bool valid() const { return handle_ != nullptr; }
  bool already_running() const { return already_running_; }
 private:
  HANDLE handle_ = nullptr;
  bool already_running_ = false;
};
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  ArchiveInstance archive_instance;
  if (!archive_instance.valid()) {
    ::MessageBoxW(nullptr, L"Arsiv kilidi alinamadi. Uygulamayi yeniden acin.",
                  L"Arsivim", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  // The old published runner did not use a mutex. Recognize its existing
  // window as well, before Flutter or the database is initialized.
  HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"arsiv_uygulamasi");
  if (archive_instance.already_running() || existing) {
    if (existing) {
      if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
    }
    return EXIT_SUCCESS;
  }

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
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"arsiv_uygulamasi", origin, size)) {
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
