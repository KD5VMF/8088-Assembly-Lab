using System;
using System.Globalization;
using System.IO;
using System.IO.Ports;
using System.Text;
using System.Threading;

class TimeSyncHost
{
    static string ConfigFile = "TimeSyncHost.cfg";
    static string PortName = "COM1";
    static int BaudRate = 9600;
    static int ThresholdSeconds = 2;
    static string LastDailySyncDate = "";
    static DateTime LastSendUtc = DateTime.MinValue;

    static int Main(string[] args)
    {
        Console.Title = "TimeSyncHost - DOS Time Sync 88 REV7";

        bool configLoaded = LoadConfig();
        bool setupRequested = false;
        bool listOnly = false;

        ParseArgs(args, ref setupRequested, ref listOnly);

        if (listOnly)
        {
            PrintAvailablePorts();
            return 0;
        }

        // First run: no config and no command-line options, so ask setup.
        // Later runs: use saved TimeSyncHost.cfg automatically.
        if ((!configLoaded && args.Length == 0) || setupRequested)
        {
            AskSetup();
        }

        // Save normalized settings. This also repairs old configs such as Port=13.
        PortName = NormalizePortName(PortName);
        SaveConfig();

        Console.WriteLine("============================================================");
        Console.WriteLine(" TimeSyncHost REV7 - Windows clock sender for DOSTIME.EXE");
        Console.WriteLine("============================================================");
        Console.WriteLine("Port      : " + PortName);
        Console.WriteLine("Baud      : " + BaudRate);
        Console.WriteLine("Format    : 8N1, no flow control");
        Console.WriteLine("Threshold : " + ThresholdSeconds + " seconds");
        PrintTimeZoneStatus();
        Console.WriteLine();

        SerialPort sp = new SerialPort(PortName, BaudRate, Parity.None, 8, StopBits.One);
        sp.Handshake = Handshake.None;
        sp.DtrEnable = true;
        sp.RtsEnable = true;
        sp.ReadTimeout = 250;
        sp.WriteTimeout = 1000;
        sp.NewLine = "\n";

        try
        {
            sp.Open();
        }
        catch (ArgumentException ex)
        {
            PrintOpenError("Invalid serial port name", ex);
            return 2;
        }
        catch (UnauthorizedAccessException ex)
        {
            PrintOpenError("Serial port is busy or access was denied", ex);
            return 3;
        }
        catch (IOException ex)
        {
            PrintOpenError("Serial port I/O error", ex);
            return 4;
        }
        catch (Exception ex)
        {
            PrintOpenError("Could not open serial port", ex);
            return 5;
        }

        using (sp)
        {
            Console.WriteLine("Connected. Start DOSTIME.EXE on the DOS machine.");
            Console.WriteLine("Press Ctrl+C to quit.");
            Console.WriteLine();

            StringBuilder line = new StringBuilder(64);

            while (true)
            {
                try
                {
                    int v = sp.ReadChar();
                    if (v < 0) continue;
                    char ch = (char)v;

                    if (ch == '\r' || ch == '\n')
                    {
                        if (line.Length > 0)
                        {
                            ProcessLine(sp, line.ToString().Trim());
                            line.Clear();
                        }
                    }
                    else
                    {
                        if (line.Length < 63) line.Append(ch);
                        else line.Clear();
                    }
                }
                catch (TimeoutException)
                {
                    // Normal idle timeout. Keep waiting for DOS heartbeat lines.
                }
            }
        }
    }

    static void AskSetup()
    {
        Console.WriteLine("Setup:");
        PrintAvailablePorts();
        Console.WriteLine();
        Console.WriteLine("Port entry examples: COM1, COM2, COM13, or just 13");

        Console.Write("COM port [" + PortName + "]: ");
        string port = Console.ReadLine();
        if (!string.IsNullOrWhiteSpace(port)) PortName = NormalizePortName(port);
        else PortName = NormalizePortName(PortName);

        Console.Write("Baud rate [" + BaudRate + "]: ");
        string baudText = Console.ReadLine();
        int baud;
        if (int.TryParse(baudText, out baud) && baud > 0) BaudRate = baud;

        Console.Write("Correction threshold seconds [" + ThresholdSeconds + "]: ");
        string thText = Console.ReadLine();
        int th;
        if (int.TryParse(thText, out th) && th >= 1) ThresholdSeconds = th;
    }

    static void ParseArgs(string[] args, ref bool setupRequested, ref bool listOnly)
    {
        for (int i = 0; i < args.Length; i++)
        {
            string a = args[i];
            if (a.Equals("--port", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                PortName = NormalizePortName(args[++i]);
            }
            else if (a.Equals("--baud", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                int b;
                if (int.TryParse(args[++i], out b) && b > 0) BaudRate = b;
            }
            else if (a.Equals("--threshold", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                int t;
                if (int.TryParse(args[++i], out t) && t >= 1) ThresholdSeconds = t;
            }
            else if (a.Equals("--setup", StringComparison.OrdinalIgnoreCase))
            {
                setupRequested = true;
            }
            else if (a.Equals("--list", StringComparison.OrdinalIgnoreCase) ||
                     a.Equals("--ports", StringComparison.OrdinalIgnoreCase))
            {
                listOnly = true;
            }
            else if (a.Equals("--help", StringComparison.OrdinalIgnoreCase) ||
                     a.Equals("/?", StringComparison.OrdinalIgnoreCase) ||
                     a.Equals("-h", StringComparison.OrdinalIgnoreCase))
            {
                PrintHelp();
                Environment.Exit(0);
            }
        }
    }

    static string NormalizePortName(string input)
    {
        if (string.IsNullOrWhiteSpace(input)) return PortName;

        string p = input.Trim().Trim('"');
        p = p.Replace(" ", "");

        if (p.StartsWith("\\\\.\\", StringComparison.Ordinal))
            p = p.Substring(4);

        int number;
        if (int.TryParse(p, out number) && number > 0)
            return "COM" + number.ToString(CultureInfo.InvariantCulture);

        if (p.StartsWith("COM", StringComparison.OrdinalIgnoreCase))
        {
            string rest = p.Substring(3);
            if (int.TryParse(rest, out number) && number > 0)
                return "COM" + number.ToString(CultureInfo.InvariantCulture);
        }

        // Leave unusual names possible, but uppercase normal Windows-style entries.
        return p.ToUpperInvariant();
    }

    static void ProcessLine(SerialPort sp, string rawLine)
    {
        string line = CleanLine(rawLine);

        if (IsAckLine(line))
        {
            string todayKeyAck = DateTime.Now.ToString("yyyyMMdd", CultureInfo.InvariantCulture);
            LastDailySyncDate = todayKeyAck;
            LastSendUtc = DateTime.MinValue;
            SaveConfig();
            Console.WriteLine("RX AOK - DOS confirmed time set");
            return;
        }

        DateTime dosTime;
        if (!TryParseDosHeartbeat(line, out dosTime))
        {
            Console.WriteLine("RX ignored: " + rawLine);
            return;
        }

        DateTime now = DateTime.Now;
        double diff = (now - dosTime).TotalSeconds;
        double absDiff = Math.Abs(diff);
        string todayKey = now.ToString("yyyyMMdd", CultureInfo.InvariantCulture);

        Console.WriteLine("DOS " + dosTime.ToString("MM/dd/yyyy HH:mm:ss") +
                          " | WIN " + now.ToString("MM/dd/yyyy HH:mm:ss") +
                          " | diff " + diff.ToString("+0.000;-0.000;0.000") + "s");

        bool dailyDue = LastDailySyncDate != todayKey;
        bool offsetDue = absDiff >= ThresholdSeconds;

        if (!dailyDue && !offsetDue) return;

        double minSecondsBetweenSends = offsetDue ? 2.0 : 30.0;
        if ((DateTime.UtcNow - LastSendUtc).TotalSeconds < minSecondsBetweenSends) return;

        SendTimeBurst(sp, dailyDue ? "daily" : "offset");
        LastSendUtc = DateTime.UtcNow;

        // Do not mark daily sync complete merely because we transmitted.
        // REV7 waits for AOK from DOS, or for the next heartbeat to show corrected time.
        if (!offsetDue)
        {
            LastDailySyncDate = todayKey;
            SaveConfig();
        }
    }

    static string CleanLine(string line)
    {
        if (line == null) return "";
        StringBuilder sb = new StringBuilder(line.Length);
        foreach (char c in line)
        {
            if (c >= 32 && c <= 126) sb.Append(c);
        }
        return sb.ToString().Trim();
    }

    static bool IsAckLine(string line)
    {
        return line.IndexOf("AOK", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static bool TryParseDosHeartbeat(string line, out DateTime time)
    {
        time = DateTime.MinValue;
        if (string.IsNullOrEmpty(line)) return false;

        // REV7: tolerate a stray leading character, e.g. ?D20260531150705.
        for (int i = 0; i <= line.Length - 15; i++)
        {
            if (line[i] != 'D') continue;
            string digits = line.Substring(i + 1, 14);
            bool allDigits = true;
            for (int j = 0; j < digits.Length; j++)
            {
                if (!char.IsDigit(digits[j])) { allDigits = false; break; }
            }
            if (!allDigits) continue;

            if (DateTime.TryParseExact(digits, "yyyyMMddHHmmss",
                CultureInfo.InvariantCulture, DateTimeStyles.None, out time))
                return true;
        }
        return false;
    }

    static void SendTimeBurst(SerialPort sp, string reason)
    {
        DateTime now = DateTime.Now;
        bool dstActive = TimeZoneInfo.Local.IsDaylightSavingTime(now);
        char dstFlag = dstActive ? 'D' : 'S';

        // REV7 packet: TYYYYMMDDHHMMSS plus D/S DST flag.
        // DOSTIME REV7 uses Windows' local clock, so daylight-saving handling
        // comes from Windows automatically instead of from DOS.
        string packet = "T" + now.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture) + dstFlag + "\r\n";

        // Send multiple copies. Old BIOS INT 14h DOS programs can miss a short reply
        // while doing screen updates, especially with a one-byte 8250 UART.
        for (int i = 1; i <= 3; i++)
        {
            sp.Write(packet);
            Console.WriteLine("TX " + packet.Trim() + " (" + reason + ", " +
                              (dstActive ? "DST active" : "standard time") +
                              ", try " + i + "/3)");
            Thread.Sleep(250);
        }
    }

    static void PrintTimeZoneStatus()
    {
        DateTime now = DateTime.Now;
        TimeZoneInfo tz = TimeZoneInfo.Local;
        bool dstActive = tz.IsDaylightSavingTime(now);
        Console.WriteLine("Time mode : Windows local time, DST automatic");
        Console.WriteLine("Time zone : " + tz.DisplayName);
        Console.WriteLine("DST now   : " + (dstActive ? "YES" : "NO"));
    }

    static bool LoadConfig()
    {
        if (!File.Exists(ConfigFile)) return false;

        foreach (string raw in File.ReadAllLines(ConfigFile))
        {
            string line = raw.Trim();
            if (line.Length == 0 || line.StartsWith("#")) continue;
            int eq = line.IndexOf('=');
            if (eq <= 0) continue;

            string key = line.Substring(0, eq).Trim();
            string val = line.Substring(eq + 1).Trim();
            int n;

            if (key.Equals("Port", StringComparison.OrdinalIgnoreCase)) PortName = NormalizePortName(val);
            else if (key.Equals("Baud", StringComparison.OrdinalIgnoreCase) && int.TryParse(val, out n)) BaudRate = n;
            else if (key.Equals("ThresholdSeconds", StringComparison.OrdinalIgnoreCase) && int.TryParse(val, out n)) ThresholdSeconds = Math.Max(1, n);
            else if (key.Equals("LastDailySyncDate", StringComparison.OrdinalIgnoreCase)) LastDailySyncDate = val;
        }

        return true;
    }

    static void SaveConfig()
    {
        File.WriteAllLines(ConfigFile, new string[]
        {
            "# TimeSyncHost REV7 settings",
            "# Port can be COM1, COM2, COM13, etc. Plain numbers are auto-converted.",
            "Port=" + NormalizePortName(PortName),
            "Baud=" + BaudRate,
            "ThresholdSeconds=" + ThresholdSeconds,
            "LastDailySyncDate=" + LastDailySyncDate
        });
    }

    static void PrintAvailablePorts()
    {
        try
        {
            string[] ports = SerialPort.GetPortNames();
            Array.Sort(ports, StringComparer.OrdinalIgnoreCase);

            if (ports.Length == 0)
            {
                Console.WriteLine("Available ports: none found by Windows right now");
            }
            else
            {
                Console.WriteLine("Available ports: " + string.Join(", ", ports));
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("Available ports: could not list ports: " + ex.Message);
        }
    }

    static void PrintOpenError(string title, Exception ex)
    {
        Console.WriteLine();
        Console.WriteLine("ERROR: " + title);
        Console.WriteLine(ex.Message);
        Console.WriteLine();
        Console.WriteLine("What to try:");
        Console.WriteLine("  1. Enter COM13 instead of 13, this REV converts 13 -> COM13.");
        Console.WriteLine("  2. Check Device Manager for the exact COM number.");
        Console.WriteLine("  3. Close PuTTY, Tera Term, Arduino Serial Monitor, or anything using the port.");
        Console.WriteLine("  4. Run: TimeSyncHost.exe --list");
        Console.WriteLine("  5. Run setup again: TimeSyncHost.exe --setup");
        Console.WriteLine();
        PrintAvailablePorts();
    }

    static void PrintHelp()
    {
        Console.WriteLine("TimeSyncHost REV7");
        Console.WriteLine();
        Console.WriteLine("Usage:");
        Console.WriteLine("  TimeSyncHost.exe");
        Console.WriteLine("  TimeSyncHost.exe --setup");
        Console.WriteLine("  TimeSyncHost.exe --list");
        Console.WriteLine("  TimeSyncHost.exe --port COM13 --baud 9600 --threshold 2");
        Console.WriteLine("  TimeSyncHost.exe --port 13 --baud 9600 --threshold 2");
        Console.WriteLine();
        Console.WriteLine("Protocol:");
        Console.WriteLine("  RX from DOS: DYYYYMMDDHHMMSS");
        Console.WriteLine("  TX to DOS  : TYYYYMMDDHHMMSSD/S");
    }
}
