#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "scanner_plugin.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here is in the units expected by the server, which means
  // physical pixels on Windows.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterGeneratedPlugins(flutter_controller_->engine());
  
  // Register scanner method channel
  RegisterScannerMethodChannel();
  
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show" callback is
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
FlutterWindow::MessageHandler(HWND hwnd,
                              UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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

void FlutterWindow::RegisterScannerMethodChannel() {
  auto messenger = flutter_controller_->engine()->messenger();
  
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
    messenger, "arsiv_uygulamasi/tarayici", &flutter::StandardMethodCodec::GetInstance());
  
  channel->SetMethodCallHandler([&](const flutter::MethodCall<flutter::EncodableValue>& call,
                                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name().compare("findScanners") == 0) {
      HandleFindScanners(call, std::move(result));
    } else if (call.method_name().compare("findWIAScanners") == 0) {
      HandleFindWIAScanners(call, std::move(result));
    } else if (call.method_name().compare("scanDocument") == 0) {
      HandleScanDocument(call, std::move(result));
    } else if (call.method_name().compare("checkScannerStatus") == 0) {
      HandleCheckScannerStatus(call, std::move(result));
    } else if (call.method_name().compare("getScannerSettings") == 0) {
      HandleGetScannerSettings(call, std::move(result));
    } else {
      result->NotImplemented();
    }
  });
  
  // Store the channel to keep it alive
  scanner_channel_ = std::move(channel);
}

void FlutterWindow::HandleFindScanners(const flutter::MethodCall<flutter::EncodableValue>& call,
                                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    char buffer[4096];
    int length = FindScanners(buffer, sizeof(buffer));
    
    if (length > 0) {
      std::string scanners_str(buffer, length);
      std::vector<flutter::EncodableValue> scanners;
      
      // Split by '|' delimiter
      std::stringstream ss(scanners_str);
      std::string scanner;
      while (std::getline(ss, scanner, '|')) {
        if (!scanner.empty()) {
          scanners.push_back(flutter::EncodableValue(scanner));
        }
      }
      
      result->Success(flutter::EncodableValue(scanners));
    } else {
      result->Success(flutter::EncodableValue(std::vector<flutter::EncodableValue>()));
    }
  } catch (const std::exception& e) {
    result->Error("SCANNER_ERROR", "Failed to find scanners", flutter::EncodableValue(e.what()));
  }
}

void FlutterWindow::HandleFindWIAScanners(const flutter::MethodCall<flutter::EncodableValue>& call,
                                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    char buffer[4096];
    int length = FindScanners(buffer, sizeof(buffer));
    
    if (length > 0) {
      std::string scanners_str(buffer, length);
      result->Success(flutter::EncodableValue(scanners_str));
    } else {
      result->Success(flutter::EncodableValue(""));
    }
  } catch (const std::exception& e) {
    result->Error("WIA_ERROR", "WIA scanner enumeration failed", flutter::EncodableValue(e.what()));
  }
}

void FlutterWindow::HandleScanDocument(const flutter::MethodCall<flutter::EncodableValue>& call,
                                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENTS", "Arguments must be a map", flutter::EncodableValue());
      return;
    }
    
    auto scanner_name_it = arguments->find(flutter::EncodableValue("scannerName"));
    auto output_format_it = arguments->find(flutter::EncodableValue("outputFormat"));
    
    if (scanner_name_it == arguments->end()) {
      result->Error("MISSING_ARGUMENT", "scannerName is required", flutter::EncodableValue());
      return;
    }
    
    std::string scanner_name = std::get<std::string>(scanner_name_it->second);
    std::string output_format = "pdf";
    
    if (output_format_it != arguments->end()) {
      output_format = std::get<std::string>(output_format_it->second);
    }
    
    // Generate output path
    char temp_path[MAX_PATH];
    GetTempPathA(MAX_PATH, temp_path);
    
    std::time_t now = std::time(nullptr);
    std::string output_path = std::string(temp_path) + "scanned_document_" + 
                             std::to_string(now) + "." + output_format;
    
    char result_buffer[1024];
    int length = ScanDocument(scanner_name.c_str(), output_path.c_str(), result_buffer, sizeof(result_buffer));
    
    if (length > 0) {
      std::string result_path(result_buffer, length);
      result->Success(flutter::EncodableValue(result_path));
    } else {
      result->Error("SCAN_FAILED", "Document scanning failed", flutter::EncodableValue());
    }
  } catch (const std::exception& e) {
    result->Error("SCAN_ERROR", "Scanning error occurred", flutter::EncodableValue(e.what()));
  }
}

void FlutterWindow::HandleCheckScannerStatus(const flutter::MethodCall<flutter::EncodableValue>& call,
                                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENTS", "Arguments must be a map", flutter::EncodableValue());
      return;
    }
    
    auto scanner_name_it = arguments->find(flutter::EncodableValue("scannerName"));
    if (scanner_name_it == arguments->end()) {
      result->Error("MISSING_ARGUMENT", "scannerName is required", flutter::EncodableValue());
      return;
    }
    
    // For now, assume scanner is available if it was found
    result->Success(flutter::EncodableValue(true));
  } catch (const std::exception& e) {
    result->Error("STATUS_ERROR", "Status check failed", flutter::EncodableValue(e.what()));
  }
}

void FlutterWindow::HandleGetScannerSettings(const flutter::MethodCall<flutter::EncodableValue>& call,
                                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    // Return default scanner settings
    flutter::EncodableMap settings;
    settings[flutter::EncodableValue("resolution")] = flutter::EncodableValue(
      std::vector<flutter::EncodableValue>{
        flutter::EncodableValue(100), flutter::EncodableValue(200), 
        flutter::EncodableValue(300), flutter::EncodableValue(600), 
        flutter::EncodableValue(1200)
      }
    );
    settings[flutter::EncodableValue("colorModes")] = flutter::EncodableValue(
      std::vector<flutter::EncodableValue>{
        flutter::EncodableValue("color"), flutter::EncodableValue("grayscale"), 
        flutter::EncodableValue("blackwhite")
      }
    );
    settings[flutter::EncodableValue("paperSizes")] = flutter::EncodableValue(
      std::vector<flutter::EncodableValue>{
        flutter::EncodableValue("A4"), flutter::EncodableValue("A3"), 
        flutter::EncodableValue("Letter"), flutter::EncodableValue("Legal")
      }
    );
    settings[flutter::EncodableValue("outputFormats")] = flutter::EncodableValue(
      std::vector<flutter::EncodableValue>{
        flutter::EncodableValue("pdf"), flutter::EncodableValue("jpeg"), 
        flutter::EncodableValue("png"), flutter::EncodableValue("tiff")
      }
    );
    settings[flutter::EncodableValue("maxPages")] = flutter::EncodableValue(100);
    settings[flutter::EncodableValue("duplex")] = flutter::EncodableValue(true);
    
    result->Success(flutter::EncodableValue(settings));
  } catch (const std::exception& e) {
    result->Error("SETTINGS_ERROR", "Failed to get scanner settings", flutter::EncodableValue(e.what()));
  }
}
