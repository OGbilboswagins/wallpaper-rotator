#include <windows.h>
#include <shobjidl.h>
#include <string>

DESKTOP_WALLPAPER_POSITION GetWallpaperPositionFromInt(int fitMode) {
    switch (fitMode) {
        case 1:
            return DWPOS_FILL;
        case 2:
            return DWPOS_STRETCH;
        case 3:
            return DWPOS_CENTER;
        case 0:
        default:
            return DWPOS_FIT;
    }
}

extern "C" __declspec(dllexport)
int GetMonitorCount() {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    bool didInit = SUCCEEDED(hr);

    IDesktopWallpaper* wallpaper = nullptr;
    hr = CoCreateInstance(
        __uuidof(DesktopWallpaper),
        nullptr,
        CLSCTX_ALL,
        IID_PPV_ARGS(&wallpaper)
    );

    if (FAILED(hr) || wallpaper == nullptr) {
        if (didInit) CoUninitialize();
        return 0;
    }

    UINT count = 0;
    wallpaper->GetMonitorDevicePathCount(&count);

    wallpaper->Release();

    if (didInit) CoUninitialize();

    return static_cast<int>(count);
}

extern "C" __declspec(dllexport)
int ApplyMonitorWallpaper(int monitorIndex, const wchar_t* imagePath, int fitMode) {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    bool didInit = SUCCEEDED(hr);

    IDesktopWallpaper* wallpaper = nullptr;
    hr = CoCreateInstance(
        __uuidof(DesktopWallpaper),
        nullptr,
        CLSCTX_ALL,
        IID_PPV_ARGS(&wallpaper)
    );

    if (FAILED(hr) || wallpaper == nullptr) {
        if (didInit) CoUninitialize();
        return -1;
    }

    UINT count = 0;
    hr = wallpaper->GetMonitorDevicePathCount(&count);

    if (FAILED(hr) || monitorIndex < 0 || static_cast<UINT>(monitorIndex) >= count) {
        wallpaper->Release();
        if (didInit) CoUninitialize();
        return -2;
    }

    LPWSTR monitorId = nullptr;
    hr = wallpaper->GetMonitorDevicePathAt(
        static_cast<UINT>(monitorIndex),
        &monitorId
    );

    if (FAILED(hr) || monitorId == nullptr) {
        wallpaper->Release();
        if (didInit) CoUninitialize();
        return -3;
    }

// SetPosition is global, so do not set it per monitor here.
// wallpaper->SetPosition(GetWallpaperPositionFromInt(fitMode));

    hr = wallpaper->SetWallpaper(monitorId, imagePath);

    CoTaskMemFree(monitorId);
    wallpaper->Release();

    if (didInit) CoUninitialize();

    if (FAILED(hr)) {
        return -4;
    }

    return 0;
}