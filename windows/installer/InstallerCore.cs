using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;

// No archive/database migration here. Only the fixed per-user program bundle.
public static class InstallerCore
{
    public static void Install(Stream payload, string target, string version)
    {
        target = Path.GetFullPath(target).TrimEnd(Path.DirectorySeparatorChar);
        string parent = Path.GetDirectoryName(target);
        if (String.IsNullOrEmpty(parent) || Path.GetPathRoot(target) == target)
            throw new IOException("Geçersiz kurulum klasörü.");
        CheckParents(target);
        Directory.CreateDirectory(parent);
        string stage = Path.Combine(parent, ".arsivim-stage-" + Guid.NewGuid().ToString("N"));
        string backup = target + ".previous";
        bool movedOld = false;
        bool committed = false;
        try
        {
            Directory.CreateDirectory(stage);
            Extract(payload, stage);
            foreach (string required in new[] { "arsiv_uygulamasi.exe", "flutter_windows.dll", "data/app.so", "data/icudtl.dat" })
                if (!File.Exists(Path.Combine(stage, required)))
                    throw new IOException("Kurulum paketi eksik: " + required);
            if (!Directory.Exists(Path.Combine(stage, "data/flutter_assets")))
                throw new IOException("Uygulama kaynakları eksik.");
            File.WriteAllText(Path.Combine(stage, ".arsivim-bundle"), "Arsivim installer 1");

            string previousExe = Path.Combine(target, "arsiv_uygulamasi.exe");
            if (Directory.Exists(target))
            {
                CheckOwnedBundle(target);
                if (!File.Exists(previousExe))
                    throw new IOException("Kurulum konumunda tanınmayan bir klasör var: " + target);
                Version previousVersion;
                string previous = FileVersionInfo.GetVersionInfo(previousExe).ProductVersion ?? "";
                if (!Version.TryParse(previous.Split('+')[0], out previousVersion))
                    throw new IOException("Mevcut uygulamanın sürümü okunamadı; dosyalar değiştirilmedi.");
                if (previousVersion > new Version(version))
                    throw new IOException("Bilgisayarda daha yeni bir sürüm kurulu.");
                CheckTree(target);
            }
            // Remove only our known previous program backup; never arbitrary paths.
            if (Directory.Exists(backup))
            {
                CheckOwnedBundle(backup);
                CheckTree(backup);
                Directory.Delete(backup, true);
            }
            if (Directory.Exists(target))
            {
                Directory.Move(target, backup);
                movedOld = true;
            }
            try
            {
                Directory.Move(stage, target);
                committed = true;
            }
            catch
            {
                if (movedOld && !Directory.Exists(target)) Directory.Move(backup, target);
                throw;
            }
        }
        finally
        {
            if (!committed && Directory.Exists(stage))
            {
                try { CheckTree(stage); Directory.Delete(stage, true); } catch { }
            }
        }
    }

    public static void Extract(Stream payload, string stage)
    {
        string prefix = Path.GetFullPath(stage).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        long total = 0;
        using (var archive = new ZipArchive(payload, ZipArchiveMode.Read, true))
        {
            foreach (var entry in archive.Entries)
            {
                string name = entry.FullName.Replace('/', Path.DirectorySeparatorChar);
                // Reject alternate data streams, absolute/traversing paths, symlinks
                // and Windows path aliases before writing anything outside staging.
                if (name.Contains(":") || Path.IsPathRooted(name) ||
                    ((entry.ExternalAttributes >> 16) & 0xF000) == 0xA000)
                    throw new IOException("Geçersiz paket yolu.");
                foreach (string component in name.Split(Path.DirectorySeparatorChar))
                    if (component == ".." || component == "." || component.EndsWith(".") || component.EndsWith(" "))
                        throw new IOException("Geçersiz paket yolu.");
                string destination = Path.GetFullPath(Path.Combine(stage, name));
                if (!destination.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) || !names.Add(destination))
                    throw new IOException("Yinelenen veya geçersiz paket yolu.");
                if (name.EndsWith(Path.DirectorySeparatorChar.ToString()))
                {
                    Directory.CreateDirectory(destination);
                    continue;
                }
                total = checked(total + entry.Length);
                if (total > 2L * 1024 * 1024 * 1024) throw new IOException("Paket boyutu sınırı aşıldı.");
                Directory.CreateDirectory(Path.GetDirectoryName(destination));
                using (var input = entry.Open())
                using (var output = new FileStream(destination, FileMode.CreateNew, FileAccess.Write))
                {
                    var buffer = new byte[81920];
                    long written = 0;
                    int count;
                    while ((count = input.Read(buffer, 0, buffer.Length)) > 0)
                    {
                        written += count;
                        if (written > entry.Length) throw new IOException("Paket boyutu uyuşmuyor.");
                        output.Write(buffer, 0, count);
                    }
                    if (written != entry.Length) throw new IOException("Paket eksik indirildi.");
                    output.Flush(true);
                }
            }
        }
    }

    private static void CheckParents(string path)
    {
        for (var directory = new DirectoryInfo(path); directory != null; directory = directory.Parent)
            if (directory.Exists && (directory.Attributes & FileAttributes.ReparsePoint) != 0)
                throw new IOException("Kurulum klasörü bir bağlantı olamaz: " + directory.FullName);
    }

    private static void CheckOwnedBundle(string path)
    {
        string marker = Path.Combine(path, ".arsivim-bundle");
        if (!File.Exists(marker) || File.ReadAllText(marker) != "Arsivim installer 1")
            throw new IOException("Kurulum konumunda tanınmayan dosyalar var; korunmaları için işlem durduruldu: " + path);
    }

    private static void CheckTree(string path)
    {
        CheckParents(path);
        foreach (var entry in new DirectoryInfo(path).EnumerateFileSystemInfos())
        {
            if ((entry.Attributes & FileAttributes.ReparsePoint) != 0)
                throw new IOException("Kurulum klasöründe beklenmeyen bir bağlantı var.");
            if ((entry.Attributes & FileAttributes.Directory) != 0) CheckTree(entry.FullName);
        }
    }
}
