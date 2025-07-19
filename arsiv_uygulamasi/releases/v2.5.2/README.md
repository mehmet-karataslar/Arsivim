# Arşivim v2.5.2 Release Notes

## 📅 Release Date
July 19, 2025

## 🚀 What's New in v2.5.2

### Major Updates
- **Updated Dependencies**: All Flutter packages updated to latest compatible versions
- **Enhanced Compatibility**: Resolved package conflicts and improved stability
- **Android API 35**: Updated to support the latest Android version
- **Modern Build System**: Updated Gradle and build configurations

### 🔧 Technical Improvements
- **Updated Android Target SDK**: Now targeting Android API 35
- **Updated Compile SDK**: Compile SDK updated to 35
- **Package Compatibility**: Fixed compatibility issues between packages
- **QR Scanner**: Switched to `simple_barcode_scanner` for better stability
- **Notifications**: Updated to `flutter_local_notifications` v19.3.1
- **Timezone Support**: Updated timezone package for better cross-platform support

### 📱 Build Information
- **Version Code**: 12
- **Version Name**: 2.5.2
- **Min SDK**: 23 (Android 6.0+)
- **Target SDK**: 35 (Android 15)
- **Flutter Version**: 3.32.5
- **Dart Version**: 3.8.1

### 🛠️ Development Improvements
- **Flutter Lints**: Updated to v6.0.0 for better code quality
- **MultiDex**: Enabled for large app support
- **Core Library Desugaring**: Updated to v2.1.4
- **Build Optimization**: Enhanced build configurations

### 📦 Available Downloads

| Platform | File | Description |
|----------|------|-------------|
| Android | `Arsivcim-v2.5.2-android.apk` | Android APK (86.2 MB) |
| Windows | `Arsivcim-v2.5.2-windows-x64.zip` | Windows x64 package |
| Windows | `windows/arsiv_uygulamasi.exe` | Direct Windows executable |

### 🔍 Package Updates
- `flutter_local_notifications`: 17.2.4 → 19.3.1
- `mobile_scanner`: Replaced with `simple_barcode_scanner` v0.3.0
- `timezone`: 0.9.4 → 0.10.1
- `flutter_lints`: 5.0.0 → 6.0.0
- `permission_handler`: Compatible with v11.4.0

### 🐛 Bug Fixes
- Fixed Kotlin compilation errors in QR scanner
- Resolved package namespace conflicts
- Fixed Android build compatibility issues
- Improved null safety handling

### 💻 System Requirements

#### Android
- Android 6.0 (API level 23) or higher
- ARM64 or x86_64 architecture
- ~100 MB free storage space

#### Windows
- Windows 10 64-bit or later
- .NET Framework 4.7.2 or later
- ~150 MB free storage space

### 📋 Installation Instructions

#### Android
1. Download `Arsivcim-v2.5.2-android.apk`
2. Enable "Install from Unknown Sources" if needed
3. Install the APK file
4. Grant required permissions when prompted

#### Windows
1. Download `Arsivcim-v2.5.2-windows-x64.zip`
2. Extract to your desired location
3. Run `arsiv_uygulamasi.exe`
4. Windows Defender may show a warning (allow the app)

### 🔐 Security Notes
- All builds are compiled from verified source code
- No external dependencies with security vulnerabilities
- Permissions are minimal and necessary for functionality

### 🎯 Known Issues
- Some antivirus software may flag the Windows executable (false positive)
- First-time camera permission may require app restart on some devices

### 📞 Support
If you encounter any issues, please check the documentation or report them on our GitHub repository.

---
**Full Changelog**: [v2.4.10...v2.5.2](https://github.com/user/arsiv_uygulamasi/compare/v2.4.10...v2.5.2) 