#include <windows.h>
#include <shobjidl.h>
#include <string>

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