#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <sstream>
#include <ctime>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  
  // Scanner method channel
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> scanner_channel_;
  
  // Method channel handlers
  void RegisterScannerMethodChannel();
  void HandleFindScanners(const flutter::MethodCall<flutter::EncodableValue>& call,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleFindWIAScanners(const flutter::MethodCall<flutter::EncodableValue>& call,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleScanDocument(const flutter::MethodCall<flutter::EncodableValue>& call,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleCheckScannerStatus(const flutter::MethodCall<flutter::EncodableValue>& call,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleGetScannerSettings(const flutter::MethodCall<flutter::EncodableValue>& call,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
