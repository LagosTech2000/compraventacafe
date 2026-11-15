using System.Runtime.InteropServices;

namespace FingerprintBridge;

// The C API of the ZKFinger SDK 5.x (c/libs/include/libzkfp.h), stdcall.
// 0 is success; the errors are in libzkfperrdef.h.
internal static class ZkFinger
{
    private const string Dll = "libzkfp.dll";

    public const int Ok = 0;
    public const int AlreadyInit = 1;
    public const int ErrCapture = -8;
    public const int MaxTemplateSize = 2048;
    public const int ParamWidth = 1;
    public const int ParamHeight = 2;

    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)] public static extern int ZKFPM_Init();
    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)] public static extern int ZKFPM_Terminate();
    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)] public static extern int ZKFPM_GetDeviceCount();
    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)] public static extern IntPtr ZKFPM_OpenDevice(int index);
    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)] public static extern int ZKFPM_CloseDevice(IntPtr device);

    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)]
    public static extern int ZKFPM_GetParameters(IntPtr device, int code, byte[] value, ref uint size);

    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)]
    public static extern int ZKFPM_AcquireFingerprint(IntPtr device, byte[] image, uint imageSize, byte[] template, ref uint templateSize);

    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)] public static extern IntPtr ZKFPM_DBInit();
    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)] public static extern int ZKFPM_DBFree(IntPtr cache);
    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)] public static extern int ZKFPM_DBClear(IntPtr cache);

    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)]
    public static extern int ZKFPM_DBAdd(IntPtr cache, uint fid, byte[] template, uint size);

    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)]
    public static extern int ZKFPM_DBMerge(IntPtr cache, byte[] t1, byte[] t2, byte[] t3, byte[] merged, ref uint mergedSize);

    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)]
    public static extern int ZKFPM_DBIdentify(IntPtr cache, byte[] template, uint size, ref uint fid, ref uint score);

    [DllImport(Dll, CallingConvention = CallingConvention.StdCall)]
    public static extern int ZKFPM_DBMatch(IntPtr cache, byte[] t1, uint size1, byte[] t2, uint size2);
}
