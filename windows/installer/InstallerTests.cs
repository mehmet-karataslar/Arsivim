using System;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Runtime.InteropServices;

internal static class InstallerTests
{
    private static int checks;
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr LoadLibrary(string path);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern bool SetDllDirectory(string path);
    [DllImport("kernel32.dll")]
    private static extern bool FreeLibrary(IntPtr module);
    private static void Assert(bool value, string name)
    {
        if (!value) throw new Exception(name);
        checks++;
        Console.WriteLine("PASS " + name);
    }
    private static MemoryStream Zip(string path)
    {
        var result = new MemoryStream();
        using (var zip = new ZipArchive(result, ZipArchiveMode.Create, true))
        using (var writer = new StreamWriter(zip.CreateEntry(path).Open())) writer.Write("test");
        result.Position = 0;
        return result;
    }
    private static void Reject(Action operation, string name)
    {
        bool rejected = false;
        try { operation(); } catch (IOException) { rejected = true; }
        Assert(rejected, name);
    }
    private static int Main(string[] args)
    {
        string root = Path.GetFullPath(args[1]);
        Directory.CreateDirectory(root);
        string target = Path.Combine(root, "Programs", "Arsivim");
        string sentinel = Path.Combine(root, "Documents", "arsiv.db");
        Directory.CreateDirectory(Path.GetDirectoryName(sentinel));
        File.WriteAllText(sentinel, "customer archive must survive");
        var assembly = Assembly.LoadFile(Path.GetFullPath(args[0]));
        using (var payload = assembly.GetManifestResourceStream("payload.zip"))
        using (var hash = SHA256.Create())
        using (var expected = new StreamReader(assembly.GetManifestResourceStream("payload.sha256")))
        {
            Assert(BitConverter.ToString(hash.ComputeHash(payload)).Replace("-", "").Equals(expected.ReadToEnd().Trim(), StringComparison.OrdinalIgnoreCase), "embedded payload digest");
        }
        Action install = () => {
            using (var payload = assembly.GetManifestResourceStream("payload.zip")) InstallerCore.Install(payload, target, "2.6.3");
        };
        install();
        Assert(File.Exists(Path.Combine(target, "arsiv_uygulamasi.exe")), "first install executable");
        foreach (string file in new[] { "sqlite3.dll", "vcruntime140.dll", "vcruntime140_1.dll", "msvcp140.dll", "flutter_windows.dll", "data/app.so" })
            Assert(File.Exists(Path.Combine(target, file)), "customer dependency " + file);
        File.WriteAllText(Path.Combine(target, "old-version-sentinel"), "old");
        install();
        Assert(!File.Exists(Path.Combine(target, "old-version-sentinel")), "replacement removes stale bundle files");
        Assert(File.Exists(Path.Combine(target + ".previous", "old-version-sentinel")), "previous bundle retained");
        Assert(File.ReadAllText(sentinel) == "customer archive must survive", "customer archive untouched");
        Reject(() => {
            using (var payload = assembly.GetManifestResourceStream("payload.zip")) InstallerCore.Install(payload, target, "2.6.2");
        }, "downgrade rejected");
        Assert(File.Exists(Path.Combine(target, "arsiv_uygulamasi.exe")), "downgrade preserves existing app");
        using (var bad = Zip("missing.txt")) Reject(() => InstallerCore.Install(bad, target, "2.6.3"), "incomplete package rejected");
        Assert(File.Exists(Path.Combine(target, "arsiv_uygulamasi.exe")), "incomplete package preserves app");
        foreach (string path in new[] { "../escaped.txt", "data/../../escaped.txt", "C:/escaped.txt", "data/test:stream", "data/../escaped.txt" })
        {
            using (var bad = Zip(path)) Reject(() => InstallerCore.Extract(bad, Path.Combine(root, "malformed")), "unsafe ZIP rejected: " + path);
        }
        string unknown = Path.Combine(root, "unknown");
        Directory.CreateDirectory(unknown);
        File.WriteAllText(Path.Combine(unknown, "important.txt"), "preserve");
        using (var payload = assembly.GetManifestResourceStream("payload.zip"))
            Reject(() => InstallerCore.Install(payload, unknown, "2.6.3"), "unknown installation directory rejected");
        Assert(File.ReadAllText(Path.Combine(unknown, "important.txt")) == "preserve", "unknown files preserved");
        Assert(Directory.GetDirectories(Path.Combine(root, "Programs"), ".arsivim-stage-*").Length == 0, "temporary staging cleaned");
        // Load from the installed bundle with no developer PATH directories.
        Environment.SetEnvironmentVariable("PATH", Environment.GetFolderPath(Environment.SpecialFolder.System));
        Assert(SetDllDirectory(target), "isolated native dependency search path");
        foreach (string dll in Directory.GetFiles(target, "*.dll"))
        {
            IntPtr module = LoadLibrary(dll);
            Assert(module != IntPtr.Zero, "native library loads: " + Path.GetFileName(dll) + " (error " + Marshal.GetLastWin32Error() + ")");
            FreeLibrary(module);
        }
        Console.WriteLine(checks + " checks passed.");
        return 0;
    }
}
