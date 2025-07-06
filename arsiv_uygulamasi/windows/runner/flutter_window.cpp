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
  RegisterPlugins(flutter_controller_->engine());
  
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
    } else if (call.method_name().compare("advancedScan") == 0) {
      HandleAdvancedScan(call, std::move(result));
    } else if (call.method_name().compare("multiPageScan") == 0) {
      HandleMultiPageScan(call, std::move(result));
    } else if (call.method_name().compare("testScannerConnection") == 0) {
      HandleTestScannerConnection(call, std::move(result));
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
    } else if (length == -1) {
      // Extract error code from buffer
      std::string error_code(result_buffer);
      
      // Map specific error codes to Flutter errors
      if (error_code == "SCANNER_NOT_FOUND") {
        result->Error("SCANNER_NOT_FOUND", "Scanner not found or disconnected", flutter::EncodableValue());
      } else if (error_code == "SCANNER_BUSY") {
        result->Error("SCANNER_BUSY", "Scanner is busy with another operation", flutter::EncodableValue());
      } else if (error_code == "NO_PAPER") {
        result->Error("NO_PAPER", "No paper in scanner feeder", flutter::EncodableValue());
      } else if (error_code == "PAPER_JAM") {
        result->Error("PAPER_JAM", "Paper jam detected in scanner", flutter::EncodableValue());
      } else if (error_code == "COVER_OPEN") {
        result->Error("COVER_OPEN", "Scanner cover is open", flutter::EncodableValue());
      } else if (error_code == "SCANNER_CONNECTION_FAILED") {
        result->Error("SCANNER_CONNECTION_FAILED", "Failed to connect to scanner", flutter::EncodableValue());
      } else if (error_code == "SCANNER_PROPERTIES_FAILED") {
        result->Error("SCANNER_PROPERTIES_FAILED", "Failed to set scanner properties", flutter::EncodableValue());
      } else if (error_code == "DATA_TRANSFER_FAILED") {
        result->Error("DATA_TRANSFER_FAILED", "Data transfer from scanner failed", flutter::EncodableValue());
      } else if (error_code == "SCAN_OPERATION_FAILED") {
        result->Error("SCAN_OPERATION_FAILED", "Scan operation failed", flutter::EncodableValue());
      } else if (error_code == "PLUGIN_NOT_INITIALIZED") {
        result->Error("PLUGIN_NOT_INITIALIZED", "Scanner plugin not initialized", flutter::EncodableValue());
      } else if (error_code == "UNKNOWN_SCANNER_ERROR") {
        result->Error("UNKNOWN_SCANNER_ERROR", "Unknown scanner error occurred", flutter::EncodableValue());
      } else if (error_code == "BUFFER_TOO_SMALL") {
        result->Error("BUFFER_TOO_SMALL", "Buffer too small for result", flutter::EncodableValue());
      } else if (error_code == "NETWORK_SCANNER_UNREACHABLE") {
        result->Error("NETWORK_SCANNER_UNREACHABLE", "Network scanner unreachable", flutter::EncodableValue());
      } else if (error_code == "SCANNER_OFFLINE") {
        result->Error("SCANNER_OFFLINE", "Scanner is offline", flutter::EncodableValue());
      } else if (error_code == "SCANNER_TIMEOUT") {
        result->Error("SCANNER_TIMEOUT", "Scanner connection timeout", flutter::EncodableValue());
      } else {
        result->Error("SCAN_ERROR", "Scanning error: " + error_code, flutter::EncodableValue());
      }
    } else {
      result->Error("SCAN_FAILED", "Document scanning failed - check scanner status", flutter::EncodableValue());
    }
  } catch (const std::exception& e) {
    std::string error_message = e.what();
    
    // Map C++ exceptions to Flutter error codes
    if (error_message == "SCANNER_NOT_FOUND") {
      result->Error("SCANNER_NOT_FOUND", "Scanner not found or disconnected", flutter::EncodableValue());
    } else if (error_message == "SCANNER_BUSY") {
      result->Error("SCANNER_BUSY", "Scanner is busy with another operation", flutter::EncodableValue());
    } else if (error_message == "NO_PAPER") {
      result->Error("NO_PAPER", "No paper in scanner feeder", flutter::EncodableValue());
    } else if (error_message == "PAPER_JAM") {
      result->Error("PAPER_JAM", "Paper jam detected in scanner", flutter::EncodableValue());
    } else if (error_message == "COVER_OPEN") {
      result->Error("COVER_OPEN", "Scanner cover is open", flutter::EncodableValue());
    } else if (error_message == "SCANNER_CONNECTION_FAILED") {
      result->Error("SCANNER_CONNECTION_FAILED", "Failed to connect to scanner", flutter::EncodableValue());
    } else if (error_message == "SCANNER_PROPERTIES_FAILED") {
      result->Error("SCANNER_PROPERTIES_FAILED", "Failed to set scanner properties", flutter::EncodableValue());
    } else if (error_message == "DATA_TRANSFER_FAILED") {
      result->Error("DATA_TRANSFER_FAILED", "Data transfer from scanner failed", flutter::EncodableValue());
    } else if (error_message == "SCAN_OPERATION_FAILED") {
      result->Error("SCAN_OPERATION_FAILED", "Scan operation failed", flutter::EncodableValue());
    } else {
      result->Error("SCAN_ERROR", "Scanning error occurred", flutter::EncodableValue(error_message));
    }
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

void FlutterWindow::HandleAdvancedScan(const flutter::MethodCall<flutter::EncodableValue>& call,
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
    
    std::string scanner_name = std::get<std::string>(scanner_name_it->second);
    
    // Extract optional parameters
    int resolution = 300;
    std::string color_mode = "color";
    std::string paper_size = "A4";
    std::string output_format = "pdf";
    bool duplex = false;
    int quality = 80;
    
    auto resolution_it = arguments->find(flutter::EncodableValue("resolution"));
    if (resolution_it != arguments->end()) {
      resolution = std::get<int>(resolution_it->second);
    }
    
    auto color_mode_it = arguments->find(flutter::EncodableValue("colorMode"));
    if (color_mode_it != arguments->end()) {
      color_mode = std::get<std::string>(color_mode_it->second);
    }
    
    auto paper_size_it = arguments->find(flutter::EncodableValue("paperSize"));
    if (paper_size_it != arguments->end()) {
      paper_size = std::get<std::string>(paper_size_it->second);
    }
    
    auto output_format_it = arguments->find(flutter::EncodableValue("outputFormat"));
    if (output_format_it != arguments->end()) {
      output_format = std::get<std::string>(output_format_it->second);
    }
    
    auto duplex_it = arguments->find(flutter::EncodableValue("duplex"));
    if (duplex_it != arguments->end()) {
      duplex = std::get<bool>(duplex_it->second);
    }
    
    auto quality_it = arguments->find(flutter::EncodableValue("quality"));
    if (quality_it != arguments->end()) {
      quality = std::get<int>(quality_it->second);
    }
    
    // Generate output path
    char temp_path[MAX_PATH];
    GetTempPathA(MAX_PATH, temp_path);
    
    std::time_t now = std::time(nullptr);
    std::string output_path = std::string(temp_path) + "advanced_scan_" + 
                             std::to_string(now) + "." + output_format;
    
    // Use the existing ScanDocument function but with advanced parameters
    // In a real implementation, you would modify the scanner plugin to accept these parameters
    char result_buffer[1024];
    int length = ScanDocument(scanner_name.c_str(), output_path.c_str(), result_buffer, sizeof(result_buffer));
    
    if (length > 0) {
      std::string result_path(result_buffer, length);
      result->Success(flutter::EncodableValue(result_path));
    } else if (length == -1) {
      // Extract error code from buffer
      std::string error_code(result_buffer);
      result->Error(error_code, "Advanced scanning failed: " + error_code, flutter::EncodableValue());
    } else {
      result->Error("ADVANCED_SCAN_FAILED", "Advanced document scanning failed", flutter::EncodableValue());
    }
  } catch (const std::exception& e) {
    result->Error("ADVANCED_SCAN_ERROR", "Advanced scanning error occurred", flutter::EncodableValue(e.what()));
  }
}

void FlutterWindow::HandleMultiPageScan(const flutter::MethodCall<flutter::EncodableValue>& call,
                                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENTS", "Arguments must be a map", flutter::EncodableValue());
      return;
    }
    
    auto scanner_name_it = arguments->find(flutter::EncodableValue("scannerName"));
    auto page_count_it = arguments->find(flutter::EncodableValue("pageCount"));
    
    if (scanner_name_it == arguments->end() || page_count_it == arguments->end()) {
      result->Error("MISSING_ARGUMENT", "scannerName and pageCount are required", flutter::EncodableValue());
      return;
    }
    
    std::string scanner_name = std::get<std::string>(scanner_name_it->second);
    int page_count = std::get<int>(page_count_it->second);
    
    // Extract optional parameters
    int resolution = 300;
    std::string output_format = "pdf";
    
    auto resolution_it = arguments->find(flutter::EncodableValue("resolution"));
    if (resolution_it != arguments->end()) {
      resolution = std::get<int>(resolution_it->second);
    }
    
    auto output_format_it = arguments->find(flutter::EncodableValue("outputFormat"));
    if (output_format_it != arguments->end()) {
      output_format = std::get<std::string>(output_format_it->second);
    }
    
    // Scan multiple pages
    std::vector<flutter::EncodableValue> scanned_pages;
    
    for (int i = 0; i < page_count; ++i) {
      // Generate output path for each page
      char temp_path[MAX_PATH];
      GetTempPathA(MAX_PATH, temp_path);
      
      std::time_t now = std::time(nullptr);
      std::string output_path = std::string(temp_path) + "multi_page_scan_" + 
                               std::to_string(now) + "_page_" + std::to_string(i + 1) + "." + output_format;
      
      char result_buffer[1024];
      int length = ScanDocument(scanner_name.c_str(), output_path.c_str(), result_buffer, sizeof(result_buffer));
      
      if (length > 0) {
        std::string result_path(result_buffer, length);
        scanned_pages.push_back(flutter::EncodableValue(result_path));
      } else if (length == -1) {
        // Extract error code from buffer
        std::string error_code(result_buffer);
        result->Error(error_code, "Multi-page scanning failed at page " + std::to_string(i + 1) + ": " + error_code, flutter::EncodableValue());
        return;
      } else {
        result->Error("MULTI_PAGE_SCAN_FAILED", "Multi-page scanning failed at page " + std::to_string(i + 1), flutter::EncodableValue());
        return;
      }
    }
    
    result->Success(flutter::EncodableValue(scanned_pages));
  } catch (const std::exception& e) {
    result->Error("MULTI_PAGE_SCAN_ERROR", "Multi-page scanning error occurred", flutter::EncodableValue(e.what()));
  }
}

void FlutterWindow::HandleTestScannerConnection(const flutter::MethodCall<flutter::EncodableValue>& call,
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
    
    std::string scanner_name = std::get<std::string>(scanner_name_it->second);
    
    // Test connection by trying to find the scanner
    char buffer[4096];
    int length = FindScanners(buffer, sizeof(buffer));
    
    if (length > 0) {
      std::string scanners_str(buffer, length);
      
      // Check if the requested scanner is in the list
      if (scanners_str.find(scanner_name) != std::string::npos) {
        result->Success(flutter::EncodableValue(true));
      } else {
        result->Success(flutter::EncodableValue(false));
      }
    } else {
      result->Success(flutter::EncodableValue(false));
    }
  } catch (const std::exception& e) {
    result->Error("CONNECTION_TEST_ERROR", "Scanner connection test failed", flutter::EncodableValue(e.what()));
  }
}
