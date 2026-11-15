using System.Collections.Concurrent;

namespace FingerprintBridge;

// The ZK9500 on its own thread (every SDK call happens here). It identifies
// each finger put on it among the templates the app sent (1:N, in the
// reader's memory) and, when the app asks, registers a finger: three
// captures of the same finger, merged into one template.
internal sealed class Reader : IDisposable
{
    public sealed record EnrollRequest(string RequestId, int Captures);

    // What the reader tells the bridge.
    public event Action<bool>? ConnectedChanged;
    public event Action<uint?, uint>? Identified;
    public event Action<string, int>? EnrollProgress;
    public event Action<string, string, uint?>? Enrolled;
    public event Action<string, string>? EnrollFailed;

    private static readonly TimeSpan CaptureTimeout = TimeSpan.FromSeconds(60);
    private static readonly TimeSpan AfterFinger = TimeSpan.FromMilliseconds(1500);

    private readonly ConcurrentQueue<EnrollRequest> _enrollments = new();
    private readonly CancellationTokenSource _stop = new();
    private Dictionary<uint, byte[]>? _pendingTemplates;
    private readonly object _templatesLock = new();
    private Thread? _thread;
    private IntPtr _device = IntPtr.Zero;
    private IntPtr _cache = IntPtr.Zero;
    private byte[] _image = Array.Empty<byte>();
    private bool _connected;

    public void Start()
    {
        _thread = new Thread(Run) { IsBackground = true, Name = "ZK9500" };
        _thread.Start();
    }

    // The templates to identify with (id -> template), loaded on the reader's thread.
    public void LoadTemplates(Dictionary<uint, byte[]> templates)
    {
        lock (_templatesLock) _pendingTemplates = templates;
    }

    public void Enroll(EnrollRequest request) => _enrollments.Enqueue(request);

    private Dictionary<uint, byte[]> _templates = new();

    private void Run()
    {
        try
        {
            var init = ZkFinger.ZKFPM_Init();
            if (init != ZkFinger.Ok && init != ZkFinger.AlreadyInit)
            {
                Settings.Log($"ZKFPM_Init: {init}");
            }

            while (!_stop.IsCancellationRequested)
            {
                if (!EnsureOpen())
                {
                    Thread.Sleep(2000);
                    continue;
                }

                ApplyTemplates();

                if (_enrollments.TryDequeue(out var request))
                {
                    RunEnrollment(request);
                    continue;
                }

                var template = Capture(TimeSpan.FromMilliseconds(250));
                if (template is null) continue;

                uint fid = 0, score = 0;
                var found = _templates.Count > 0 &&
                            ZkFinger.ZKFPM_DBIdentify(_cache, template, (uint)template.Length, ref fid, ref score) == ZkFinger.Ok;
                Identified?.Invoke(found ? fid : null, score);
                Thread.Sleep(AfterFinger);
            }
        }
        catch (DllNotFoundException error)
        {
            Settings.Log($"No se encontró libzkfp.dll (instala el ZKFinger SDK): {error.Message}");
            SetConnected(false);
        }
        finally
        {
            Close();
            ZkFinger.ZKFPM_Terminate();
        }
    }

    private bool EnsureOpen()
    {
        if (_device != IntPtr.Zero)
        {
            if (ZkFinger.ZKFPM_GetDeviceCount() > 0) return true;
            Close();
        }

        if (ZkFinger.ZKFPM_GetDeviceCount() <= 0)
        {
            SetConnected(false);
            return false;
        }

        _device = ZkFinger.ZKFPM_OpenDevice(0);
        if (_device == IntPtr.Zero)
        {
            SetConnected(false);
            return false;
        }

        _image = new byte[ImageSize()];
        _cache = ZkFinger.ZKFPM_DBInit();
        lock (_templatesLock) _pendingTemplates ??= new Dictionary<uint, byte[]>(_templates);
        SetConnected(true);
        return true;
    }

    private uint ImageSize()
    {
        var value = new byte[4];
        uint size = 4;
        ZkFinger.ZKFPM_GetParameters(_device, ZkFinger.ParamWidth, value, ref size);
        var width = BitConverter.ToInt32(value, 0);
        size = 4;
        ZkFinger.ZKFPM_GetParameters(_device, ZkFinger.ParamHeight, value, ref size);
        var height = BitConverter.ToInt32(value, 0);
        return width > 0 && height > 0 ? (uint)(width * height) : 512 * 512;
    }

    private void ApplyTemplates()
    {
        Dictionary<uint, byte[]>? templates;
        lock (_templatesLock)
        {
            templates = _pendingTemplates;
            _pendingTemplates = null;
        }
        if (templates is null || _cache == IntPtr.Zero) return;

        ZkFinger.ZKFPM_DBClear(_cache);
        foreach (var (fid, template) in templates)
        {
            var result = ZkFinger.ZKFPM_DBAdd(_cache, fid, template, (uint)template.Length);
            if (result != ZkFinger.Ok) Settings.Log($"DBAdd {fid}: {result}");
        }
        _templates = templates;
        Settings.Log($"Huellas cargadas: {templates.Count}");
    }

    // A template from the next finger put on the reader, or null after `wait`.
    private byte[]? Capture(TimeSpan wait)
    {
        var until = DateTime.UtcNow + wait;
        var template = new byte[ZkFinger.MaxTemplateSize];
        while (DateTime.UtcNow < until && !_stop.IsCancellationRequested)
        {
            uint size = ZkFinger.MaxTemplateSize;
            var result = ZkFinger.ZKFPM_AcquireFingerprint(_device, _image, (uint)_image.Length, template, ref size);
            if (result == ZkFinger.Ok && size > 0) return template[..(int)size];
            if (result != ZkFinger.ErrCapture && ZkFinger.ZKFPM_GetDeviceCount() <= 0) return null;
            Thread.Sleep(100);
        }
        return null;
    }

    private void RunEnrollment(EnrollRequest request)
    {
        var captures = new List<byte[]>();
        uint? duplicate = null;
        // The SDK merges exactly three captures.
        for (var step = 0; step < 3; step++)
        {
            var template = Capture(CaptureTimeout);
            if (template is null)
            {
                EnrollFailed?.Invoke(request.RequestId, _device == IntPtr.Zero || ZkFinger.ZKFPM_GetDeviceCount() <= 0 ? "no_reader" : "timeout");
                return;
            }

            if (captures.Count > 0 &&
                ZkFinger.ZKFPM_DBMatch(_cache, captures[^1], (uint)captures[^1].Length, template, (uint)template.Length) <= 0)
            {
                EnrollFailed?.Invoke(request.RequestId, "mismatch");
                return;
            }

            if (captures.Count == 0 && _templates.Count > 0)
            {
                uint fid = 0, score = 0;
                if (ZkFinger.ZKFPM_DBIdentify(_cache, template, (uint)template.Length, ref fid, ref score) == ZkFinger.Ok) duplicate = fid;
            }

            captures.Add(template);
            EnrollProgress?.Invoke(request.RequestId, captures.Count);
            Thread.Sleep(AfterFinger);
        }

        var merged = new byte[ZkFinger.MaxTemplateSize];
        uint mergedSize = ZkFinger.MaxTemplateSize;
        if (ZkFinger.ZKFPM_DBMerge(_cache, captures[0], captures[1], captures[2], merged, ref mergedSize) != ZkFinger.Ok || mergedSize == 0)
        {
            EnrollFailed?.Invoke(request.RequestId, "merge");
            return;
        }

        Enrolled?.Invoke(request.RequestId, Convert.ToBase64String(merged, 0, (int)mergedSize), duplicate);
    }

    private void SetConnected(bool connected)
    {
        if (_connected == connected) return;
        _connected = connected;
        ConnectedChanged?.Invoke(connected);
    }

    private void Close()
    {
        if (_cache != IntPtr.Zero) ZkFinger.ZKFPM_DBFree(_cache);
        if (_device != IntPtr.Zero) ZkFinger.ZKFPM_CloseDevice(_device);
        _cache = IntPtr.Zero;
        _device = IntPtr.Zero;
        SetConnected(false);
    }

    public bool IsConnected => _connected;

    public void Dispose()
    {
        _stop.Cancel();
        _thread?.Join(TimeSpan.FromSeconds(3));
    }
}
