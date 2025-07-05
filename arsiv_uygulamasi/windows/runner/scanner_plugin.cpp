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
        for (size_t i = 0; i < scanners.size(); ++i) {
            if (scanners[i] == scannerName) {
                scannerIndex = i;
                break;
            }
        }
        
        if (scannerIndex >= availableDevices.size()) {
            return "";
        }
        
        std::wstring deviceId = availableDevices[scannerIndex];
        
        // Create device
        IWiaItem* rootItem = nullptr;
        HRESULT hr = deviceManager->CreateDevice(deviceId.c_str(), &rootItem);
        
        if (!SUCCEEDED(hr) || !rootItem) {
            return "";
        }
        
        // Get scanner item
        IWiaItem* scannerItem = nullptr;
        hr = GetScannerItem(rootItem, &scannerItem);
        
        if (!SUCCEEDED(hr) || !scannerItem) {
            rootItem->Release();
            return "";
        }
        
        // Set scan properties
        SetScanProperties(scannerItem);
        
        // Perform scan
        std::string result = PerformScan(scannerItem, outputPath);
        
        scannerItem->Release();
        rootItem->Release();
        
        return result;
    }
    
private:
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
    
    void SetScanProperties(IWiaItem* scannerItem) {
        IWiaPropertyStorage* propStorage = nullptr;
        HRESULT hr = scannerItem->QueryInterface(IID_IWiaPropertyStorage, (void**)&propStorage);
        
        if (SUCCEEDED(hr)) {
            PROPSPEC propSpec[4];
            PROPVARIANT propVar[4];
            
            // Set resolution (300 DPI)
            propSpec[0].ulKind = PRSPEC_PROPID;
            propSpec[0].propid = WIA_IPS_XRES;
            propVar[0].vt = VT_I4;
            propVar[0].lVal = 300;
            
            propSpec[1].ulKind = PRSPEC_PROPID;
            propSpec[1].propid = WIA_IPS_YRES;
            propVar[1].vt = VT_I4;
            propVar[1].lVal = 300;
            
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
            
            propStorage->WriteMultiple(4, propSpec, propVar, WIA_IPA_FIRST);
            propStorage->Release();
        }
    }
    
    std::string PerformScan(IWiaItem* scannerItem, const std::string& outputPath) {
        IWiaDataTransfer* dataTransfer = nullptr;
        HRESULT hr = scannerItem->QueryInterface(IID_IWiaDataTransfer, (void**)&dataTransfer);
        
        if (!SUCCEEDED(hr)) {
            return "";
        }
        
        // Create callback
        ScanCallback callback(outputPath);
        
        // Start transfer
        STGMEDIUM medium = {0};
        medium.tymed = TYMED_FILE;
        
        std::wstring wOutputPath(outputPath.begin(), outputPath.end());
        medium.lpszFileName = _wcsdup(wOutputPath.c_str());
        
        hr = dataTransfer->idtGetData(&medium, &callback);
        
        dataTransfer->Release();
        
        if (medium.lpszFileName) {
            free(medium.lpszFileName);
        }
        
        if (SUCCEEDED(hr)) {
            return outputPath;
        }
        
        return "";
    }
};

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
            return result.length();
        }
        
        return 0;
    }
    
    __declspec(dllexport) int ScanDocument(const char* scannerName, const char* outputPath, char* resultBuffer, int bufferSize) {
        if (!g_scannerPlugin) {
            return 0;
        }
        
        std::string result = g_scannerPlugin->ScanDocument(scannerName, outputPath);
        
        if (result.length() < bufferSize) {
            strcpy_s(resultBuffer, bufferSize, result.c_str());
            return result.length();
        }
        
        return 0;
    }
} 