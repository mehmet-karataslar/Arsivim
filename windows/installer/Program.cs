using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

internal sealed class InstallerWindow : Form
{
    private readonly Label status = new Label();
    private readonly Button install = new Button();
    private readonly ProgressBar progress = new ProgressBar();
    private readonly string target = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Arsivim");
    private bool working;
    private bool installed;
    private readonly string version = Assembly.GetExecutingAssembly().GetName().Version.ToString(3);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindow(string className, string windowName);

    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new InstallerWindow());
    }

    private InstallerWindow()
    {
        Text = "Arşivim kurulumu — " + version;
        ClientSize = new Size(540, 260);
        MinimumSize = new Size(500, 290);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 10);
        MaximizeBox = false;
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(24), RowCount = 3, ColumnCount = 1 };
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
        status.Dock = DockStyle.Fill;
        status.Text = "Arşivim " + version + " kurulmaya hazır.\n\nAçık işlemlerinizi kaydedin, aktarımları tamamlayın ve Arşivim'i kapatın. Belgeleriniz ve hesap bilgileriniz korunur.";
        progress.Dock = DockStyle.Fill;
        progress.Visible = false;
        progress.Style = ProgressBarStyle.Marquee;
        install.Text = "Kur / Güncelle";
        install.AutoSize = true;
        install.Anchor = AnchorStyles.Right | AnchorStyles.Bottom;
        install.Padding = new Padding(12, 4, 12, 4);
        install.Click += OnInstall;
        layout.Controls.Add(status, 0, 0);
        layout.Controls.Add(progress, 0, 1);
        layout.Controls.Add(install, 0, 2);
        Controls.Add(layout);
        FormClosing += (sender, args) => { if (working) args.Cancel = true; };
    }

    private async void OnInstall(object sender, EventArgs args)
    {
        if (installed)
        {
            try
            {
                Process.Start(new ProcessStartInfo(Path.Combine(target, "arsiv_uygulamasi.exe")) { WorkingDirectory = target, UseShellExecute = true });
                Close();
            }
            catch (Exception e) { status.Text = "Uygulama açılamadı: " + e.Message; }
            return;
        }
        working = true;
        install.Enabled = false;
        progress.Visible = true;
        status.Text = "Paket doğrulanıyor ve uygulama dosyaları hazırlanıyor…";
        try
        {
            string shortcutWarning = await Task.Run(() => InstallBundle());
            installed = true;
            install.Text = "Arşivim'i aç";
            status.Text = "Arşivim " + version + " kuruldu. Arşiviniz kullanıma hazır.\n\n" + shortcutWarning;
        }
        catch (Exception e)
        {
            status.Text = "Kurulum tamamlanamadı.\n\n" + e.Message + "\n\nSorunu giderip yeniden deneyin.";
        }
        finally
        {
            working = false;
            install.Enabled = true;
            progress.Visible = false;
        }
    }

    private string InstallBundle()
    {
        // Matches the Flutter runner. Holding this named object prevents the app
        // and other installers from starting while its directory is replaced.
        bool created;
        using (var mutex = new Mutex(false, @"Local\Arsivim.Archive.Instance", out created))
        {
            if (!created || FindWindow("FLUTTER_RUNNER_WIN32_WINDOW", "arsiv_uygulamasi") != IntPtr.Zero)
                throw new IOException("Arşivim açık. Uygulamayı kapatın ve tekrar deneyin.");
            var assembly = Assembly.GetExecutingAssembly();
            using (var payload = assembly.GetManifestResourceStream("payload.zip"))
            using (var hashText = new StreamReader(assembly.GetManifestResourceStream("payload.sha256")))
            using (var sha = SHA256.Create())
            {
                string actual = BitConverter.ToString(sha.ComputeHash(payload)).Replace("-", "").ToLowerInvariant();
                if (actual != hashText.ReadToEnd().Trim().ToLowerInvariant())
                    throw new IOException("Kurulum paketi doğrulanamadı. Yeniden indirin.");
                payload.Position = 0;
                InstallerCore.Install(payload, target, version);
            }
            try
            {
                CreateShortcut(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory));
                CreateShortcut(Environment.GetFolderPath(Environment.SpecialFolder.Programs));
                return "Masaüstündeki veya Başlat menüsündeki Arşivim kısayolunu kullanabilirsiniz.";
            }
            catch
            {
                return "Kısayol oluşturulamadı. Uygulama konumu: " + target;
            }
        }
    }

    private void CreateShortcut(string folder)
    {
        Directory.CreateDirectory(folder);
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
        dynamic shortcut = shell.CreateShortcut(Path.Combine(folder, "Arşivim.lnk"));
        try
        {
            shortcut.TargetPath = Path.Combine(target, "arsiv_uygulamasi.exe");
            shortcut.WorkingDirectory = target;
            shortcut.Description = "Arşivim kişisel belge arşivi";
            shortcut.Save();
        }
        finally
        {
            Marshal.FinalReleaseComObject(shortcut);
            Marshal.FinalReleaseComObject(shell);
        }
    }
}
