using System.Net.Http.Headers;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FingerprintBridge;

// The app: pairing (a one-time code for a token), the templates (HTTPS) and
// the live channel (Action Cable over a WebSocket, FingerprintBridgeChannel),
// reconnecting by itself.
internal sealed class Server : IDisposable
{
    private const string ChannelIdentifier = "{\"channel\":\"FingerprintBridgeChannel\"}";
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };

    public event Action<bool>? ConnectedChanged;
    public event Action<string, int>? EnrollAsked;
    public event Action? TemplatesChanged;

    private readonly Settings _settings;
    private readonly CancellationTokenSource _stop = new();
    private readonly SemaphoreSlim _sendLock = new(1, 1);
    private ClientWebSocket? _socket;
    private bool _connected;

    public Server(Settings settings) => _settings = settings;

    public static async Task<(string Token, string Station)> PairAsync(string serverUrl, string code)
    {
        var body = new StringContent(JsonSerializer.Serialize(new { code }), Encoding.UTF8, "application/json");
        using var response = await Http.PostAsync($"{serverUrl.TrimEnd('/')}/fingerprint_bridge/pairing", body);
        if (!response.IsSuccessStatusCode) throw new InvalidOperationException($"{(int)response.StatusCode}");

        var json = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
        return (json["token"]!.GetValue<string>(), json["station"]!.GetValue<string>());
    }

    // id -> template, every fingerprint of the app.
    public async Task<Dictionary<uint, byte[]>> TemplatesAsync()
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, $"{_settings.ServerUrl.TrimEnd('/')}/fingerprint_bridge/templates");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _settings.Token);
        using var response = await Http.SendAsync(request);
        response.EnsureSuccessStatusCode();

        var json = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
        var templates = new Dictionary<uint, byte[]>();
        foreach (var item in json["templates"]!.AsArray())
        {
            templates[item!["id"]!.GetValue<uint>()] = Convert.FromBase64String(item["template"]!.GetValue<string>());
        }
        return templates;
    }

    public void Start() => _ = Task.Run(RunAsync);

    private async Task RunAsync()
    {
        var wait = TimeSpan.FromSeconds(2);
        while (!_stop.IsCancellationRequested)
        {
            try
            {
                await ConnectAsync();
                wait = TimeSpan.FromSeconds(2);
                await ReceiveAsync();
            }
            catch (Exception error)
            {
                // A silent server (no pings for 30 s) cancels the read too: reconnect.
                if (_stop.IsCancellationRequested) return;
                Settings.Log($"Conexión: {error.Message}");
            }
            SetConnected(false);
            try { await Task.Delay(wait, _stop.Token); } catch (OperationCanceledException) { return; }
            wait = TimeSpan.FromSeconds(Math.Min(wait.TotalSeconds * 2, 60));
        }
    }

    private async Task ConnectAsync()
    {
        var baseUri = new Uri(_settings.ServerUrl.TrimEnd('/'));
        var cable = new UriBuilder(baseUri) { Scheme = baseUri.Scheme == "https" ? "wss" : "ws", Path = "/cable" }.Uri;
        _socket?.Dispose();
        _socket = new ClientWebSocket();
        _socket.Options.SetRequestHeader("Authorization", $"Bearer {_settings.Token}");
        _socket.Options.SetRequestHeader("Origin", $"{baseUri.Scheme}://{baseUri.Authority}");
        _socket.Options.AddSubProtocol("actioncable-v1-json");
        _socket.Options.KeepAliveInterval = TimeSpan.FromSeconds(20);
        await _socket.ConnectAsync(cable, _stop.Token);
    }

    private async Task ReceiveAsync()
    {
        var buffer = new byte[64 * 1024];
        while (_socket!.State == WebSocketState.Open && !_stop.IsCancellationRequested)
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(_stop.Token);
            timeout.CancelAfter(TimeSpan.FromSeconds(30)); // the server pings every 3 seconds
            using var message = new MemoryStream();
            WebSocketReceiveResult result;
            do
            {
                result = await _socket.ReceiveAsync(new ArraySegment<byte>(buffer), timeout.Token);
                if (result.MessageType == WebSocketMessageType.Close) return;
                message.Write(buffer, 0, result.Count);
            } while (!result.EndOfMessage);

            await HandleAsync(JsonNode.Parse(Encoding.UTF8.GetString(message.ToArray())));
        }
    }

    private async Task HandleAsync(JsonNode? json)
    {
        switch (json?["type"]?.GetValue<string>())
        {
            case "welcome":
                await SendRawAsync(new JsonObject { ["command"] = "subscribe", ["identifier"] = ChannelIdentifier });
                return;
            case "confirm_subscription":
                SetConnected(true);
                TemplatesChanged?.Invoke();
                return;
            case "reject_subscription":
                Settings.Log("El sistema rechazó el lector: empareja de nuevo.");
                SetConnected(false);
                return;
            case "ping":
                return;
            case "disconnect":
                Settings.Log($"El sistema cerró la conexión: {json?["reason"]}");
                await _socket!.CloseAsync(WebSocketCloseStatus.NormalClosure, "", CancellationToken.None);
                return;
        }

        var payload = json?["message"];
        switch (payload?["type"]?.GetValue<string>())
        {
            case "enroll":
                EnrollAsked?.Invoke(payload["request_id"]!.GetValue<string>(), payload["captures"]?.GetValue<int>() ?? 3);
                break;
            case "templates_changed":
                TemplatesChanged?.Invoke();
                break;
        }
    }

    // An action of FingerprintBridgeChannel: identified, reader, enroll_progress, enrolled, enroll_failed.
    public async Task PerformAsync(string action, JsonObject data)
    {
        if (!_connected) return;

        data["action"] = action;
        await SendRawAsync(new JsonObject
        {
            ["command"] = "message", ["identifier"] = ChannelIdentifier, ["data"] = data.ToJsonString()
        });
    }

    private async Task SendRawAsync(JsonObject message)
    {
        var bytes = Encoding.UTF8.GetBytes(message.ToJsonString());
        await _sendLock.WaitAsync();
        try
        {
            if (_socket?.State == WebSocketState.Open) await _socket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, _stop.Token);
        }
        finally
        {
            _sendLock.Release();
        }
    }

    private void SetConnected(bool connected)
    {
        if (_connected == connected) return;
        _connected = connected;
        ConnectedChanged?.Invoke(connected);
    }

    public bool IsConnected => _connected;

    public void Dispose()
    {
        _stop.Cancel();
        _socket?.Dispose();
    }
}
