using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace FingerprintBridge;

// Where this PC's bridge connects and its station's token, in
// %APPDATA%\FingerprintBridge\settings.json; the token is protected with
// Windows (DPAPI, this Windows user only).
internal sealed class Settings
{
    public string ServerUrl { get; set; } = "";
    public string StationName { get; set; } = "";
    public string ProtectedToken { get; set; } = "";

    private static string Folder => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "FingerprintBridge");
    private static string FilePath => Path.Combine(Folder, "settings.json");

    public bool Paired => ServerUrl.Length > 0 && ProtectedToken.Length > 0;

    public string Token
    {
        get => ProtectedToken.Length == 0 ? "" :
            Encoding.UTF8.GetString(ProtectedData.Unprotect(Convert.FromBase64String(ProtectedToken), null, DataProtectionScope.CurrentUser));
        set => ProtectedToken = Convert.ToBase64String(ProtectedData.Protect(Encoding.UTF8.GetBytes(value), null, DataProtectionScope.CurrentUser));
    }

    public static Settings Load()
    {
        try
        {
            return File.Exists(FilePath) ? JsonSerializer.Deserialize<Settings>(File.ReadAllText(FilePath)) ?? new Settings() : new Settings();
        }
        catch (Exception)
        {
            return new Settings();
        }
    }

    public void Save()
    {
        Directory.CreateDirectory(Folder);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
    }

    public static void Log(string message)
    {
        try
        {
            Directory.CreateDirectory(Folder);
            File.AppendAllText(Path.Combine(Folder, "bridge.log"), $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} {message}{Environment.NewLine}");
        }
        catch (Exception)
        {
            // A log that cannot be written never stops the bridge.
        }
    }
}
