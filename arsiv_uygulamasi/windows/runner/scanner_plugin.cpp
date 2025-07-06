#include "scanner_plugin.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

// Network headers first to avoid conflicts
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iphlpapi.h>
#include <netlistmgr.h>
#include <windns.h>

// COM and WIA headers
#include <objbase.h>
#include <wia.h>
#include <comdef.h>
#include <shlwapi.h>

// Standard library headers
#include <vector>
#include <string>
#include <memory>
#include <iostream>
#include <fstream>
#include <thread>
#include <chrono>
#include <regex>
#include <sstream>
#include <mutex>
#include <set>
#include <algorithm>
#include <map>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "wiaservc.lib")
#pragma comment(lib, "wiaguid.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "netapi32.lib")
#pragma comment(lib, "rpcrt4.lib")
#pragma comment(lib, "dnsapi.lib")

// WIA sabitlerini tanımla
#ifndef WIA_DEVICE_TYPE_SCANNER
#define WIA_DEVICE_TYPE_SCANNER 1
#endif

// Use Windows SDK's original WIA definitions
#include <wiadef.h>

// Disable size_t conversion warnings for network code
#pragma warning(push)
#pragma warning(disable: 4267)
#pragma warning(disable: 4996)
#pragma warning(disable: 4244)

// Define essential WIA constants if not available
#ifndef WIA_ERROR_PAPER_EMPTY
#define WIA_ERROR_PAPER_EMPTY 0x80210003L
#endif
#ifndef WIA_ERROR_PAPER_JAM
#define WIA_ERROR_PAPER_JAM 0x80210004L
#endif
#ifndef WIA_ERROR_COVER_OPEN
#define WIA_ERROR_COVER_OPEN 0x80210005L
#endif
#ifndef WIA_ERROR_BUSY
#define WIA_ERROR_BUSY 0x80210006L
#endif
#ifndef WIA_ERROR_WARMING_UP
#define WIA_ERROR_WARMING_UP 0x80210007L
#endif
#ifndef WIA_ERROR_USER_INTERVENTION
#define WIA_ERROR_USER_INTERVENTION 0x80210008L
#endif
#ifndef WIA_ERROR_OFFLINE
#define WIA_ERROR_OFFLINE 0x80210001L
#endif

// Additional constants for network discovery
#define WSD_DISCOVERY_PORT 3702
#define SSDP_DISCOVERY_PORT 1900
#define SSDP_DISCOVERY_MULTICAST "239.255.255.250"
#define ESCL_DISCOVERY_TIMEOUT 3000 // 3 seconds

// Enhanced error definitions for WiFi scanning
#define WIFI_SCAN_ERROR_BASE 0x80004000L
#define WIFI_ERROR_NETWORK_UNREACHABLE (WIFI_SCAN_ERROR_BASE + 0x001)
#define WIFI_ERROR_TIMEOUT (WIFI_SCAN_ERROR_BASE + 0x002)
#define WIFI_ERROR_WEAK_SIGNAL (WIFI_SCAN_ERROR_BASE + 0x003)
#define WIFI_ERROR_CONGESTION (WIFI_SCAN_ERROR_BASE + 0x004)
#define WIFI_ERROR_AUTHENTICATION (WIFI_SCAN_ERROR_BASE + 0x005)
#define WIFI_ERROR_PROTOCOL_NOT_SUPPORTED (WIFI_SCAN_ERROR_BASE + 0x006)
#define WIFI_ERROR_DEVICE_BUSY (WIFI_SCAN_ERROR_BASE + 0x007)
#define WIFI_ERROR_INVALID_SETTINGS (WIFI_SCAN_ERROR_BASE + 0x008)
#define WIFI_ERROR_BUFFER_TOO_SMALL (WIFI_SCAN_ERROR_BASE + 0x009)
#define WIFI_ERROR_SCAN_CANCELLED (WIFI_SCAN_ERROR_BASE + 0x00A)

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
    IWiaDevMgr2* deviceManager;
    std::vector<std::wstring> availableDevices;
    std::mutex deviceMutex;
    bool wsaInitialized;
    
public:
    WindowsScannerPlugin() : deviceManager(nullptr), wsaInitialized(false) {
        // Initialize COM for multithreaded apartment (required for network operations)
        HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        if (FAILED(hr)) {
            // Try apartment threaded as fallback
            CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        }
        
        // Initialize Winsock for network operations
        WSADATA wsaData;
        int result = WSAStartup(MAKEWORD(2, 2), &wsaData);
        wsaInitialized = (result == 0);
        
        InitializeWIA();
    }
    
    ~WindowsScannerPlugin() {
        if (deviceManager) {
            deviceManager->Release();
        }
        
        if (wsaInitialized) {
            WSACleanup();
        }
        
        CoUninitialize();
    }
    
    bool InitializeWIA() {
        // Use WIA 2.0 Device Manager for network scanner support
        HRESULT hr = CoCreateInstance(
            CLSID_WiaDevMgr2,
            nullptr,
            CLSCTX_LOCAL_SERVER,
            IID_IWiaDevMgr2,
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
        
        // First try local scanners
        FindLocalScanners(scanners);
        
        // Then try network scanners with WIA2 support
        FindNetworkScanners(scanners);
        
        return scanners;
    }
    
    void FindLocalScanners(std::vector<std::string>& scanners) {
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
    }
    
    void FindNetworkScanners(std::vector<std::string>& scanners) {
        if (!wsaInitialized) {
            return;
        }
        
        try {
            // Discover network scanners using multiple protocols
            DiscoverWSDScanners(scanners);
            DiscovereSCLScanners(scanners);
            DiscoverSNMPScanners(scanners);
        } catch (const std::exception& e) {
            // Log error but don't fail completely
            std::cerr << "Network scanner discovery error: " << e.what() << std::endl;
        }
    }
    
    // WSD (Web Services for Devices) Scanner Discovery
    void DiscoverWSDScanners(std::vector<std::string>& scanners) {
        // Enhanced WSD discovery with multiple protocols
        try {
            // 1. UDP Broadcast Discovery
            DiscoverWSDUDPBroadcast(scanners);
            
            // 2. Multicast DNS Discovery  
            DiscoverWSDMulticast(scanners);
            
            // 3. SSDP Discovery
            DiscoverWSDSSDP(scanners);
            
        } catch (const std::exception& e) {
            std::cerr << "WSD discovery error: " << e.what() << std::endl;
        }
    }
    
    // UDP Broadcast WSD Discovery
    void DiscoverWSDUDPBroadcast(std::vector<std::string>& scanners) {
        SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (sock == INVALID_SOCKET) {
            return;
        }
        
        // Enable broadcast
        BOOL broadcast = TRUE;
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, (char*)&broadcast, sizeof(broadcast));
        
        // Set timeout with retry mechanism
        DWORD timeout = 3000; // 3 seconds
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char*)&timeout, sizeof(timeout));
        
        // Enhanced WSD probe message with multiple device types
        const char* probeMessages[] = {
            // Generic scanner probe
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:3702\r\nMAN: \"ssdp:discover\"\r\nST: urn:schemas-xmlsoap-org:ws:2005:04:discovery\r\nMX: 3\r\n\r\n",
            
            // Printer/Scanner specific probe
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:3702\r\nMAN: \"ssdp:discover\"\r\nST: urn:schemas-upnp-org:device:Printer:1\r\nMX: 3\r\n\r\n",
            
            // HP specific probe
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:3702\r\nMAN: \"ssdp:discover\"\r\nST: urn:hp-com:device:Printer:1\r\nMX: 3\r\n\r\n",
            
            // Canon specific probe
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:3702\r\nMAN: \"ssdp:discover\"\r\nST: urn:canon-com:device:Scanner:1\r\nMX: 3\r\n\r\n"
        };
        
        std::set<std::string> foundDevices; // Prevent duplicates
        
        // Send multiple probe messages for better discovery
        for (const char* probeMsg : probeMessages) {
            sockaddr_in broadcastAddr;
            broadcastAddr.sin_family = AF_INET;
            broadcastAddr.sin_addr.s_addr = INADDR_BROADCAST;
            broadcastAddr.sin_port = htons(3702); // WSD port
            
            sendto(sock, probeMsg, strlen(probeMsg), 0, (sockaddr*)&broadcastAddr, sizeof(broadcastAddr));
            
            // Listen for responses with timeout
            char buffer[4096];
            sockaddr_in fromAddr;
            int fromLen = sizeof(fromAddr);
            
            auto startTime = std::chrono::steady_clock::now();
            while (std::chrono::steady_clock::now() - startTime < std::chrono::seconds(2)) {
                int received = recvfrom(sock, buffer, sizeof(buffer) - 1, 0, (sockaddr*)&fromAddr, &fromLen);
                if (received <= 0) {
                    break; // Timeout or error
                }
                
                buffer[received] = '\0';
                std::string response(buffer);
                
                // Enhanced response parsing
                if (IsWSDScannerResponse(response)) {
                    char ipStr[INET_ADDRSTRLEN];
                    inet_ntop(AF_INET, &fromAddr.sin_addr, ipStr, INET_ADDRSTRLEN);
                    
                    std::string deviceKey = std::string(ipStr);
                    if (foundDevices.find(deviceKey) == foundDevices.end()) {
                        foundDevices.insert(deviceKey);
                        
                        std::string scannerName = ExtractWSDScannerName(response, ipStr);
                        scanners.push_back(scannerName);
                        
                        // Store device info for later use
                        std::wstring deviceId = L"WSD:" + std::wstring(ipStr, ipStr + strlen(ipStr));
                        availableDevices.push_back(deviceId);
                    }
                }
            }
        }
        
        closesocket(sock);
    }
    
    // Multicast DNS Discovery for WSD
    void DiscoverWSDMulticast(std::vector<std::string>& scanners) {
        SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (sock == INVALID_SOCKET) {
            return;
        }
        
        // Set up multicast
        sockaddr_in multicastAddr;
        multicastAddr.sin_family = AF_INET;
        multicastAddr.sin_addr.s_addr = inet_addr("224.0.0.251"); // mDNS multicast address
        multicastAddr.sin_port = htons(5353); // mDNS port
        
        // Enable multicast
        ip_mreq mreq;
        mreq.imr_multiaddr.s_addr = inet_addr("224.0.0.251");
        mreq.imr_interface.s_addr = INADDR_ANY;
        setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, (char*)&mreq, sizeof(mreq));
        
        // Set timeout
        DWORD timeout = 2000; // 2 seconds
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char*)&timeout, sizeof(timeout));
        
        // mDNS query for scanner services
        const char* mDNSQueries[] = {
            "_scanner._tcp.local",
            "_ipp._tcp.local",
            "_http._tcp.local",
            "_printer._tcp.local"
        };
        
        for (const char* query : mDNSQueries) {
            // Construct mDNS query packet (simplified)
            std::vector<char> packet;
            ConstructmDNSQuery(packet, query);
            
            sendto(sock, packet.data(), packet.size(), 0, (sockaddr*)&multicastAddr, sizeof(multicastAddr));
            
            // Listen for responses
            char buffer[1024];
            sockaddr_in fromAddr;
            int fromLen = sizeof(fromAddr);
            
            auto startTime = std::chrono::steady_clock::now();
            while (std::chrono::steady_clock::now() - startTime < std::chrono::seconds(1)) {
                int received = recvfrom(sock, buffer, sizeof(buffer) - 1, 0, (sockaddr*)&fromAddr, &fromLen);
                if (received <= 0) {
                    break;
                }
                
                // Parse mDNS response (simplified)
                if (ParsemDNSResponse(buffer, received)) {
                    char ipStr[INET_ADDRSTRLEN];
                    inet_ntop(AF_INET, &fromAddr.sin_addr, ipStr, INET_ADDRSTRLEN);
                    
                    std::string scannerName = "mDNS Scanner (" + std::string(ipStr) + ")";
                    scanners.push_back(scannerName);
                    
                    std::wstring deviceId = L"MDNS:" + std::wstring(ipStr, ipStr + strlen(ipStr));
                    availableDevices.push_back(deviceId);
                }
            }
        }
        
        closesocket(sock);
    }
    
    // SSDP Discovery for WSD
    void DiscoverWSDSSDP(std::vector<std::string>& scanners) {
        SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (sock == INVALID_SOCKET) {
            return;
        }
        
        // Set up SSDP multicast
        sockaddr_in ssdpAddr;
        ssdpAddr.sin_family = AF_INET;
        ssdpAddr.sin_addr.s_addr = inet_addr("239.255.255.250");
        ssdpAddr.sin_port = htons(1900); // SSDP port
        
        // Set timeout
        DWORD timeout = 3000; // 3 seconds
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char*)&timeout, sizeof(timeout));
        
        // SSDP search messages for different device types
        const char* ssdpSearches[] = {
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nST: upnp:rootdevice\r\nMX: 3\r\n\r\n",
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nST: urn:schemas-upnp-org:device:Printer:1\r\nMX: 3\r\n\r\n",
            "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nST: urn:schemas-upnp-org:service:Scanner:1\r\nMX: 3\r\n\r\n"
        };
        
        for (const char* search : ssdpSearches) {
            sendto(sock, search, strlen(search), 0, (sockaddr*)&ssdpAddr, sizeof(ssdpAddr));
            
            // Listen for responses
            char buffer[2048];
            sockaddr_in fromAddr;
            int fromLen = sizeof(fromAddr);
            
            auto startTime = std::chrono::steady_clock::now();
            while (std::chrono::steady_clock::now() - startTime < std::chrono::seconds(2)) {
                int received = recvfrom(sock, buffer, sizeof(buffer) - 1, 0, (sockaddr*)&fromAddr, &fromLen);
                if (received <= 0) {
                    break;
                }
                
                buffer[received] = '\0';
                std::string response(buffer);
                
                                 // Check if response indicates scanner capability
                 if (IsSSDPScannerResponse(response)) {
                     char ipStr[INET_ADDRSTRLEN];
                     inet_ntop(AF_INET, &fromAddr.sin_addr, ipStr, INET_ADDRSTRLEN);
                     
                     std::string scannerName = ExtractSSDPScannerInfo(response, ipStr);
                     scanners.push_back(scannerName);
                     
                     std::wstring deviceId = L"SSDP:" + std::wstring(ipStr, ipStr + strlen(ipStr));
                     availableDevices.push_back(deviceId);
                 }
            }
        }
        
        closesocket(sock);
    }
    
    // Helper function to check if WSD response indicates scanner
    bool IsWSDScannerResponse(const std::string& response) {
        // Check for scanner-related keywords in response
        std::string lowercaseResponse = response;
        std::transform(lowercaseResponse.begin(), lowercaseResponse.end(), lowercaseResponse.begin(), ::tolower);
        
        return lowercaseResponse.find("scanner") != std::string::npos ||
               lowercaseResponse.find("scan") != std::string::npos ||
               lowercaseResponse.find("printer") != std::string::npos ||
               lowercaseResponse.find("multifunction") != std::string::npos ||
               lowercaseResponse.find("mfp") != std::string::npos ||
               lowercaseResponse.find("all-in-one") != std::string::npos ||
               lowercaseResponse.find("wsd") != std::string::npos ||
               lowercaseResponse.find("escl") != std::string::npos;
    }
    
    // Helper function to extract scanner name from WSD response
    std::string ExtractWSDScannerName(const std::string& response, const char* ipAddr) {
        // Try to extract device name from response headers
        std::string deviceName = "Network Scanner";
        
        // Look for common device name headers
        std::regex nameRegex(R"((?:SERVER|USN|ST):\s*([^\r\n]+))", std::regex_constants::icase);
        std::smatch match;
        
        if (std::regex_search(response, match, nameRegex)) {
            std::string extracted = match[1].str();
            // Clean up the extracted name
            if (extracted.length() > 5 && extracted.length() < 50) {
                deviceName = extracted;
            }
        }
        
        return deviceName + " (" + std::string(ipAddr) + ")";
    }
    
    // Helper function to construct mDNS query
    void ConstructmDNSQuery(std::vector<char>& packet, const char* serviceName) {
        // Simplified mDNS query construction
        // In a real implementation, this would construct a proper DNS packet
        packet.clear();
        
        // DNS header (12 bytes)
        packet.resize(12);
        
        // Transaction ID
        packet[0] = 0x00;
        packet[1] = 0x01;
        
        // Flags (standard query)
        packet[2] = 0x01; // Recursion desired
        packet[3] = 0x00;
        
        // Questions count
        packet[4] = 0x00;
        packet[5] = 0x01;
        
        // Other counts (Answer, Authority, Additional)
        for (int i = 6; i < 12; i++) {
            packet[i] = 0x00;
        }
        
        // Add service name (simplified)
        std::string service = serviceName;
        size_t start = packet.size();
        packet.resize(start + service.length() + 2);
        
        packet[start] = service.length();
        memcpy(&packet[start + 1], service.c_str(), service.length());
        packet[start + service.length() + 1] = 0x00; // Null terminator
    }
    
    // Helper function to parse mDNS response
    bool ParsemDNSResponse(const char* buffer, int length) {
        // Simplified mDNS response parsing
        // In a real implementation, this would properly parse DNS response format
        
        if (length < 12) {
            return false; // Too short to be valid DNS response
        }
        
        // Check if it's a response (QR bit set)
        if ((buffer[2] & 0x80) == 0) {
            return false; // Not a response
        }
        
        // Check answer count
        int answerCount = (buffer[6] << 8) | buffer[7];
        return answerCount > 0;
    }
    
         // Helper function to check if SSDP response indicates scanner
     bool IsSSDPScannerResponse(const std::string& response) {
        std::string lowercaseResponse = response;
        std::transform(lowercaseResponse.begin(), lowercaseResponse.end(), lowercaseResponse.begin(), ::tolower);
        
        return lowercaseResponse.find("location:") != std::string::npos &&
               (lowercaseResponse.find("printer") != std::string::npos ||
                lowercaseResponse.find("scanner") != std::string::npos ||
                lowercaseResponse.find("multifunction") != std::string::npos);
    }
    
         // Helper function to extract scanner info from SSDP response
     std::string ExtractSSDPScannerInfo(const std::string& response, const char* ipAddr) {
        std::string deviceName = "SSDP Scanner";
        
        // Try to extract device description from LOCATION header
        std::regex locationRegex(R"(LOCATION:\s*http://([^/\r\n]+))", std::regex_constants::icase);
        std::smatch match;
        
        if (std::regex_search(response, match, locationRegex)) {
            std::string location = match[1].str();
            // Extract hostname or use as device identifier
            size_t colonPos = location.find(':');
            if (colonPos != std::string::npos) {
                deviceName = "SSDP Scanner (" + location.substr(0, colonPos) + ")";
            } else {
                deviceName = "SSDP Scanner (" + location + ")";
            }
        } else {
            deviceName = "SSDP Scanner (" + std::string(ipAddr) + ")";
        }
        
        return deviceName;
    }
    
    // eSCL (AirPrint) Scanner Discovery
    void DiscovereSCLScanners(std::vector<std::string>& scanners) {
        // Enhanced eSCL scanners discovery with retry and timeout
        // Common eSCL scanner ports: 80, 443, 8080, 8443, 631 (IPP)
        std::vector<int> ports = {80, 443, 8080, 8443, 631};
        
        // Get local network IP range with improved detection
        std::vector<std::string> localIPs = GetLocalNetworkIPs();
        
        if (localIPs.empty()) {
            // Fallback to common network ranges
            localIPs = {"192.168.1.", "192.168.0.", "10.0.0.", "172.16.0."};
        }
        
        std::vector<std::thread> threads;
        std::mutex scannerMutex;
        
        for (const auto& baseIP : localIPs) {
            threads.emplace_back([this, baseIP, ports, &scanners, &scannerMutex]() {
                ScanIPRangeForeSCL(baseIP, ports, scanners, scannerMutex);
            });
        }
        
        // Wait for all threads to complete with timeout
        auto startTime = std::chrono::steady_clock::now();
        for (auto& thread : threads) {
            if (thread.joinable()) {
                thread.join();
                
                // Check timeout (max 10 seconds for all discovery)
                if (std::chrono::steady_clock::now() - startTime > std::chrono::seconds(10)) {
                    break;
                }
            }
        }
    }
    
    // Enhanced IP range scanning for eSCL
    void ScanIPRangeForeSCL(const std::string& baseIP, const std::vector<int>& ports, 
                           std::vector<std::string>& scanners, std::mutex& scannerMutex) {
        for (int i = 1; i <= 254; i++) {
            std::string ip = baseIP + std::to_string(i);
            
            for (int port : ports) {
                if (TesteSCLScannerWithRetry(ip, port)) {
                    std::string scannerInfo = GeteSCLScannerInfo(ip, port);
                    
                    std::lock_guard<std::mutex> lock(scannerMutex);
                    scanners.push_back(scannerInfo);
                    
                    std::wstring deviceId = L"ESCL:" + std::wstring(ip.begin(), ip.end()) + L":" + std::to_wstring(port);
                    availableDevices.push_back(deviceId);
                    break; // Found scanner on this IP, no need to check other ports
                }
                
                // Small delay between attempts to avoid overwhelming the network
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }
    }
    
    // Test eSCL scanner with retry mechanism
    bool TesteSCLScannerWithRetry(const std::string& ip, int port) {
        const int maxRetries = 2;
        
        for (int attempt = 0; attempt < maxRetries; attempt++) {
            if (TesteSCLScanner(ip, port, 1000)) { // 1 second timeout
                return true;
            }
            
            // Exponential backoff
            if (attempt < maxRetries - 1) {
                std::this_thread::sleep_for(std::chrono::milliseconds(100 * (attempt + 1)));
            }
        }
        
        return false;
    }
    
    // Enhanced eSCL scanner testing with configurable timeout
    bool TesteSCLScanner(const std::string& ip, int port, int timeoutMs = 1000) {
        SOCKET sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (sock == INVALID_SOCKET) {
            return false;
        }
        
        // Set connection timeout
        DWORD timeout = timeoutMs;
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char*)&timeout, sizeof(timeout));
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (char*)&timeout, sizeof(timeout));
        
        // Set socket to non-blocking for connect timeout
        u_long mode = 1;
        ioctlsocket(sock, FIONBIO, &mode);
        
        sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        inet_pton(AF_INET, ip.c_str(), &addr.sin_addr);
        
        bool isScanner = false;
        int connectResult = connect(sock, (sockaddr*)&addr, sizeof(addr));
        
        if (connectResult == SOCKET_ERROR) {
            int error = WSAGetLastError();
            if (error == WSAEWOULDBLOCK) {
                // Wait for connection with select
                fd_set writeSet;
                FD_ZERO(&writeSet);
                FD_SET(sock, &writeSet);
                
                struct timeval tv;
                tv.tv_sec = timeoutMs / 1000;
                tv.tv_usec = (timeoutMs % 1000) * 1000;
                
                if (select(0, nullptr, &writeSet, nullptr, &tv) > 0) {
                    // Connection successful, test eSCL endpoints
                    isScanner = TesteSCLEndpoints(sock, ip, port);
                }
            }
        } else {
            // Connection successful immediately
            isScanner = TesteSCLEndpoints(sock, ip, port);
        }
        
        closesocket(sock);
        return isScanner;
    }
    
    // Test multiple eSCL endpoints
    bool TesteSCLEndpoints(SOCKET sock, const std::string& ip, int port) {
        // Set socket back to blocking
        u_long mode = 0;
        ioctlsocket(sock, FIONBIO, &mode);
        
        // List of eSCL endpoints to test
        const char* endpoints[] = {
            "/eSCL/ScannerCapabilities",
            "/eSCL/ScannerStatus", 
            "/ipp/print",
            "/hp/device/info_ConfigDyn.xml",
            "/canon/info/device.xml",
            "/DevMgmt/DiscoveryTree.xml"
        };
        
        for (const char* endpoint : endpoints) {
            if (TestHTTPEndpoint(sock, ip, port, endpoint)) {
                return true;
            }
        }
        
        return false;
    }
    
    // Test specific HTTP endpoint for eSCL capability
    bool TestHTTPEndpoint(SOCKET sock, const std::string& ip, int port, const char* endpoint) {
        // Construct HTTP GET request
        std::string request = "GET " + std::string(endpoint) + " HTTP/1.1\r\n";
        request += "Host: " + ip + ":" + std::to_string(port) + "\r\n";
        request += "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)\r\n";
        request += "Accept: text/xml, application/xml, */*\r\n";
        request += "Connection: close\r\n\r\n";
        
        if (send(sock, request.c_str(), request.length(), 0) <= 0) {
            return false;
        }
        
        // Read response
        char buffer[2048];
        int received = recv(sock, buffer, sizeof(buffer) - 1, 0);
        if (received <= 0) {
            return false;
        }
        
        buffer[received] = '\0';
        std::string response(buffer);
        
        // Check for eSCL/scanner indicators in response
        std::string lowercaseResponse = response;
        std::transform(lowercaseResponse.begin(), lowercaseResponse.end(), lowercaseResponse.begin(), ::tolower);
        
        return lowercaseResponse.find("scannercapabilities") != std::string::npos ||
               lowercaseResponse.find("pwg:scannercapabilities") != std::string::npos ||
               lowercaseResponse.find("escl") != std::string::npos ||
               lowercaseResponse.find("application/xml") != std::string::npos ||
               lowercaseResponse.find("text/xml") != std::string::npos ||
               (lowercaseResponse.find("200 ok") != std::string::npos && 
                lowercaseResponse.find("printer") != std::string::npos);
    }
    
    // Get detailed eSCL scanner information
    std::string GeteSCLScannerInfo(const std::string& ip, int port) {
        std::string scannerName = "eSCL Scanner";
        std::string model = "";
        std::string manufacturer = "";
        
        // Try to get device information from common endpoints
        std::vector<std::string> infoEndpoints = {
            "/eSCL/ScannerCapabilities",
            "/DevMgmt/DiscoveryTree.xml",
            "/hp/device/info_ConfigDyn.xml",
            "/canon/info/device.xml"
        };
        
        for (const auto& endpoint : infoEndpoints) {
            auto deviceInfo = FetchDeviceInfo(ip, port, endpoint);
            if (!deviceInfo.empty()) {
                manufacturer = ExtractXMLValue(deviceInfo, "manufacturer", "make", "vendor");
                model = ExtractXMLValue(deviceInfo, "model", "modelname", "product");
                
                if (!manufacturer.empty() || !model.empty()) {
                    break;
                }
            }
        }
        
        // Construct scanner name
        if (!manufacturer.empty() && !model.empty()) {
            scannerName = manufacturer + " " + model;
        } else if (!model.empty()) {
            scannerName = model;
        } else if (!manufacturer.empty()) {
            scannerName = manufacturer + " Scanner";
        }
        
        return scannerName + " (" + ip + ":" + std::to_string(port) + ")";
    }
    
    // Fetch device information via HTTP
    std::string FetchDeviceInfo(const std::string& ip, int port, const std::string& endpoint) {
        SOCKET sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (sock == INVALID_SOCKET) {
            return "";
        }
        
        // Set timeout
        DWORD timeout = 2000; // 2 seconds
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char*)&timeout, sizeof(timeout));
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (char*)&timeout, sizeof(timeout));
        
        sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        inet_pton(AF_INET, ip.c_str(), &addr.sin_addr);
        
        if (connect(sock, (sockaddr*)&addr, sizeof(addr)) != 0) {
            closesocket(sock);
            return "";
        }
        
        // Send HTTP request
        std::string request = "GET " + endpoint + " HTTP/1.1\r\n";
        request += "Host: " + ip + "\r\n";
        request += "Accept: text/xml, application/xml\r\n";
        request += "Connection: close\r\n\r\n";
        
        if (send(sock, request.c_str(), request.length(), 0) <= 0) {
            closesocket(sock);
            return "";
        }
        
        // Read response
        std::string response;
        char buffer[1024];
        int received;
        
        while ((received = recv(sock, buffer, sizeof(buffer) - 1, 0)) > 0) {
            buffer[received] = '\0';
            response += buffer;
        }
        
        closesocket(sock);
        
        // Extract body from HTTP response
        size_t bodyStart = response.find("\r\n\r\n");
        if (bodyStart != std::string::npos) {
            return response.substr(bodyStart + 4);
        }
        
        return response;
    }
    
    // Extract value from XML using multiple possible tag names
    std::string ExtractXMLValue(const std::string& xml, const std::string& tag1, 
                               const std::string& tag2 = "", const std::string& tag3 = "") {
        std::vector<std::string> tags = {tag1};
        if (!tag2.empty()) tags.push_back(tag2);
        if (!tag3.empty()) tags.push_back(tag3);
        
        for (const auto& tag : tags) {
            std::string openTag = "<" + tag + ">";
            std::string closeTag = "</" + tag + ">";
            
            size_t start = xml.find(openTag);
            if (start != std::string::npos) {
                start += openTag.length();
                size_t end = xml.find(closeTag, start);
                if (end != std::string::npos) {
                    std::string value = xml.substr(start, end - start);
                    // Clean up value
                    value.erase(0, value.find_first_not_of(" \t\r\n"));
                    value.erase(value.find_last_not_of(" \t\r\n") + 1);
                    if (!value.empty()) {
                        return value;
                    }
                }
            }
        }
        
        return "";
    }
    
    // SNMP Scanner Discovery
    void DiscoverSNMPScanners(std::vector<std::string>& scanners) {
        // TODO: Implement SNMP scanner discovery
        // This requires SNMP API calls
        // For now, we'll skip this implementation
    }
    
    // Helper method to get local network IP ranges
    std::vector<std::string> GetLocalNetworkIPs() {
        std::vector<std::string> ips;
        
        IP_ADAPTER_INFO* adapterInfo = nullptr;
        DWORD bufferSize = 0;
        
        GetAdaptersInfo(nullptr, &bufferSize);
        adapterInfo = (IP_ADAPTER_INFO*)malloc(bufferSize);
        
        if (GetAdaptersInfo(adapterInfo, &bufferSize) == NO_ERROR) {
            IP_ADAPTER_INFO* adapter = adapterInfo;
            while (adapter) {
                if (adapter->Type == MIB_IF_TYPE_ETHERNET || 
                    adapter->Type == IF_TYPE_IEEE80211) {
                    
                    std::string ip = adapter->IpAddressList.IpAddress.String;
                    if (ip != "0.0.0.0") {
                        // Extract base IP (remove last octet)
                        size_t lastDot = ip.find_last_of('.');
                        if (lastDot != std::string::npos) {
                            ips.push_back(ip.substr(0, lastDot + 1));
                        }
                    }
                }
                adapter = adapter->Next;
            }
        }
        
        if (adapterInfo) {
            free(adapterInfo);
        }
        
        return ips;
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
        IWiaItem2* rootItem = nullptr;
        BSTR deviceIdBstr = SysAllocString(deviceId.c_str());
        HRESULT hr = deviceManager->CreateDevice(0, deviceIdBstr, &rootItem);
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
        IWiaItem2* scannerItem = nullptr;
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
        IWiaItem2* testItem = nullptr;
        BSTR deviceIdBstr = SysAllocString(deviceId.c_str());
        
        HRESULT hr = deviceManager->CreateDevice(0, deviceIdBstr, &testItem);
        SysFreeString(deviceIdBstr);
        
        if (testItem) {
            testItem->Release();
            return SUCCEEDED(hr);
        }
        
        return false;
    }

    HRESULT GetScannerItem(IWiaItem2* rootItem, IWiaItem2** scannerItem) {
        IEnumWiaItem2* enumItems = nullptr;
        HRESULT hr = rootItem->EnumChildItems(nullptr, &enumItems);
        
        if (!SUCCEEDED(hr)) {
            return hr;
        }
        
        IWiaItem2* item = nullptr;
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
    
    HRESULT SetScanProperties(IWiaItem2* scannerItem, bool isNetworkScanner = false) {
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
    
    std::string PerformScan(IWiaItem2* scannerItem, const std::string& outputPath) {
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

// Map Windows error codes to user-friendly messages for WiFi scanners
std::string MapWiFiErrorCode(HRESULT hr) {
    switch (hr) {
        // Network-specific errors
        case WSAENETDOWN:
            return "NETWORK_DOWN";
        case WSAENETUNREACH:
            return "NETWORK_UNREACHABLE";
        case WSAETIMEDOUT:
            return "SCANNER_TIMEOUT";
        case WSAECONNREFUSED:
            return "SCANNER_CONNECTION_REFUSED";
        case WSAEHOSTUNREACH:
            return "SCANNER_HOST_UNREACHABLE";
        case WSAEHOSTDOWN:
            return "SCANNER_HOST_DOWN";
        case WSAENOBUFS:
            return "NETWORK_BUFFER_FULL";
        case WSAEMSGSIZE:
            return "NETWORK_MESSAGE_TOO_LARGE";
        case WSAECONNRESET:
            return "SCANNER_CONNECTION_RESET";
        case WSAECONNABORTED:
            return "SCANNER_CONNECTION_ABORTED";
        case WSAEADDRNOTAVAIL:
            return "SCANNER_ADDRESS_NOT_AVAILABLE";
        case WSAEINVAL:
            return "INVALID_SCANNER_ADDRESS";
        
        // WIA-specific errors for network scanners
        case WIA_ERROR_OFFLINE:
            return "NETWORK_SCANNER_OFFLINE";
        case WIA_ERROR_WARMING_UP:
            return "NETWORK_SCANNER_WARMING_UP";
        case WIA_ERROR_USER_INTERVENTION:
            return "NETWORK_SCANNER_USER_INTERVENTION_REQUIRED";
        case WIA_ERROR_BUSY:
            return "NETWORK_SCANNER_BUSY";
        case WIA_ERROR_PAPER_EMPTY:
            return "NETWORK_SCANNER_PAPER_EMPTY";
        case WIA_ERROR_PAPER_JAM:
            return "NETWORK_SCANNER_PAPER_JAM";
        case WIA_ERROR_COVER_OPEN:
            return "NETWORK_SCANNER_COVER_OPEN";
        
        // Extended WiFi-specific errors
        case ERROR_TIMEOUT:
            return "WIFI_SCANNER_TIMEOUT";
        case ERROR_NETWORK_UNREACHABLE:
            return "WIFI_NETWORK_UNREACHABLE";
        case ERROR_ACCESS_DENIED:
            return "WIFI_SCANNER_ACCESS_DENIED";
        case ERROR_INVALID_HANDLE:
            return "WIFI_SCANNER_INVALID_HANDLE";
        case ERROR_NOT_ENOUGH_MEMORY:
            return "WIFI_SCANNER_INSUFFICIENT_MEMORY";
        case ERROR_INVALID_PARAMETER:
            return "WIFI_SCANNER_INVALID_PARAMETER";
        case ERROR_INSUFFICIENT_BUFFER:
            return "WIFI_SCANNER_BUFFER_TOO_SMALL";
        case ERROR_OPERATION_ABORTED:
            return "WIFI_SCANNER_OPERATION_ABORTED";
        case ERROR_IO_PENDING:
            return "WIFI_SCANNER_OPERATION_PENDING";
        case ERROR_INVALID_USER_BUFFER:
            return "WIFI_SCANNER_INVALID_BUFFER";
        case ERROR_NOT_SUPPORTED:
            return "WIFI_SCANNER_NOT_SUPPORTED";
        case ERROR_INVALID_STATE:
            return "WIFI_SCANNER_INVALID_STATE";
        case ERROR_BUFFER_OVERFLOW:
            return "WIFI_SCANNER_BUFFER_OVERFLOW";
        case ERROR_MORE_DATA:
            return "WIFI_SCANNER_MORE_DATA_AVAILABLE";
        case ERROR_SERVICE_NOT_ACTIVE:
            return "WIFI_SCANNER_SERVICE_NOT_ACTIVE";
        case ERROR_INVALID_FUNCTION:
            return "WIFI_SCANNER_INVALID_FUNCTION";
        case ERROR_CANCELLED:
            return "WIFI_SCANNER_CANCELLED";
        case ERROR_REQUEST_ABORTED:
            return "WIFI_SCANNER_REQUEST_ABORTED";
        case ERROR_RETRY:
            return "WIFI_SCANNER_RETRY_REQUIRED";
        
        // HTTP-specific errors for eSCL scanners
        case 400:
            return "ESCL_BAD_REQUEST";
        case 401:
            return "ESCL_UNAUTHORIZED";
        case 403:
            return "ESCL_FORBIDDEN";
        case 404:
            return "ESCL_NOT_FOUND";
        case 409:
            return "ESCL_CONFLICT";
        case 500:
            return "ESCL_INTERNAL_SERVER_ERROR";
        case 503:
            return "ESCL_SERVICE_UNAVAILABLE";
        
        // Common network scanner errors
        default:
            if (FAILED(hr)) {
                if (hr >= 0x80000000 && hr <= 0x8000FFFF) {
                    return "NETWORK_SCANNER_SYSTEM_ERROR";
                } else if (hr >= 0x80040000 && hr <= 0x8004FFFF) {
                    return "NETWORK_SCANNER_WIA_ERROR";
                } else if (hr >= 0x80070000 && hr <= 0x8007FFFF) {
                    return "NETWORK_SCANNER_WIN32_ERROR";
                } else {
                    return "NETWORK_SCANNER_UNKNOWN_ERROR";
                }
            }
            return "SUCCESS";
    }
}

// Check if error is WiFi/network related
bool IsNetworkError(HRESULT hr) {
    return hr == WSAENETDOWN || hr == WSAENETUNREACH || hr == WSAETIMEDOUT || 
           hr == WSAECONNREFUSED || hr == WSAEHOSTUNREACH || hr == WSAEHOSTDOWN ||
           hr == WIA_ERROR_OFFLINE || hr == WIA_ERROR_BUSY ||
           hr == ERROR_TIMEOUT || hr == ERROR_NETWORK_UNREACHABLE;
}

// Get user-friendly WiFi error message in Turkish
std::string GetWiFiErrorMessage(const std::string& errorCode) {
    static std::map<std::string, std::string> errorMessages = {
        {"NETWORK_DOWN", "Ağ bağlantısı kesildi"},
        {"NETWORK_UNREACHABLE", "Ağa ulaşılamıyor"},
        {"SCANNER_TIMEOUT", "Tarayıcı zaman aşımına uğradı"},
        {"SCANNER_CONNECTION_REFUSED", "Tarayıcı bağlantıyı reddetti"},
        {"SCANNER_HOST_UNREACHABLE", "Tarayıcıya ulaşılamıyor"},
        {"SCANNER_HOST_DOWN", "Tarayıcı çevrimdışı"},
        {"NETWORK_BUFFER_FULL", "Ağ tamponu dolu"},
        {"NETWORK_MESSAGE_TOO_LARGE", "Veri çok büyük"},
        {"SCANNER_CONNECTION_RESET", "Bağlantı sıfırlandı"},
        {"SCANNER_CONNECTION_ABORTED", "Bağlantı iptal edildi"},
        {"SCANNER_ADDRESS_NOT_AVAILABLE", "Tarayıcı adresi kullanılamıyor"},
        {"INVALID_SCANNER_ADDRESS", "Geçersiz tarayıcı adresi"},
        {"NETWORK_SCANNER_OFFLINE", "Tarayıcı çevrimdışı"},
        {"NETWORK_SCANNER_WARMING_UP", "Tarayıcı ısınıyor"},
        {"NETWORK_SCANNER_USER_INTERVENTION_REQUIRED", "Tarayıcıda kullanıcı müdahalesi gerekli"},
        {"NETWORK_SCANNER_BUSY", "Tarayıcı meşgul"},
        {"NETWORK_SCANNER_PAPER_EMPTY", "Tarayıcıda kağıt yok"},
        {"NETWORK_SCANNER_PAPER_JAM", "Tarayıcıda kağıt sıkışması"},
        {"NETWORK_SCANNER_COVER_OPEN", "Tarayıcı kapağı açık"},
        {"WIFI_SCANNER_TIMEOUT", "WiFi tarayıcı zaman aşımı"},
        {"WIFI_NETWORK_UNREACHABLE", "WiFi ağına ulaşılamıyor"},
        {"WIFI_SCANNER_ACCESS_DENIED", "Tarayıcıya erişim reddedildi"},
        {"WIFI_SCANNER_INVALID_HANDLE", "Geçersiz tarayıcı tanımlayıcısı"},
        {"WIFI_SCANNER_INSUFFICIENT_MEMORY", "Yetersiz bellek"},
        {"WIFI_SCANNER_INVALID_PARAMETER", "Geçersiz parametre"},
        {"WIFI_SCANNER_BUFFER_TOO_SMALL", "Tampon çok küçük"},
        {"WIFI_SCANNER_OPERATION_ABORTED", "İşlem iptal edildi"},
        {"WIFI_SCANNER_OPERATION_PENDING", "İşlem beklemede"},
        {"WIFI_SCANNER_INVALID_BUFFER", "Geçersiz tampon"},
        {"WIFI_SCANNER_NOT_SUPPORTED", "Desteklenmiyor"},
        {"WIFI_SCANNER_INVALID_STATE", "Geçersiz durum"},
        {"WIFI_SCANNER_BUFFER_OVERFLOW", "Tampon taşması"},
        {"WIFI_SCANNER_MORE_DATA_AVAILABLE", "Daha fazla veri mevcut"},
        {"WIFI_SCANNER_SERVICE_NOT_ACTIVE", "Servis aktif değil"},
        {"WIFI_SCANNER_INVALID_FUNCTION", "Geçersiz fonksiyon"},
        {"WIFI_SCANNER_CANCELLED", "İptal edildi"},
        {"WIFI_SCANNER_REQUEST_ABORTED", "İstek iptal edildi"},
        {"WIFI_SCANNER_RETRY_REQUIRED", "Tekrar deneme gerekli"},
        {"ESCL_BAD_REQUEST", "Hatalı istek"},
        {"ESCL_UNAUTHORIZED", "Yetkisiz erişim"},
        {"ESCL_FORBIDDEN", "Yasak erişim"},
        {"ESCL_NOT_FOUND", "Bulunamadı"},
        {"ESCL_CONFLICT", "Çakışma"},
        {"ESCL_INTERNAL_SERVER_ERROR", "Sunucu hatası"},
        {"ESCL_SERVICE_UNAVAILABLE", "Servis kullanılamıyor"},
        {"NETWORK_SCANNER_SYSTEM_ERROR", "Sistem hatası"},
        {"NETWORK_SCANNER_WIA_ERROR", "WIA hatası"},
        {"NETWORK_SCANNER_WIN32_ERROR", "Windows hatası"},
        {"NETWORK_SCANNER_UNKNOWN_ERROR", "Bilinmeyen hata"},
        {"NETWORK_SCANNER_UNREACHABLE", "Ağ tarayıcısına ulaşılamıyor"},
        {"WEAK_SIGNAL", "Zayıf WiFi sinyali"},
        {"NETWORK_CONGESTION", "Ağ trafiği yoğun"},
        {"WIFI_SCAN_FAILED", "WiFi tarama başarısız"}
    };
    
    auto it = errorMessages.find(errorCode);
    if (it != errorMessages.end()) {
        return it->second;
    }
    
    return "Bilinmeyen WiFi tarayıcı hatası: " + errorCode;
}

// Get troubleshooting suggestions for WiFi scanner errors
std::vector<std::string> GetWiFiTroubleshootingSuggestions(const std::string& errorCode) {
    std::vector<std::string> suggestions;
    
    if (errorCode.find("NETWORK") != std::string::npos || 
        errorCode.find("WIFI") != std::string::npos) {
        suggestions.push_back("WiFi bağlantınızı kontrol edin");
        suggestions.push_back("Router'ı yeniden başlatın");
        suggestions.push_back("Tarayıcının WiFi ağına bağlı olduğundan emin olun");
    }
    
    if (errorCode.find("TIMEOUT") != std::string::npos) {
        suggestions.push_back("Router'a daha yakın konumda deneyin");
        suggestions.push_back("Ağ trafiğinin yoğun olmadığı bir zamanda deneyin");
        suggestions.push_back("Tarayıcı ayarlarında timeout değerini artırın");
    }
    
    if (errorCode.find("UNREACHABLE") != std::string::npos || 
        errorCode.find("HOST_DOWN") != std::string::npos) {
        suggestions.push_back("Tarayıcının IP adresini kontrol edin");
        suggestions.push_back("Tarayıcıyı yeniden başlatın");
        suggestions.push_back("Firewall ayarlarını kontrol edin");
    }
    
    if (errorCode.find("BUSY") != std::string::npos || 
        errorCode.find("LOCKED") != std::string::npos) {
        suggestions.push_back("Tarayıcının başka bir işlem yapıp yapmadığını kontrol edin");
        suggestions.push_back("Birkaç dakika bekleyip tekrar deneyin");
        suggestions.push_back("Tarayıcı panelinden mevcut işlemleri iptal edin");
    }
    
    if (errorCode.find("ACCESS_DENIED") != std::string::npos || 
        errorCode.find("UNAUTHORIZED") != std::string::npos) {
        suggestions.push_back("Tarayıcı güvenlik ayarlarını kontrol edin");
        suggestions.push_back("Kullanıcı adı ve şifre gerekip gerekmediğini kontrol edin");
        suggestions.push_back("Tarayıcı erişim izinlerini kontrol edin");
    }
    
    if (errorCode.find("ESCL") != std::string::npos) {
        suggestions.push_back("Tarayıcının AirPrint özelliğinin aktif olduğundan emin olun");
        suggestions.push_back("Tarayıcı firmware'ini güncelleyin");
        suggestions.push_back("Tarayıcı web arayüzünden eSCL ayarlarını kontrol edin");
    }
    
    // General suggestions
    suggestions.push_back("Tarayıcı sürücülerini güncelleyin");
    suggestions.push_back("Bilgisayarı yeniden başlatın");
    suggestions.push_back("Sistem yöneticisine başvurun");
    
    return suggestions;
}

// Restore warnings
#pragma warning(pop) 