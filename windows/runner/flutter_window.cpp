#include "flutter_window.h"

#include <optional>
#include <regex>
#include <chrono>

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
    } else if (call.method_name().compare("discoverNetworkScanners") == 0) {
      HandleDiscoverNetworkScanners(call, std::move(result));
    } else if (call.method_name().compare("checkWiFiStatus") == 0) {
      HandleCheckWiFiStatus(call, std::move(result));
    } else if (call.method_name().compare("testNetworkScannerQuality") == 0) {
      HandleTestNetworkScannerQuality(call, std::move(result));
    } else if (call.method_name().compare("getWiFiScannerSettings") == 0) {
      HandleGetWiFiScannerSettings(call, std::move(result));
    } else if (call.method_name().compare("getNetworkScannerIP") == 0) {
      HandleGetNetworkScannerIP(call, std::move(result));
    } else if (call.method_name().compare("wifiOptimizedScan") == 0) {
      HandleWiFiOptimizedScan(call, std::move(result));
    } else if (call.method_name().compare("networkTroubleshooting") == 0) {
      HandleNetworkTroubleshooting(call, std::move(result));
    } else if (call.method_name().compare("scanLocalNetwork") == 0) {
      HandleScanLocalNetwork(call, std::move(result));
    } else {
      result->NotImplemented();
    }
  });
  
  // Store the channel to keep it alive
  scanner_channel_ = std::move(channel);
}

void FlutterWindow::HandleFindScanners(const flutter::MethodCall<flutter::EncodableValue>& call,
                                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Run scanner discovery in background thread to avoid UI blocking
  RunInBackground<std::vector<std::string>>(
    []() -> std::vector<std::string> {
    char buffer[4096];
    int length = FindScanners(buffer, sizeof(buffer));
    
      std::vector<std::string> scanners;
    if (length > 0) {
      std::string scanners_str(buffer, length);
      std::stringstream ss(scanners_str);
      std::string scanner;
      while (std::getline(ss, scanner, '|')) {
        if (!scanner.empty()) {
            scanners.push_back(scanner);
        }
      }
      }
      return scanners;
    },
    std::move(result),
    [](const std::vector<std::string>& scanners) -> flutter::EncodableValue {
      std::vector<flutter::EncodableValue> flutter_scanners;
      for (const auto& scanner : scanners) {
        flutter_scanners.push_back(flutter::EncodableValue(scanner));
      }
      return flutter::EncodableValue(flutter_scanners);
    },
    [](const std::exception& e) {
      // Error handler will be called by RunInBackground
  }
  );
}

void FlutterWindow::HandleFindWIAScanners(const flutter::MethodCall<flutter::EncodableValue>& call,
                                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Run WIA scanner discovery in background thread
  RunInBackground<std::string>(
    []() -> std::string {
    char buffer[4096];
    int length = FindScanners(buffer, sizeof(buffer));
    
    if (length > 0) {
        return std::string(buffer, length);
      }
      return "";
    },
    std::move(result),
    [](const std::string& scanners_str) -> flutter::EncodableValue {
      return flutter::EncodableValue(scanners_str);
    }
  );
}

void FlutterWindow::HandleScanDocument(const flutter::MethodCall<flutter::EncodableValue>& call,
                                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
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
  
  auto output_format_it = arguments->find(flutter::EncodableValue("outputFormat"));
    std::string output_format = "pdf";
    if (output_format_it != arguments->end()) {
      output_format = std::get<std::string>(output_format_it->second);
    }
    
  // Run scan operation in background thread with timeout
  RunInBackground<std::string>(
    [scanner_name, output_format]() -> std::string {
    // Generate output path
    char temp_path[MAX_PATH];
    GetTempPathA(MAX_PATH, temp_path);
    
    std::time_t now = std::time(nullptr);
    std::string output_path = std::string(temp_path) + "scanned_document_" + 
                             std::to_string(now) + "." + output_format;
    
    char result_buffer[1024];
    int length = ScanDocument(scanner_name.c_str(), output_path.c_str(), result_buffer, sizeof(result_buffer));
    
    if (length > 0) {
        return std::string(result_buffer, length);
    } else if (length == -1) {
      // Extract error code from buffer
      std::string error_code(result_buffer);
        throw std::runtime_error(error_code);
      } else {
        throw std::runtime_error("SCAN_FAILED");
    }
    },
    std::move(result),
    [](const std::string& result_path) -> flutter::EncodableValue {
      return flutter::EncodableValue(result_path);
    },
    [](const std::exception& e) {
      // Error mapping will be handled by RunInBackground
      std::string error_code = e.what();
      // Additional error code mapping could be added here
    }
  );
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

void FlutterWindow::HandleDiscoverNetworkScanners(const flutter::MethodCall<flutter::EncodableValue>& call,
                                                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Run network scanner discovery in background thread
  RunInBackground<std::vector<std::string>>(
    []() -> std::vector<std::string> {
      char buffer[4096];
      int length = FindScanners(buffer, sizeof(buffer));
      
      std::vector<std::string> scanners;
      if (length > 0) {
        std::string scanners_str(buffer, length);
        std::stringstream ss(scanners_str);
        std::string scanner;
        while (std::getline(ss, scanner, '|')) {
          if (!scanner.empty() && 
              (scanner.find("Network") != std::string::npos || 
               scanner.find("WiFi") != std::string::npos ||
               scanner.find("eSCL") != std::string::npos ||
               scanner.find("WSD") != std::string::npos)) {
            scanners.push_back(scanner);
          }
        }
      }
      return scanners;
    },
    std::move(result),
    [](const std::vector<std::string>& scanners) -> flutter::EncodableValue {
      std::vector<flutter::EncodableValue> flutter_scanners;
      for (const auto& scanner : scanners) {
        flutter_scanners.push_back(flutter::EncodableValue(scanner));
      }
      return flutter::EncodableValue(flutter_scanners);
    }
  );
}

void FlutterWindow::HandleCheckWiFiStatus(const flutter::MethodCall<flutter::EncodableValue>& call,
                                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Simple WiFi status check - assume connected if request is made
  // Real implementation would be in scanner_plugin.cpp
  result->Success(flutter::EncodableValue(true));
}

void FlutterWindow::HandleTestNetworkScannerQuality(const flutter::MethodCall<flutter::EncodableValue>& call,
                                                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
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
  
  // Simple mock quality test - real implementation in scanner_plugin.cpp
  flutter::EncodableMap quality;
  quality[flutter::EncodableValue("isReachable")] = flutter::EncodableValue(true);
  quality[flutter::EncodableValue("latency")] = flutter::EncodableValue(100);
  quality[flutter::EncodableValue("signalStrength")] = flutter::EncodableValue(80);
  quality[flutter::EncodableValue("connectionType")] = flutter::EncodableValue("WiFi");
  
  result->Success(flutter::EncodableValue(quality));
}

void FlutterWindow::HandleGetWiFiScannerSettings(const flutter::MethodCall<flutter::EncodableValue>& call,
                                                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
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
  
  // Get WiFi-optimized scanner settings
  flutter::EncodableMap settings;
  
  // WiFi optimized settings
  std::vector<flutter::EncodableValue> resolutions = {
    flutter::EncodableValue(150),
    flutter::EncodableValue(200),
    flutter::EncodableValue(300),
    flutter::EncodableValue(600)
  };
  
  std::vector<flutter::EncodableValue> colorModes = {
    flutter::EncodableValue("color"),
    flutter::EncodableValue("grayscale"),
    flutter::EncodableValue("blackwhite")
  };
  
  std::vector<flutter::EncodableValue> paperSizes = {
    flutter::EncodableValue("A4"),
    flutter::EncodableValue("A3"),
    flutter::EncodableValue("Letter"),
    flutter::EncodableValue("Legal")
  };
  
  std::vector<flutter::EncodableValue> outputFormats = {
    flutter::EncodableValue("pdf"),
    flutter::EncodableValue("jpeg"),
    flutter::EncodableValue("png")
  };
  
  settings[flutter::EncodableValue("resolution")] = flutter::EncodableValue(resolutions);
  settings[flutter::EncodableValue("colorModes")] = flutter::EncodableValue(colorModes);
  settings[flutter::EncodableValue("paperSizes")] = flutter::EncodableValue(paperSizes);
  settings[flutter::EncodableValue("outputFormats")] = flutter::EncodableValue(outputFormats);
  settings[flutter::EncodableValue("maxPages")] = flutter::EncodableValue(50);
  settings[flutter::EncodableValue("duplex")] = flutter::EncodableValue(false);
  settings[flutter::EncodableValue("timeout")] = flutter::EncodableValue(30000);
  settings[flutter::EncodableValue("bufferSize")] = flutter::EncodableValue(32768);
  settings[flutter::EncodableValue("compression")] = flutter::EncodableValue("medium");
  settings[flutter::EncodableValue("networkOptimized")] = flutter::EncodableValue(true);
  
  result->Success(flutter::EncodableValue(settings));
}

void FlutterWindow::HandleGetNetworkScannerIP(const flutter::MethodCall<flutter::EncodableValue>& call,
                                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
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
  
  // Extract IP address from scanner name
  std::regex ipRegex(R"((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}))");
  std::smatch match;
  
  if (std::regex_search(scanner_name, match, ipRegex)) {
    std::string ip = match[1].str();
    result->Success(flutter::EncodableValue(ip));
  } else {
    result->Success(flutter::EncodableValue());
  }
}

void FlutterWindow::HandleWiFiOptimizedScan(const flutter::MethodCall<flutter::EncodableValue>& call,
                                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
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
  
  // Get optional parameters with WiFi-optimized defaults
  int resolution = 200; // Lower resolution for WiFi
  auto resolution_it = arguments->find(flutter::EncodableValue("resolution"));
  if (resolution_it != arguments->end()) {
    resolution = std::get<int>(resolution_it->second);
  }
  
  std::string output_format = "pdf";
  auto format_it = arguments->find(flutter::EncodableValue("outputFormat"));
  if (format_it != arguments->end()) {
    output_format = std::get<std::string>(format_it->second);
  }
  
  int timeout = 30000; // 30 seconds for WiFi
  auto timeout_it = arguments->find(flutter::EncodableValue("timeout"));
  if (timeout_it != arguments->end()) {
    timeout = std::get<int>(timeout_it->second);
  }
  
  // Run WiFi optimized scan in background
  RunInBackground<std::string>(
    [scanner_name, output_format, timeout]() -> std::string {
      // Generate output path
      char temp_path[MAX_PATH];
      GetTempPathA(MAX_PATH, temp_path);
      
      std::time_t now = std::time(nullptr);
      std::string output_path = std::string(temp_path) + "wifi_scanned_document_" + 
                               std::to_string(now) + "." + output_format;
      
      char result_buffer[1024];
      int length = ScanDocument(scanner_name.c_str(), output_path.c_str(), result_buffer, sizeof(result_buffer));
      
      if (length > 0) {
        return std::string(result_buffer, length);
      } else if (length == -1) {
        std::string error_code(result_buffer);
        
        // Enhanced WiFi-specific error handling
        if (error_code == "SCANNER_NOT_FOUND") {
          throw std::runtime_error("NETWORK_SCANNER_UNREACHABLE");
        } else if (error_code == "SCANNER_CONNECTION_FAILED") {
          throw std::runtime_error("SCANNER_TIMEOUT");
        } else {
          throw std::runtime_error(error_code);
        }
      } else {
        throw std::runtime_error("WIFI_SCAN_FAILED");
      }
    },
    std::move(result),
    [](const std::string& result_path) -> flutter::EncodableValue {
      return flutter::EncodableValue(result_path);
    }
  );
}

void FlutterWindow::HandleNetworkTroubleshooting(const flutter::MethodCall<flutter::EncodableValue>& call,
                                                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
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
  
  // Simple mock diagnostics - real implementation in scanner_plugin.cpp
  flutter::EncodableMap diagnostics;
  diagnostics[flutter::EncodableValue("wifiConnected")] = flutter::EncodableValue(true);
  diagnostics[flutter::EncodableValue("scannerReachable")] = flutter::EncodableValue(true);
  diagnostics[flutter::EncodableValue("signalStrength")] = flutter::EncodableValue(80);
  diagnostics[flutter::EncodableValue("latency")] = flutter::EncodableValue(150);
  
  std::vector<flutter::EncodableValue> actions = {
    flutter::EncodableValue("Tarayıcı düzgün çalışıyor görünüyor")
  };
  diagnostics[flutter::EncodableValue("suggestedActions")] = flutter::EncodableValue(actions);
  
  result->Success(flutter::EncodableValue(diagnostics));
}

void FlutterWindow::HandleScanLocalNetwork(const flutter::MethodCall<flutter::EncodableValue>& call,
                                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Simple mock local network scan - real implementation in scanner_plugin.cpp
  std::vector<flutter::EncodableValue> scanners = {
    flutter::EncodableValue("Local Network Scanner (192.168.1.100)"),
    flutter::EncodableValue("WiFi Scanner (192.168.1.150)")
  };
  
  result->Success(flutter::EncodableValue(scanners));
}

// Template implementation for background thread operations
template<typename T>
void FlutterWindow::RunInBackground(std::function<T()> operation, 
                                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
                                    std::function<flutter::EncodableValue(T)> success_handler,
                                    std::function<void(const std::exception&)> error_handler) {
  
  // Create a shared pointer to the result to manage lifetime
  auto shared_result = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(result.release());
  
  // Run operation in background thread
  std::thread([operation, shared_result, success_handler, error_handler]() {
    try {
      T result_value = operation();
      
      // Return result on main thread
      flutter::EncodableValue flutter_result = success_handler(result_value);
      shared_result->Success(flutter_result);
      
    } catch (const std::exception& e) {
      std::string error_code = e.what();
      std::string error_message = "Operation failed";
      
      // Map specific error codes to Flutter errors
      if (error_code == "SCANNER_NOT_FOUND") {
        error_message = "Scanner not found or disconnected";
      } else if (error_code == "SCANNER_BUSY") {
        error_message = "Scanner is busy, please try again";
      } else if (error_code == "PAPER_JAM") {
        error_message = "Paper jam detected, please check scanner";
      } else if (error_code == "NO_PAPER") {
        error_message = "No paper in scanner, please add paper";
      } else if (error_code == "COVER_OPEN") {
        error_message = "Scanner cover is open, please close it";
      } else if (error_code == "NETWORK_SCANNER_UNREACHABLE") {
        error_message = "Network scanner is unreachable, check WiFi connection";
      } else if (error_code == "SCANNER_TIMEOUT") {
        error_message = "Scanner operation timed out, check network connection";
      } else if (error_code == "SCAN_FAILED") {
        error_message = "Scan operation failed";
      } else {
        error_message = "Scanner error: " + error_code;
      }
      
      // Call custom error handler if provided
      if (error_handler) {
        error_handler(e);
      }
      
      shared_result->Error(error_code, error_message, flutter::EncodableValue());
      
    } catch (...) {
      shared_result->Error("UNKNOWN_ERROR", "Unknown scanner error occurred", flutter::EncodableValue());
    }
  }).detach();
}
