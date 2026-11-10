# Enumerates the real "New" submenu of the desktop background context menu
# by going through IShellFolder -> IShellView -> IContextMenu (no UI needed).
# Usage: powershell.exe -NoProfile -STA -File dump-new-menu.ps1   (Windows PowerShell / STA)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class NewMenuDump
{
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    static extern int SHGetDesktopFolder(out IShellFolder psf);

    [DllImport("user32.dll")] static extern IntPtr CreatePopupMenu();
    [DllImport("user32.dll")] static extern bool DestroyMenu(IntPtr h);
    [DllImport("user32.dll")] static extern int GetMenuItemCount(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int GetMenuString(IntPtr h, uint item, StringBuilder s, int max, uint flags);
    [DllImport("user32.dll")] static extern IntPtr GetSubMenu(IntPtr h, int pos);

    const uint MF_BYPOSITION = 0x400;

    [StructLayout(LayoutKind.Sequential)]
    public struct MENUITEMINFO
    {
        public uint cbSize; public uint fMask; public uint fType; public uint fState;
        public uint wID; public IntPtr hSubMenu; public IntPtr hbmpChecked; public IntPtr hbmpUnchecked;
        public IntPtr dwItemData; public IntPtr dwTypeData; public uint cch; public IntPtr hbmpItem;
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool GetMenuItemInfo(IntPtr h, uint item, bool byPos, ref MENUITEMINFO mii);
    [DllImport("user32.dll")] static extern IntPtr GetShellWindow();
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern int TrackPopupMenuEx(IntPtr hMenu, uint flags, int x, int y, IntPtr hwnd, IntPtr lptpm);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr CreateWindowEx(uint ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr inst, IntPtr param);

    [ComImport, Guid("000214E6-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IShellFolder
    {
        [PreserveSig] int ParseDisplayName(IntPtr hwnd, IntPtr pbc, [MarshalAs(UnmanagedType.LPWStr)] string name, out uint eaten, out IntPtr pidl, ref uint attrs);
        [PreserveSig] int EnumObjects(IntPtr hwnd, uint flags, out IntPtr enumIdList);
        [PreserveSig] int BindToObject(IntPtr pidl, IntPtr pbc, ref Guid riid, out IntPtr ppv);
        [PreserveSig] int BindToStorage(IntPtr pidl, IntPtr pbc, ref Guid riid, out IntPtr ppv);
        [PreserveSig] int CompareIDs(IntPtr lParam, IntPtr pidl1, IntPtr pidl2);
        [PreserveSig] int CreateViewObject(IntPtr hwndOwner, ref Guid riid, out IntPtr ppv);
        [PreserveSig] int GetAttributesOf(uint cidl, IntPtr apidl, ref uint rgfInOut);
        [PreserveSig] int GetDisplayNameOf(IntPtr pidl, uint uFlags, IntPtr lpName);
        [PreserveSig] int SetNameOf(IntPtr hwnd, IntPtr pidl, [MarshalAs(UnmanagedType.LPWStr)] string name, uint uFlags, out IntPtr pidlOut);
    }

    [ComImport, Guid("000214E3-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IShellView
    {
        // IShellView derives from IOleWindow: two methods first, otherwise the vtable is off by two
        [PreserveSig] int GetWindow(out IntPtr hwnd);
        [PreserveSig] int ContextSensitiveHelp(bool fEnterMode);
        [PreserveSig] int TranslateAccelerator(IntPtr pmsg);
        [PreserveSig] int EnableModeless(bool enable);
        [PreserveSig] int UIActivate(uint state);
        [PreserveSig] int Refresh();
        [PreserveSig] int CreateViewWindow(IntPtr prev, IntPtr fs, IntPtr viewSite, IntPtr rect, IntPtr hwnd);
        [PreserveSig] int DestroyViewWindow();
        [PreserveSig] int GetCurrentInfo(out IntPtr fs);
        [PreserveSig] int AddPropertySheetPages(uint reserved, IntPtr lpfnAddPage, IntPtr lParam);
        [PreserveSig] int SaveViewState();
        [PreserveSig] int SelectItem(IntPtr pidl, uint flags);
        [PreserveSig] int GetItemObject(uint uItem, ref Guid riid, out IntPtr ppv);
    }

    [ComImport, Guid("000214E4-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IContextMenu
    {
        [PreserveSig] int QueryContextMenu(IntPtr hmenu, uint indexMenu, int idCmdFirst, int idCmdLast, uint uFlags);
        [PreserveSig] int InvokeCommand(IntPtr pici);
        [PreserveSig] int GetCommandString(int idCmd, uint uType, IntPtr reserved, StringBuilder name, int cchMax);
    }

    [ComImport, Guid("000214F4-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IContextMenu3
    {
        [PreserveSig] int QueryContextMenu(IntPtr hmenu, uint indexMenu, int idCmdFirst, int idCmdLast, uint uFlags);
        [PreserveSig] int InvokeCommand(IntPtr pici);
        [PreserveSig] int GetCommandString(int idCmd, uint uType, IntPtr reserved, StringBuilder name, int cchMax);
        [PreserveSig] int HandleMenuMsg(uint uMsg, IntPtr wParam, IntPtr lParam);
        [PreserveSig] int HandleMenuMsg2(uint uMsg, IntPtr wParam, IntPtr lParam, out IntPtr plResult);
    }

    static string Dump(IntPtr hMenu, int depth, StringBuilder sb)
    {
        int n = GetMenuItemCount(hMenu);
        for (int i = 0; i < n; i++)
        {
            var s = new StringBuilder(512);
            GetMenuString(hMenu, (uint)i, s, 512, MF_BYPOSITION);
            string text = s.ToString();
            IntPtr sub = GetSubMenu(hMenu, i);
            var mii = new MENUITEMINFO();
            mii.cbSize = (uint)Marshal.SizeOf(typeof(MENUITEMINFO));
            mii.fMask = 0x2; // MIIM_ID
            GetMenuItemInfo(hMenu, (uint)i, true, ref mii);
            sb.AppendLine(new string(' ', depth * 2) + "- [" + mii.wID + "] " + text + (sub != IntPtr.Zero ? "  >" : ""));
            if (sub != IntPtr.Zero && depth < 3) Dump(sub, depth + 1, sb);
        }
        return sb.ToString();
    }

    public static string Run()
    {
        var sb = new StringBuilder();
        IShellFolder desktop;
        int hr = SHGetDesktopFolder(out desktop);
        if (hr != 0) return "SHGetDesktopFolder hr=0x" + hr.ToString("X8");

        Guid iidView = Marshal.GenerateGuidForType(typeof(IShellView));
        IntPtr psv;
        hr = desktop.CreateViewObject(IntPtr.Zero, ref iidView, out psv);
        if (hr != 0) return "CreateViewObject hr=0x" + hr.ToString("X8");

        var view = (IShellView)Marshal.GetObjectForIUnknown(psv);
        Guid iidCm = Marshal.GenerateGuidForType(typeof(IContextMenu));
        IntPtr pcm;
        hr = view.GetItemObject(0 /* SVGIO_BACKGROUND */, ref iidCm, out pcm);
        if (hr != 0) return "GetItemObject hr=0x" + hr.ToString("X8");

        var cm = (IContextMenu)Marshal.GetObjectForIUnknown(pcm);
        IntPtr h = CreatePopupMenu();
        hr = cm.QueryContextMenu(h, 0, 1, 0x7FFF, 0x4 /* CMF_EXPLORE */);
        sb.AppendLine("QueryContextMenu hr=0x" + hr.ToString("X8"));
        sb.AppendLine("apartment: " + System.Threading.Thread.CurrentThread.GetApartmentState());

        // shell32 builds the "New" submenu lazily: it is only populated while the menu is
        // actually being shown (the owner forwards WM_INITMENUPOPUP to IContextMenu2/3).
        var cm3 = cm as IContextMenu3;
        IntPtr shell = GetShellWindow();
        int nTop = GetMenuItemCount(h);
        for (int i = 0; i < nTop; i++)
        {
            IntPtr sub = GetSubMenu(h, i);
            if (sub == IntPtr.Zero) continue;
            IntPtr res;
            int a = cm3.HandleMenuMsg2(0x117, sub, (IntPtr)i, out res);
            int b = cm3.HandleMenuMsg(0x117, sub, (IntPtr)i);
            SendMessage(shell, 0x117, h, (IntPtr)i);
            sb.AppendLine(string.Format("init#{0} hm2=0x{1:X8} hm=0x{2:X8} items={3}", i, a, b, GetMenuItemCount(sub)));
        }

        // Last resort: actually show the menu far away from the cursor and cancel it right away.
        // This is what makes shell32 populate the submenu for real.
        if (GetMenuItemCount(GetSubMenu(h, 14)) <= 1)
        {
            IntPtr wnd = CreateWindowEx(0, "STATIC", "", 0, 0, 0, 1, 1, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
            var t = new System.Threading.Thread(() => { System.Threading.Thread.Sleep(150); PostMessage(wnd, 0x001F /* WM_CANCELMODE */, IntPtr.Zero, IntPtr.Zero); });
            t.IsBackground = true;
            t.Start();
            TrackPopupMenuEx(h, 0x0100 /* TPM_RETURNCMD */, 2000, 1200, wnd, IntPtr.Zero);
            t.Join(2000);
            sb.AppendLine("after TrackPopupMenu test, New submenu items=" + GetMenuItemCount(GetSubMenu(h, 14)));
        }

        sb.AppendLine("--- menu tree ---");
        Dump(h, 0, sb);
        DestroyMenu(h);
        return sb.ToString();
    }
}
'@

$out = [NewMenuDump]::Run()
$file = Join-Path $env:TEMP 'newmenu-dump.txt'
[System.IO.File]::WriteAllText($file, $out, [System.Text.Encoding]::UTF8)
Write-Host ("written to " + $file)
