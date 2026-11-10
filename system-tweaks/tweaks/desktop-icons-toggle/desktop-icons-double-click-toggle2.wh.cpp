// ==WindhawkMod==
// @id              desktop-icons-double-click-toggle2
// @name            Desktop Icons Double-Click Toggle
// @description     Toggle desktop icons by double-clicking an empty area of the desktop.
// @version         1.4
// @author          akumy
// @github          https://github.com/Akumy-01
// @include         explorer.exe
// @compilerOptions -lcomctl32
// @license         MIT
// ==/WindhawkMod==

// ==WindhawkModReadme==
/*
# Desktop Icons Double-Click Toggle

Double-click an empty area of the desktop to hide the desktop icons. Double-click
the desktop again to show them.

Double-clicking a desktop icon still opens it normally. Only empty desktop space
triggers the toggle.
*/
// ==/WindhawkModReadme==

// ==WindhawkModSettings==
/*
- DoubleClickTimeMs: 0
  $name: Double-click time
  $description: Maximum time between clicks in milliseconds. Use 0 for the Windows system setting.
- DoubleClickDistancePx: 0
  $name: Double-click distance
  $description: Maximum pointer movement between clicks in pixels. Use 0 for the Windows system setting.
- RestoreInitialStateOnUnload: true
  $name: Restore initial state on unload
  $description: Restore desktop icon visibility to the state that was active when the mod loaded.
- HideIconsOnStartup: true
  $name: Hide icons on startup
  $description: Hide desktop icons automatically when the mod loads, e.g. after logon or an Explorer restart. Double-click the desktop to show them again.
*/
// ==/WindhawkModSettings==

#include <windows.h>
#include <commctrl.h>

#ifndef GUI_INMENUMODE
#define GUI_INMENUMODE 0x00000004
#endif

#ifndef GUI_POPUPMENUMODE
#define GUI_POPUPMENUMODE 0x00000010
#endif

struct Settings {
    DWORD doubleClickTimeMs;
    int doubleClickDistancePx;
    bool restoreInitialStateOnUnload;
    bool hideIconsOnStartup;
};

static Settings g_settings{};
static CRITICAL_SECTION g_lock;
static HANDLE g_stopEvent;
static HANDLE g_workerThread;
static HHOOK g_mouseHook;
static DWORD g_hookThreadId;
static HWND g_defView;
static HWND g_listView;
static bool g_haveInitialVisibility;
static bool g_initialIconsVisible;
static bool g_modifiedVisibility;
static bool g_startupHidePending;
static bool g_leftButtonDownEligible;
static POINT g_leftButtonDownPt;
static DWORD g_lastClickTime;
static POINT g_lastClickPt;

static int AbsInt(int value) {
    return value < 0 ? -value : value;
}

static void LoadSettings() {
    g_settings.doubleClickTimeMs =
        static_cast<DWORD>(Wh_GetIntSetting(L"DoubleClickTimeMs"));
    g_settings.doubleClickDistancePx =
        Wh_GetIntSetting(L"DoubleClickDistancePx");
    g_settings.restoreInitialStateOnUnload =
        Wh_GetIntSetting(L"RestoreInitialStateOnUnload") != 0;
    g_settings.hideIconsOnStartup =
        Wh_GetIntSetting(L"HideIconsOnStartup") != 0;
}

static HWND FindDesktopDefView() {
    HWND progman = FindWindowW(L"Progman", nullptr);
    HWND defView = FindWindowExW(progman, nullptr, L"SHELLDLL_DefView", nullptr);
    if (defView) {
        return defView;
    }

    HWND worker = nullptr;
    while ((worker = FindWindowExW(nullptr, worker, L"WorkerW", nullptr))) {
        defView = FindWindowExW(worker, nullptr, L"SHELLDLL_DefView", nullptr);
        if (defView) {
            return defView;
        }
    }

    return nullptr;
}

static HWND FindDesktopListView(HWND defView) {
    if (!defView) {
        return nullptr;
    }

    return FindWindowExW(defView, nullptr, L"SysListView32", nullptr);
}

static bool RefreshDesktopWindowsLocked() {
    if (IsWindow(g_defView) && IsWindow(g_listView)) {
        return true;
    }

    g_defView = FindDesktopDefView();
    g_listView = FindDesktopListView(g_defView);

    if (!g_defView || !g_listView) {
        return false;
    }

    if (!g_haveInitialVisibility) {
        g_initialIconsVisible = IsWindowVisible(g_listView) != FALSE;
        g_haveInitialVisibility = true;
    }

    return true;
}

static bool IsDesktopTargetLocked(HWND hwnd) {
    if (!RefreshDesktopWindowsLocked()) {
        return false;
    }

    HWND desktopParent = GetAncestor(g_defView, GA_PARENT);

    return hwnd == g_listView || hwnd == g_defView || hwnd == desktopParent ||
           IsChild(g_listView, hwnd) || IsChild(g_defView, hwnd);
}

static bool IsPopupMenuWindow(HWND hwnd) {
    wchar_t className[32]{};
    return IsWindow(hwnd) &&
           GetClassNameW(hwnd, className,
                         sizeof(className) / sizeof(className[0])) &&
           lstrcmpW(className, L"#32768") == 0;
}

static bool IsPopupMenuActiveLocked() {
    GUITHREADINFO guiThreadInfo{sizeof(guiThreadInfo)};
    if (!g_hookThreadId || !GetGUIThreadInfo(g_hookThreadId, &guiThreadInfo)) {
        return false;
    }

    return (guiThreadInfo.flags & (GUI_INMENUMODE | GUI_POPUPMENUMODE)) != 0;
}

static bool IsBlankListViewPointLocked(POINT screenPt) {
    if (!RefreshDesktopWindowsLocked()) {
        return false;
    }

    POINT clientPt = screenPt;
    ScreenToClient(g_listView, &clientPt);

    LVHITTESTINFO hitTest{};
    hitTest.pt = clientPt;
    int item = ListView_HitTest(g_listView, &hitTest);

    return item == -1 || (hitTest.flags & LVHT_NOWHERE) ||
           !(hitTest.flags & LVHT_ONITEM);
}

static void RedrawDesktopLocked() {
    if (!g_defView) {
        return;
    }

    RedrawWindow(g_defView, nullptr, nullptr,
                 RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN);

    HWND desktopParent = GetAncestor(g_defView, GA_PARENT);
    if (desktopParent) {
        RedrawWindow(desktopParent, nullptr, nullptr,
                     RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN);
    }
}

static bool IsDesktopLabelEditingLocked();

// 返回 true 表示已执行；false 表示被「正在重命名」保护拦下。
// protectEditing=false 只给卸载时的状态恢复用：那时没有用户编辑可言，
// 而且必须尽力把图标可见性还原回去。
static bool SetDesktopIconsVisibleLocked(bool visible,
                                         bool protectEditing = true) {
    // 重命名期间对 SysListView32 做 ShowWindow 会销毁就地编辑框
    // （实测事件序列 HIDE -> DESTROY），所以把保护下沉到这一个出入口，
    // 让 startup hide / 双击 toggle / 卸载恢复三条路径都受同一份保护。
    if (protectEditing && IsDesktopLabelEditingLocked()) {
        return false;
    }

    if (!RefreshDesktopWindowsLocked()) {
        return false;
    }

    ShowWindow(g_listView, visible ? SW_SHOW : SW_HIDE);
    g_modifiedVisibility = true;
    RedrawDesktopLocked();
    return true;
}

static void ToggleDesktopIconsLocked() {
    // 重命名期间不切换图标，防止重命名被取消
    if (IsDesktopLabelEditingLocked()) {
        return;
    }

    if (!RefreshDesktopWindowsLocked()) {
        return;
    }

    bool iconsVisible = IsWindowVisible(g_listView) != FALSE;
    if (SetDesktopIconsVisibleLocked(!iconsVisible)) {
        Wh_Log(L"Desktop icons %s", iconsVisible ? L"hidden" : L"shown");
    }
}

static bool IsSecondClickLocked(POINT pt) {
    DWORD now = GetTickCount();
    DWORD maxTime =
        g_settings.doubleClickTimeMs ? g_settings.doubleClickTimeMs
                                     : GetDoubleClickTime();

    int maxDistanceX =
        g_settings.doubleClickDistancePx ? g_settings.doubleClickDistancePx
                                         : GetSystemMetrics(SM_CXDOUBLECLK);
    int maxDistanceY =
        g_settings.doubleClickDistancePx ? g_settings.doubleClickDistancePx
                                         : GetSystemMetrics(SM_CYDOUBLECLK);

    bool secondClick =
        g_lastClickTime != 0 && now - g_lastClickTime <= maxTime &&
        AbsInt(pt.x - g_lastClickPt.x) <= maxDistanceX &&
        AbsInt(pt.y - g_lastClickPt.y) <= maxDistanceY;

    g_lastClickTime = now;
    g_lastClickPt = pt;

    if (secondClick) {
        g_lastClickTime = 0;
    }

    return secondClick;
}

static void ResetClickStateLocked() {
    g_leftButtonDownEligible = false;
    g_lastClickTime = 0;
}

static bool IsDesktopLabelEditingLocked() {
    if (!RefreshDesktopWindowsLocked()) {
        return false;
    }

    // 桌面图标重命名时，SysListView32 会创建一个 Edit 子窗口作为编辑框
    return FindWindowExW(g_listView, nullptr, L"Edit", nullptr) != nullptr;
}

static bool IsEligibleDesktopClickPointLocked(POINT pt) {
    // 重命名（标签编辑）期间不响应任何点击，避免误判导致重命名被取消
    if (IsDesktopLabelEditingLocked()) {
        return false;
    }

    if (IsPopupMenuActiveLocked()) {
        return false;
    }

    HWND hwnd = WindowFromPoint(pt);
    if (!hwnd || IsPopupMenuWindow(hwnd) || !IsDesktopTargetLocked(hwnd)) {
        return false;
    }

    // 点击落在 SysListView32 子窗口（如重命名编辑框）上时，不算桌面空白
    if (hwnd != g_listView && IsChild(g_listView, hwnd)) {
        return false;
    }

    return !IsWindowVisible(g_listView) || IsBlankListViewPointLocked(pt);
}

static void HandleLeftButtonDown(POINT pt) {
    EnterCriticalSection(&g_lock);

    if (IsEligibleDesktopClickPointLocked(pt)) {
        g_leftButtonDownEligible = true;
        g_leftButtonDownPt = pt;
    } else {
        ResetClickStateLocked();
    }

    LeaveCriticalSection(&g_lock);
}

static void HandleLeftButtonUp(POINT pt) {
    EnterCriticalSection(&g_lock);

    bool eligible = g_leftButtonDownEligible &&
                    IsEligibleDesktopClickPointLocked(pt) &&
                    AbsInt(pt.x - g_leftButtonDownPt.x) <=
                        GetSystemMetrics(SM_CXDRAG) &&
                    AbsInt(pt.y - g_leftButtonDownPt.y) <=
                        GetSystemMetrics(SM_CYDRAG);

    g_leftButtonDownEligible = false;

    if (!eligible) {
        ResetClickStateLocked();
        LeaveCriticalSection(&g_lock);
        return;
    }

    if (IsSecondClickLocked(pt)) {
        ToggleDesktopIconsLocked();
    }

    LeaveCriticalSection(&g_lock);
}

static void HandleNonLeftMouseAction() {
    EnterCriticalSection(&g_lock);
    ResetClickStateLocked();
    LeaveCriticalSection(&g_lock);
}

static LRESULT CALLBACK MouseHookProc(int code, WPARAM wParam, LPARAM lParam) {
    if (code >= 0 && (wParam == WM_LBUTTONDOWN ||
                      wParam == WM_LBUTTONDBLCLK ||
                      wParam == WM_LBUTTONUP ||
                      wParam == WM_RBUTTONDOWN ||
                      wParam == WM_RBUTTONUP ||
                      wParam == WM_MBUTTONDOWN ||
                      wParam == WM_MBUTTONUP)) {
        MOUSEHOOKSTRUCT* mouse = reinterpret_cast<MOUSEHOOKSTRUCT*>(lParam);
        if (wParam == WM_LBUTTONDOWN || wParam == WM_LBUTTONDBLCLK) {
            HandleLeftButtonDown(mouse->pt);
        } else if (wParam == WM_LBUTTONUP) {
            HandleLeftButtonUp(mouse->pt);
        } else {
            HandleNonLeftMouseAction();
        }
    }

    return CallNextHookEx(g_mouseHook, code, wParam, lParam);
}

static void EnsureMouseHookLocked() {
    if (!RefreshDesktopWindowsLocked()) {
        return;
    }

    DWORD processId = 0;
    DWORD threadId = GetWindowThreadProcessId(g_defView, &processId);
    if (!threadId || processId != GetCurrentProcessId()) {
        return;
    }

    if (g_mouseHook && g_hookThreadId == threadId) {
        return;
    }

    if (g_mouseHook) {
        UnhookWindowsHookEx(g_mouseHook);
        g_mouseHook = nullptr;
        g_hookThreadId = 0;
    }

    g_mouseHook = SetWindowsHookExW(WH_MOUSE, MouseHookProc, nullptr, threadId);
    if (g_mouseHook) {
        g_hookThreadId = threadId;
        Wh_Log(L"Installed desktop mouse hook for thread %lu", threadId);
    } else {
        Wh_Log(L"Failed to install mouse hook, error %lu", GetLastError());
    }
}

static DWORD WINAPI WorkerThreadProc(LPVOID) {
    while (WaitForSingleObject(g_stopEvent, 1000) == WAIT_TIMEOUT) {
        EnterCriticalSection(&g_lock);

        if (g_mouseHook && (!IsWindow(g_defView) || !IsWindow(g_listView))) {
            UnhookWindowsHookEx(g_mouseHook);
            g_mouseHook = nullptr;
            g_hookThreadId = 0;
            g_defView = nullptr;
            g_listView = nullptr;
            ResetClickStateLocked();
        }

        EnsureMouseHookLocked();

        // 桌面窗口就绪后隐藏一次图标（登录 / Explorer 重启时生效）
        if (g_startupHidePending && RefreshDesktopWindowsLocked()) {
            if (!IsWindowVisible(g_listView)) {
                // 已经隐藏了，没什么可做
                g_startupHidePending = false;
            } else if (SetDesktopIconsVisibleLocked(false)) {
                g_startupHidePending = false;
                Wh_Log(L"Desktop icons hidden on startup");
            }
            // 被重命名保护拦下时保留 pending，1 秒后重试，
            // 避免「开机时正好在重命名」导致自动隐藏永久失效。
        }

        LeaveCriticalSection(&g_lock);
    }

    return 0;
}

BOOL Wh_ModInit() {
    InitializeCriticalSection(&g_lock);
    LoadSettings();
    g_startupHidePending = g_settings.hideIconsOnStartup;

    g_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!g_stopEvent) {
        Wh_Log(L"Failed to create stop event, error %lu", GetLastError());
        DeleteCriticalSection(&g_lock);
        return FALSE;
    }

    EnterCriticalSection(&g_lock);
    EnsureMouseHookLocked();
    LeaveCriticalSection(&g_lock);

    g_workerThread =
        CreateThread(nullptr, 0, WorkerThreadProc, nullptr, 0, nullptr);
    if (!g_workerThread) {
        Wh_Log(L"Failed to create worker thread, error %lu", GetLastError());
        if (g_mouseHook) {
            UnhookWindowsHookEx(g_mouseHook);
            g_mouseHook = nullptr;
            g_hookThreadId = 0;
        }
        CloseHandle(g_stopEvent);
        g_stopEvent = nullptr;
        DeleteCriticalSection(&g_lock);
        return FALSE;
    }

    return TRUE;
}

void Wh_ModUninit() {
    if (g_stopEvent) {
        SetEvent(g_stopEvent);
    }

    if (g_workerThread) {
        WaitForSingleObject(g_workerThread, INFINITE);
        CloseHandle(g_workerThread);
        g_workerThread = nullptr;
    }

    EnterCriticalSection(&g_lock);

    if (g_mouseHook) {
        UnhookWindowsHookEx(g_mouseHook);
        g_mouseHook = nullptr;
        g_hookThreadId = 0;
    }

    if (g_settings.restoreInitialStateOnUnload && g_modifiedVisibility &&
        g_haveInitialVisibility) {
        SetDesktopIconsVisibleLocked(g_initialIconsVisible,
                                    /* protectEditing = */ false);
    }

    LeaveCriticalSection(&g_lock);

    if (g_stopEvent) {
        CloseHandle(g_stopEvent);
        g_stopEvent = nullptr;
    }

    DeleteCriticalSection(&g_lock);
}

void Wh_ModSettingsChanged() {
    EnterCriticalSection(&g_lock);
    LoadSettings();
    ResetClickStateLocked();
    LeaveCriticalSection(&g_lock);
}
