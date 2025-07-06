#include "scanner_plugin.h"
#include <windows.h>
#include <objbase.h>
#include <wia.h>
#include <comdef.h>
#include <vector>
#include <string>
#include <memory>
#include <iostream>
#include <fstream>
#include <shlwapi.h>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "wiaservc.lib")
#pragma comment(lib, "wiaguid.lib")
#pragma comment(lib, "shlwapi.lib")

// WIA sabitlerini tanımla
#ifndef WIA_DEVICE_TYPE_SCANNER
#define WIA_DEVICE_TYPE_SCANNER 1
#endif

// Callback class for scan progress
class ScanCallback : public IWiaDataCallback {
private:
    LONG refCount;
    std::string outputPath;
    
public:
    ScanCallback(const std::string& path) : refCount(1), outputPath(path) {}
    
    // IUnknown methods
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppvObject) override {
        if (riid == IID_IUnknown || riid == IID_IWiaDataCallback) {
            *ppvObject = this;
            AddRef();
            return S_OK;
        }
        return E_NOINTERFACE;
    }
    
    ULONG STDMETHODCALLTYPE AddRef() override {
        return InterlockedIncrement(&refCount);
    }
    
    ULONG STDMETHODCALLTYPE Release() override {
        LONG result = InterlockedDecrement(&refCount);
        if (result == 0) {
            delete this;
        }
        return result;
    }
    
    // IWiaDataCallback method
    HRESULT STDMETHODCALLTYPE BandedDataCallback(
        LONG lMessage,
        LONG lStatus,
        LONG lPercentComplete,
        LONG lOffset,
        LONG lLength,
        LONG lReserved,
        LONG lResLength,
        BYTE* pbBuffer) override {
        
        switch (lMessage) {
            case IT_MSG_DATA:
                // Save data to file
                if (pbBuffer && lLength > 0) {
                    std::ofstream file(outputPath, std::ios::binary | std::ios::app);
                    if (file.is_open()) {
                        file.write(reinterpret_cast<char*>(pbBuffer), lLength);
                        file.close();
                    }
                }
                break;
                
            case IT_MSG_STATUS:
                // Update progress (can be used for UI updates)
                break;
                
            case IT_MSG_TERMINATION:
                // Scan completed
                break;
        }
        
        return S_OK;
    }
};

class WindowsScannerPlugin {
private:
    IWiaDevMgr* deviceManager;
    std::vector<std::wstring> availableDevices;
    
public:
    WindowsScannerPlugin() : deviceManager(nullptr) {
        CoInitialize(nullptr);
        InitializeWIA();
    }
    
    ~WindowsScannerPlugin() {
        if (deviceManager) {
            deviceManager->Release();
        }
        CoUninitialize();
    }
    
    bool InitializeWIA() {
        HRESULT hr = CoCreateInstance(
            CLSID_WiaDevMgr,
            nullptr,
            CLSCTX_LOCAL_SERVER,
            IID_IWiaDevMgr,
            (void**)&deviceManager
        );
        
        return SUCCEEDED(hr);
    }
    
    std::vector<std::string> FindScanners() {
        std::vector<std::string> scanners;
        availableDevices.clear();
        
        if (!deviceManager) {
            return scanners;
        }
        
        IEnumWIA_DEV_INFO* enumDevInfo = nullptr;
        HRESULT hr = deviceManager->EnumDeviceInfo(WIA_DEVICE_TYPE_SCANNER, &enumDevInfo);
        
        if (SUCCEEDED(hr) && enumDevInfo) {
            IWiaPropertyStorage* propStorage = nullptr;
            ULONG fetched = 0;
            
            while (enumDevInfo->Next(1, &propStorage, &fetched) == S_OK && fetched == 1) {
                PROPSPEC propSpec[2];
                PROPVARIANT propVar[2];
                
                // Get device name
                propSpec[0].ulKind = PRSPEC_PROPID;
                propSpec[0].propid = WIA_DIP_DEV_NAME;
                
                // Get device ID
                propSpec[1].ulKind = PRSPEC_PROPID;
                propSpec[1].propid = WIA_DIP_DEV_ID;
                
                hr = propStorage->ReadMultiple(2, propSpec, propVar);
                
                if (SUCCEEDED(hr)) {
                    if (propVar[0].vt == VT_BSTR && propVar[1].vt == VT_BSTR) {
                        std::wstring deviceName = propVar[0].bstrVal;
                        std::wstring deviceId = propVar[1].bstrVal;
                        
                        availableDevices.push_back(deviceId);
                        
                        // Convert to narrow string
                        int size = WideCharToMultiByte(CP_UTF8, 0, deviceName.c_str(), -1, nullptr, 0, nullptr, nullptr);
                        std::string narrowName(size - 1, '\0');
                        WideCharToMultiByte(CP_UTF8, 0, deviceName.c_str(), -1, &narrowName[0], size, nullptr, nullptr);
                        
                        scanners.push_back(narrowName);
                    }
                    
                    PropVariantClear(&propVar[0]);
                    PropVariantClear(&propVar[1]);
                }
                
                propStorage->Release();
            }
            
            enumDevInfo->Release();
        }
        
        return scanners;
    }
    
    std::string ScanDocument(const std::string& scannerName, const std::string& outputPath) {
        if (availableDevices.empty()) {
            FindScanners();
        }
        
        // Find scanner index by name
        auto scanners = FindScanners();
        size_t scannerIndex = 0;
        bool scannerFound = false;
        
        for (size_t i = 0; i < scanners.size(); ++i) {
            if (scanners[i] == scannerName) {
                scannerIndex = i;
                scannerFound = true;
                break;
            }
        }
        
        if (!scannerFound || scannerIndex >= availableDevices.size()) {
            throw std::runtime_error("SCANNER_NOT_FOUND");
        }
        
        std::wstring deviceId = availableDevices[scannerIndex];
        
        // Test network connection first (for network scanners)
        if (IsNetworkScanner(deviceId)) {
            if (!TestNetworkConnection(deviceId)) {
                throw std::runtime_error("NETWORK_SCANNER_UNREACHABLE");
            }
        }
        
        // Create device with extended timeout for network scanners
        IWiaItem* rootItem = nullptr;
        BSTR deviceIdBstr = SysAllocString(deviceId.c_str());
        HRESULT hr = deviceManager->CreateDevice(deviceIdBstr, &rootItem);
        SysFreeString(deviceIdBstr);
        
        if (hr == E_ACCESSDENIED) {
            throw std::runtime_error("SCANNER_BUSY");
        } else if (hr == WIA_ERROR_OFFLINE) {
            throw std::runtime_error("SCANNER_OFFLINE");
        } else if (hr == HRESULT_FROM_WIN32(ERROR_TIMEOUT)) {
            throw std::runtime_error("SCANNER_TIMEOUT");
        } else if (!SUCCEEDED(hr) || !rootItem) {
            throw std::runtime_error("SCANNER_CONNECTION_FAILED");
        }
        
        // Get scanner item
        IWiaItem* scannerItem = nullptr;
        hr = GetScannerItem(rootItem, &scannerItem);
        
        if (!SUCCEEDED(hr) || !scannerItem) {
            rootItem->Release();
            
            if (hr == WIA_ERROR_PAPER_EMPTY) {
                throw std::runtime_error("NO_PAPER");
            } else if (hr == WIA_ERROR_PAPER_JAM) {
                throw std::runtime_error("PAPER_JAM");
            } else if (hr == WIA_ERROR_COVER_OPEN) {
                throw std::runtime_error("COVER_OPEN");
            } else if (hr == WIA_ERROR_OFFLINE) {
                throw std::runtime_error("SCANNER_OFFLINE");
            } else {
                throw std::runtime_error("SCANNER_ITEM_NOT_FOUND");
            }
        }
        
        // Set scan properties with network-friendly settings
        hr = SetScanProperties(scannerItem, IsNetworkScanner(deviceId));
        if (!SUCCEEDED(hr)) {
            scannerItem->Release();
            rootItem->Release();
            throw std::runtime_error("SCANNER_PROPERTIES_FAILED");
        }
        
        // Perform scan with extended timeout for network scanners
        std::string result;
        try {
            result = PerformScan(scannerItem, outputPath);
        } catch (...) {
            scannerItem->Release();
            rootItem->Release();
            throw;
        }
        
        scannerItem->Release();
        rootItem->Release();
        
        if (result.empty()) {
            throw std::runtime_error("SCAN_FAILED");
        }
        
        return result;
    }
    
private:
    // Check if scanner is a network scanner
    bool IsNetworkScanner(const std::wstring& deviceId) {
        // Check if device ID contains network indicators
        return deviceId.find(L"\\\\") != std::wstring::npos ||  // UNC path
               deviceId.find(L"http://") != std::wstring::npos ||  // HTTP
               deviceId.find(L"https://") != std::wstring::npos || // HTTPS
               deviceId.find(L"IP_") != std::wstring::npos ||      // IP prefix
               deviceId.find(L"NET_") != std::wstring::npos;       // Network prefix
    }
    
    // Test network connection to scanner
    bool TestNetworkConnection(const std::wstring& deviceId) {
        // For network scanners, try to create a temporary connection
        IWiaItem* testItem = nullptr;
        BSTR deviceIdBstr = SysAllocString(deviceId.c_str());
        
        HRESULT hr = deviceManager->CreateDevice(deviceIdBstr, &testItem);
        SysFreeString(deviceIdBstr);
        
        if (testItem) {
            testItem->Release();
            return SUCCEEDED(hr);
        }
        
        return false;
    }

    HRESULT GetScannerItem(IWiaItem* rootItem, IWiaItem** scannerItem) {
        IEnumWiaItem* enumItems = nullptr;
        HRESULT hr = rootItem->EnumChildItems(&enumItems);
        
        if (!SUCCEEDED(hr)) {
            return hr;
        }
        
        IWiaItem* item = nullptr;
        ULONG fetched = 0;
        
        while (enumItems->Next(1, &item, &fetched) == S_OK && fetched == 1) {
            // Check if this is a scanner item
            IWiaPropertyStorage* propStorage = nullptr;
            hr = item->QueryInterface(IID_IWiaPropertyStorage, (void**)&propStorage);
            
            if (SUCCEEDED(hr)) {
                PROPSPEC propSpec;
                PROPVARIANT propVar;
                
                propSpec.ulKind = PRSPEC_PROPID;
                propSpec.propid = WIA_IPA_ITEM_CATEGORY;
                
                hr = propStorage->ReadMultiple(1, &propSpec, &propVar);
                
                if (SUCCEEDED(hr) && propVar.vt == VT_CLSID) {
                    if (IsEqualCLSID(*propVar.puuid, WIA_CATEGORY_FLATBED) ||
                        IsEqualCLSID(*propVar.puuid, WIA_CATEGORY_FEEDER)) {
                        *scannerItem = item;
                        PropVariantClear(&propVar);
                        propStorage->Release();
                        enumItems->Release();
                        return S_OK;
                    }
                }
                
                PropVariantClear(&propVar);
                propStorage->Release();
            }
            
            item->Release();
        }
        
        enumItems->Release();
        return E_FAIL;
    }
    
    HRESULT SetScanProperties(IWiaItem* scannerItem, bool isNetworkScanner = false) {
        IWiaPropertyStorage* propStorage = nullptr;
        HRESULT hr = scannerItem->QueryInterface(IID_IWiaPropertyStorage, (void**)&propStorage);
        
        if (!SUCCEEDED(hr)) {
            return hr;
        }
        
        PROPSPEC propSpec[6];
        PROPVARIANT propVar[6];
        
        // Set resolution (lower for network scanners to improve speed)
        int resolution = isNetworkScanner ? 200 : 300;
        
        propSpec[0].ulKind = PRSPEC_PROPID;
        propSpec[0].propid = WIA_IPS_XRES;
        propVar[0].vt = VT_I4;
        propVar[0].lVal = resolution;
        
        propSpec[1].ulKind = PRSPEC_PROPID;
        propSpec[1].propid = WIA_IPS_YRES;
        propVar[1].vt = VT_I4;
        propVar[1].lVal = resolution;
        
        // Set color mode (color)
        propSpec[2].ulKind = PRSPEC_PROPID;
        propSpec[2].propid = WIA_IPA_DATATYPE;
        propVar[2].vt = VT_I4;
        propVar[2].lVal = WIA_DATA_COLOR;
        
        // Set format (BMP)
        propSpec[3].ulKind = PRSPEC_PROPID;
        propSpec[3].propid = WIA_IPA_FORMAT;
        propVar[3].vt = VT_CLSID;
        propVar[3].puuid = (CLSID*)&WiaImgFmt_BMP;
        
        int propCount = 4;
        
        // For network scanners, set additional properties for better performance
        if (isNetworkScanner) {
            // Set buffer size for network transfer
            propSpec[4].ulKind = PRSPEC_PROPID;
            propSpec[4].propid = WIA_IPA_BUFFER_SIZE;
            propVar[4].vt = VT_I4;
            propVar[4].lVal = 32768; // 32KB buffer
            
            propCount = 5;
        }
        
        hr = propStorage->WriteMultiple(propCount, propSpec, propVar, WIA_IPA_FIRST);
        propStorage->Release();
        
        return hr;
    }
    
    std::string PerformScan(IWiaItem* scannerItem, const std::string& outputPath) {
        IWiaDataTransfer* dataTransfer = nullptr;
        HRESULT hr = scannerItem->QueryInterface(IID_IWiaDataTransfer, (void**)&dataTransfer);
        
        if (!SUCCEEDED(hr)) {
            throw std::runtime_error("DATA_TRANSFER_FAILED");
        }
        
        // Create callback
        ScanCallback* callback = new ScanCallback(outputPath);
        
        // Start transfer
        STGMEDIUM medium = {0};
        medium.tymed = TYMED_FILE;
        
        std::wstring wOutputPath(outputPath.begin(), outputPath.end());
        medium.lpszFileName = _wcsdup(wOutputPath.c_str());
        
        hr = dataTransfer->idtGetData(&medium, callback);
        
        dataTransfer->Release();
        callback->Release();
        
        if (medium.lpszFileName) {
            free(medium.lpszFileName);
        }
        
        if (hr == WIA_ERROR_PAPER_EMPTY) {
            throw std::runtime_error("NO_PAPER");
        } else if (hr == WIA_ERROR_PAPER_JAM) {
            throw std::runtime_error("PAPER_JAM");
        } else if (hr == WIA_ERROR_COVER_OPEN) {
            throw std::runtime_error("COVER_OPEN");
        } else if (hr == WIA_ERROR_BUSY) {
            throw std::runtime_error("SCANNER_BUSY");
        } else if (!SUCCEEDED(hr)) {
            throw std::runtime_error("SCAN_OPERATION_FAILED");
        }
        
        return outputPath;
    }
    
    bool CheckScannerStatus(const std::string& scannerName) {
        try {
            auto scanners = FindScanners();
            for (const auto& scanner : scanners) {
                if (scanner == scannerName) {
                    return true;
                }
            }
            return false;
        } catch (...) {
            return false;
        }
    }
};

// Global plugin instance
static std::unique_ptr<WindowsScannerPlugin> g_scannerPlugin;

// Plugin interface functions
extern "C" {
    __declspec(dllexport) void InitializeScannerPlugin() {
        g_scannerPlugin = std::make_unique<WindowsScannerPlugin>();
    }
    
    __declspec(dllexport) void CleanupScannerPlugin() {
        g_scannerPlugin.reset();
    }
    
    __declspec(dllexport) int FindScanners(char* buffer, int bufferSize) {
        if (!g_scannerPlugin) {
            return 0;
        }
        
        auto scanners = g_scannerPlugin->FindScanners();
        std::string result;
        
        for (size_t i = 0; i < scanners.size(); ++i) {
            if (i > 0) result += "|";
            result += scanners[i];
        }
        
        if (result.length() < bufferSize) {
            strcpy_s(buffer, bufferSize, result.c_str());
            return static_cast<int>(result.length());
        }
        
        return 0;
    }
    
    __declspec(dllexport) int ScanDocument(const char* scannerName, const char* outputPath, char* resultBuffer, int bufferSize) {
        if (!g_scannerPlugin) {
            strcpy_s(resultBuffer, bufferSize, "PLUGIN_NOT_INITIALIZED");
            return -1;
        }
        
        std::string result;
        try {
            result = g_scannerPlugin->ScanDocument(scannerName, outputPath);
        } catch (const std::runtime_error& e) {
            // Return specific error code
            strcpy_s(resultBuffer, bufferSize, e.what());
            return -1;
        } catch (...) {
            strcpy_s(resultBuffer, bufferSize, "UNKNOWN_SCANNER_ERROR");
            return -1;
        }
        
        if (result.length() < bufferSize) {
            strcpy_s(resultBuffer, bufferSize, result.c_str());
            return static_cast<int>(result.length());
        }
        
        strcpy_s(resultBuffer, bufferSize, "BUFFER_TOO_SMALL");
        return -1;
    }
} 