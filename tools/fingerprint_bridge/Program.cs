using System.Diagnostics;
using System.Text.Json.Nodes;
using Microsoft.Win32;

namespace FingerprintBridge;

// The fingerprint bridge (Fernando, 2026-11-14): lives by the clock (tray)
// on the PC with the ZK9500, tells the app who put a finger and registers
// fingers when an administrator asks from that PC's browser.
internal static class Program
{
    [STAThread]
    private static void Main()
    {
        using var single = new Mutex(true, "FingerprintBridge.Single", out var first);
        if (!first) return;

        ApplicationConfiguration.Initialize();
        Application.Run(new TrayContext());
    }
}

internal sealed class TrayContext : ApplicationContext
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

    private readonly Settings _settings = Settings.Load();
    private readonly Reader _reader = new();
    private readonly NotifyIcon _icon;
    private readonly ToolStripMenuItem _status = new() { Enabled = false };
    private readonly ToolStripMenuItem _autostart = new("Iniciar con Windows") { CheckOnClick = true };
    private readonly SynchronizationContext _ui;
    private Server? _server;

    public TrayContext()
    {
        _ui = new WindowsFormsSynchronizationContext();

        var menu = new ContextMenuStrip();
        menu.Items.Add(_status);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Emparejar con el sistema…", null, (_, _) => ShowPairing());
        menu.Items.Add("Abrir el sistema", null, (_, _) => OpenApp());
        _autostart.Checked = AutostartEnabled();
        _autostart.CheckedChanged += (_, _) => SetAutostart(_autostart.Checked);
        menu.Items.Add(_autostart);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Salir", null, (_, _) => Exit());

        _icon = new NotifyIcon { Icon = SystemIcons.Shield, ContextMenuStrip = menu, Visible = true, Text = "Lector de huella" };
        _icon.DoubleClick += (_, _) => OpenApp();

        _reader.ConnectedChanged += connected =>
        {
            Perform("reader", new JsonObject { ["connected"] = connected });
            ShowStatus();
        };
        _reader.Identified += (fid, score) =>
            Perform("identified", new JsonObject { ["fid"] = fid is null ? null : JsonValue.Create(fid.Value), ["score"] = score });
        _reader.EnrollProgress += (requestId, step) =>
            Perform("enroll_progress", new JsonObject { ["request_id"] = requestId, ["step"] = step });
        _reader.Enrolled += (requestId, template, duplicate) =>
            Perform("enrolled", new JsonObject
            {
                ["request_id"] = requestId, ["template"] = template,
                ["duplicate_fid"] = duplicate is null ? null : JsonValue.Create(duplicate.Value)
            });
        _reader.EnrollFailed += (requestId, reason) =>
            Perform("enroll_failed", new JsonObject { ["request_id"] = requestId, ["reason"] = reason });
        _reader.Start();

        // The first time it opens it also starts with Windows.
        if (!_settings.Paired && !AutostartEnabled())
        {
            SetAutostart(true);
            _autostart.Checked = true;
        }
        if (_settings.Paired) StartServer();
        else ShowPairing();
        ShowStatus();
    }

    private void StartServer()
    {
        _server?.Dispose();
        _server = new Server(_settings);
        _server.ConnectedChanged += connected =>
        {
            if (connected) Perform("reader", new JsonObject { ["connected"] = _reader.IsConnected });
            ShowStatus();
        };
        _server.TemplatesChanged += () => _ = LoadTemplatesAsync();
        _server.EnrollAsked += (requestId, captures) => _reader.Enroll(new Reader.EnrollRequest(requestId, captures));
        _server.Start();
    }

    private async Task LoadTemplatesAsync()
    {
        try
        {
            if (_server is not null) _reader.LoadTemplates(await _server.TemplatesAsync());
        }
        catch (Exception error)
        {
            Settings.Log($"Huellas: {error.Message}");
        }
    }

    private void Perform(string action, JsonObject data)
    {
        var server = _server;
        if (server is null) return;

        _ = Task.Run(async () =>
        {
            try { await server.PerformAsync(action, data); }
            catch (Exception error) { Settings.Log($"{action}: {error.Message}"); }
        });
    }

    private void ShowStatus()
    {
        _ui.Post(_ =>
        {
            var system = !_settings.Paired ? "sin emparejar" : (_server?.IsConnected == true ? $"conectado a «{_settings.StationName}»" : "conectando…");
            var reader = _reader.IsConnected ? "lector listo" : "lector desconectado";
            _status.Text = $"Sistema: {system} · {reader}";
            var tip = $"Lector de huella: {reader}";
            _icon.Text = tip.Length > 63 ? tip[..63] : tip;
        }, null);
    }

    private void ShowPairing()
    {
        using var form = new PairingForm(_settings.ServerUrl);
        if (form.ShowDialog() != DialogResult.OK) return;

        _settings.ServerUrl = form.ServerUrl;
        _settings.Token = form.Token;
        _settings.StationName = form.StationName;
        _settings.Save();
        StartServer();
        ShowStatus();
        _icon.ShowBalloonTip(4000, "Lector de huella", $"Emparejado con «{form.StationName}».", ToolTipIcon.Info);
    }

    private void OpenApp()
    {
        if (_settings.ServerUrl.Length > 0) Process.Start(new ProcessStartInfo(_settings.ServerUrl) { UseShellExecute = true });
    }

    private static bool AutostartEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue("FingerprintBridge") is not null;
    }

    private static void SetAutostart(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey);
        if (enabled) key.SetValue("FingerprintBridge", $"\"{Application.ExecutablePath}\"");
        else key.DeleteValue("FingerprintBridge", false);
    }

    private void Exit()
    {
        _icon.Visible = false;
        _server?.Dispose();
        _reader.Dispose();
        ExitThread();
    }
}

// Pairing with the app: its address and the 6-number code of
// Administración → Lectores de huella.
internal sealed class PairingForm : Form
{
    private readonly TextBox _url = new() { Width = 320 };
    private readonly TextBox _code = new() { Width = 120, MaxLength = 7 };
    private readonly Button _pair = new() { Text = "Emparejar", AutoSize = true };
    private readonly Label _message = new() { AutoSize = true, MaximumSize = new Size(340, 0), ForeColor = Color.Firebrick };

    public string ServerUrl => _url.Text.Trim().TrimEnd('/');
    public string Token { get; private set; } = "";
    public string StationName { get; private set; } = "";

    public PairingForm(string serverUrl)
    {
        Text = "Emparejar el lector de huella";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        Padding = new Padding(16);
        _url.Text = serverUrl.Length > 0 ? serverUrl : "https://";

        var layout = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, WrapContents = false };
        layout.Controls.Add(new Label { Text = "Dirección del sistema", AutoSize = true });
        layout.Controls.Add(_url);
        layout.Controls.Add(new Label { Text = "Código (Administración → Lectores de huella)", AutoSize = true, Margin = new Padding(0, 10, 0, 0) });
        layout.Controls.Add(_code);
        layout.Controls.Add(_pair);
        layout.Controls.Add(_message);
        Controls.Add(layout);
        AcceptButton = _pair;
        _pair.Click += async (_, _) => await PairAsync();
    }

    private async Task PairAsync()
    {
        if (!Uri.TryCreate(ServerUrl, UriKind.Absolute, out var uri) || (uri.Scheme != "https" && uri.Host != "localhost"))
        {
            _message.Text = "Escribe la dirección completa, con https://";
            return;
        }

        _pair.Enabled = false;
        _message.Text = "Emparejando…";
        try
        {
            (Token, StationName) = await Server.PairAsync(ServerUrl, _code.Text);
            DialogResult = DialogResult.OK;
            Close();
        }
        catch (Exception)
        {
            _message.Text = "No se pudo emparejar. Revisa la dirección y que el código no haya vencido (pide uno nuevo).";
            _pair.Enabled = true;
        }
    }
}
