#ifndef SCANNER_PLUGIN_H
#define SCANNER_PLUGIN_H

#ifdef __cplusplus
extern "C" {
#endif

// Initialize the scanner plugin
__declspec(dllexport) void InitializeScannerPlugin();

// Cleanup the scanner plugin
__declspec(dllexport) void CleanupScannerPlugin();

// Find available scanners
// Returns the number of characters written to buffer
__declspec(dllexport) int FindScanners(char* buffer, int bufferSize);

// Scan a document with the specified scanner
// Returns the number of characters written to resultBuffer
__declspec(dllexport) int ScanDocument(const char* scannerName, const char* outputPath, char* resultBuffer, int bufferSize);

#ifdef __cplusplus
}
#endif

#endif // SCANNER_PLUGIN_H 