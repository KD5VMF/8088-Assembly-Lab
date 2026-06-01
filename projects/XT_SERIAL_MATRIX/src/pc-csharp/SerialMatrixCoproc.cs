// SerialMatrixCoproc.cs
//
// XT / 8088 Serial Matrix Co-Processor Host Program
//
// The 8088 side generates a new data-set request over RS-232:
//
//   MAT,seq,N,seedA,seedB*XX
//
// Example:
//
//   MAT,00001,04096,12345,54321*59
//
// The PC side expands the 8088-provided seeds into deterministic 4096x4096
// pseudo-random matrices A and B, performs real matrix-multiplication
// fingerprint math, and sends compact fixed-width result fields back to the XT.
//
// Response format:
//
//   RSP,seq,N,seedA,seedB,sumMod,diagMod,c00,cmid,clast,ms*XX
//
// Example:
//
//   RSP,00001,04096,12345,54321,1234567890,1234567890,1234567890,1234567890,1234567890,00123*XX
//
// NOTE ABOUT 4096x4096:
// Sending all two raw 4096x4096 matrices across a 9600 baud serial link would
// take many hours before the PC could even start. This program uses practical
// seed-stream mode: the 8088 generates and sends the random seeds and matrix
// size; the PC expands those into the exact matrices and calculates exact
// A*B aggregate fingerprints and sample cells. That keeps the screen alive and
// makes the modern PC do the heavy work.

using System;
using System.Diagnostics;
using System.Globalization;
using System.IO.Ports;
using System.Text;
using System.Threading;

namespace SerialMatrixCoproc
{
    internal static class Program
    {
        private const int DefaultBaud = 9600;
        private const ulong Mod = 10000000000UL; // 10 fixed display digits

        private static volatile bool _running = true;
        private static Dashboard _dashboard = new Dashboard();

        private static int Main(string[] args)
        {
            Console.Title = "XT / 8088 Serial Matrix Co-Processor";

            if (args.Length > 0 && IsArg(args[0], "--list"))
            {
                ListPorts();
                return 0;
            }

            if (args.Length > 0 && IsArg(args[0], "--selftest"))
            {
                SelfTest();
                return 0;
            }

            string portName;
            int baudRate;
            if (!GetPortAndBaud(args, out portName, out baudRate))
            {
                return 1;
            }

            Console.CancelKeyPress += delegate(object sender, ConsoleCancelEventArgs e)
            {
                e.Cancel = true;
                _running = false;
            };

            using (SerialPort port = new SerialPort())
            {
                port.PortName = portName;
                port.BaudRate = baudRate;
                port.DataBits = 8;
                port.Parity = Parity.None;
                port.StopBits = StopBits.One;
                port.Handshake = Handshake.None;
                port.Encoding = Encoding.ASCII;
                port.ReadTimeout = 100;
                port.WriteTimeout = 1000;
                port.NewLine = "\r\n";
                port.DtrEnable = true;
                port.RtsEnable = true;

                try
                {
                    port.Open();
                }
                catch (Exception ex)
                {
                    Console.WriteLine("Could not open {0}: {1}", portName, ex.Message);
                    return 1;
                }

                _dashboard.DrawStatic(portName, baudRate);
                RunServerLoop(port);
            }

            Console.CursorVisible = true;
            Console.ResetColor();
            Console.SetCursorPosition(0, Math.Min(Console.WindowHeight - 1, 24));
            Console.WriteLine();
            return 0;
        }

        private static bool GetPortAndBaud(string[] args, out string portName, out int baudRate)
        {
            portName = "";
            baudRate = DefaultBaud;

            if (args.Length >= 1)
            {
                portName = args[0].Trim().ToUpperInvariant();
            }
            else
            {
                PrintIntro();
                Console.Write("COM port, example COM3: ");
                portName = (Console.ReadLine() ?? "").Trim().ToUpperInvariant();
            }

            if (string.IsNullOrEmpty(portName))
            {
                Console.WriteLine("No COM port selected.");
                return false;
            }

            if (args.Length >= 2)
            {
                if (!int.TryParse(args[1], out baudRate))
                {
                    Console.WriteLine("Baud rate must be a number.");
                    return false;
                }
            }
            else if (args.Length == 0)
            {
                Console.Write("Baud rate [9600]: ");
                string text = Console.ReadLine();
                if (!string.IsNullOrWhiteSpace(text))
                {
                    if (!int.TryParse(text.Trim(), out baudRate))
                    {
                        Console.WriteLine("Baud rate must be a number.");
                        return false;
                    }
                }
            }

            return true;
        }

        private static void PrintIntro()
        {
            Console.WriteLine("============================================================");
            Console.WriteLine(" XT / 8088 SERIAL MATRIX CO-PROCESSOR - PC HOST");
            Console.WriteLine("============================================================");
            Console.WriteLine();
            ListPorts();
            Console.WriteLine();
        }

        private static void ListPorts()
        {
            string[] ports = SerialPort.GetPortNames();
            Array.Sort(ports, StringComparer.OrdinalIgnoreCase);
            Console.WriteLine("Available serial ports:");
            if (ports.Length == 0)
            {
                Console.WriteLine("  none found");
            }
            else
            {
                for (int i = 0; i < ports.Length; i++)
                {
                    Console.WriteLine("  " + ports[i]);
                }
            }
        }

        private static void RunServerLoop(SerialPort port)
        {
            StringBuilder lineBuffer = new StringBuilder(256);
            long receivedLines = 0;
            long goodRequests = 0;
            long badRequests = 0;
            long txBytes = 0;
            long rxBytes = 0;
            long jobsDone = 0;

            Stopwatch uptime = Stopwatch.StartNew();
            _dashboard.SetStatus("WAITING", "Waiting for 8088 MAT request lines...");
            _dashboard.SetCounters(receivedLines, goodRequests, badRequests, jobsDone, rxBytes, txBytes, uptime.Elapsed);

            while (_running)
            {
                CheckConsoleKeys(ref receivedLines, ref goodRequests, ref badRequests, ref jobsDone, ref rxBytes, ref txBytes);

                try
                {
                    int value = port.ReadByte();
                    if (value < 0)
                    {
                        continue;
                    }

                    rxBytes++;
                    char ch = (char)value;

                    if (ch == '\r' || ch == '\n')
                    {
                        if (lineBuffer.Length == 0)
                        {
                            continue;
                        }

                        string line = lineBuffer.ToString().Trim();
                        lineBuffer.Length = 0;
                        receivedLines++;
                        _dashboard.SetLastRx(line);
                        _dashboard.SetStatus("RECEIVING", "Received a request from the 8088.");

                        MatrixRequest req;
                        string parseError;
                        if (!TryParseRequest(line, out req, out parseError))
                        {
                            badRequests++;
                            string err = BuildErrorResponse(parseError);
                            SafeWriteLine(port, err);
                            txBytes += err.Length + 2;
                            _dashboard.SetLastTx(err);
                            _dashboard.SetStatus("ERROR", parseError);
                            _dashboard.SetCounters(receivedLines, goodRequests, badRequests, jobsDone, rxBytes, txBytes, uptime.Elapsed);
                            continue;
                        }

                        goodRequests++;
                        _dashboard.SetRequest(req);
                        _dashboard.SetStatus("PROCESSING", "Expanding 8088 seeds and calculating matrix fingerprints...");

                        MatrixResult result = CalculateMatrixFingerprint(req);
                        jobsDone++;

                        string response = BuildResponse(req, result);
                        _dashboard.SetResult(result, jobsDone);
                        _dashboard.SetStatus("TRANSMITTING", "Sending fixed-width result back to the 8088...");
                        SafeWriteLine(port, response);
                        txBytes += response.Length + 2;
                        _dashboard.SetLastTx(response);

                        _dashboard.SetStatus("WAITING", "Result sent. Waiting for next 8088 data set...");
                        _dashboard.SetCounters(receivedLines, goodRequests, badRequests, jobsDone, rxBytes, txBytes, uptime.Elapsed);
                    }
                    else
                    {
                        if (ch >= 32 && ch <= 126)
                        {
                            if (lineBuffer.Length < 240)
                            {
                                lineBuffer.Append(ch);
                            }
                            else
                            {
                                lineBuffer.Length = 0;
                                badRequests++;
                                _dashboard.SetStatus("ERROR", "Input line too long; buffer cleared.");
                            }
                        }
                    }
                }
                catch (TimeoutException)
                {
                    _dashboard.SetCounters(receivedLines, goodRequests, badRequests, jobsDone, rxBytes, txBytes, uptime.Elapsed);
                }
                catch (Exception ex)
                {
                    badRequests++;
                    _dashboard.SetStatus("SERIAL ERROR", ex.Message);
                    Thread.Sleep(500);
                }
            }
        }

        private static void CheckConsoleKeys(ref long receivedLines, ref long goodRequests, ref long badRequests, ref long jobsDone, ref long rxBytes, ref long txBytes)
        {
            if (!Console.KeyAvailable)
            {
                return;
            }

            ConsoleKeyInfo key = Console.ReadKey(true);
            if (key.Key == ConsoleKey.Q || key.Key == ConsoleKey.Escape)
            {
                _running = false;
                return;
            }

            if (key.Key == ConsoleKey.C)
            {
                receivedLines = 0;
                goodRequests = 0;
                badRequests = 0;
                jobsDone = 0;
                rxBytes = 0;
                txBytes = 0;
                _dashboard.SetStatus("COUNTERS CLEARED", "PC-side counters were reset.");
            }
        }

        private static bool TryParseRequest(string rawLine, out MatrixRequest request, out string error)
        {
            request = new MatrixRequest();
            error = "";

            string line = rawLine.Trim();
            if (line.Length == 0)
            {
                error = "EMPTY LINE";
                return false;
            }

            int star = line.IndexOf('*');
            if (star >= 0)
            {
                string body = line.Substring(0, star);
                string givenText = line.Substring(star + 1).Trim();
                if (givenText.Length < 2)
                {
                    error = "BAD CHECKSUM TEXT";
                    return false;
                }

                byte expected = XorChecksum(body);
                byte given;
                if (!byte.TryParse(givenText.Substring(0, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out given))
                {
                    error = "BAD CHECKSUM HEX";
                    return false;
                }

                if (expected != given)
                {
                    error = "CHECKSUM FAIL";
                    return false;
                }

                line = body;
            }

            string[] parts = line.Split(',');
            if (parts.Length != 5)
            {
                error = "EXPECTED MAT,SEQ,N,SEEDA,SEEDB";
                return false;
            }

            if (!StringEqualsIgnoreCase(parts[0].Trim(), "MAT"))
            {
                error = "NOT A MAT REQUEST";
                return false;
            }

            int seq;
            int n;
            int seedA;
            int seedB;

            if (!int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out seq))
            {
                error = "BAD SEQ";
                return false;
            }

            if (!int.TryParse(parts[2], NumberStyles.Integer, CultureInfo.InvariantCulture, out n))
            {
                error = "BAD MATRIX SIZE";
                return false;
            }

            if (!int.TryParse(parts[3], NumberStyles.Integer, CultureInfo.InvariantCulture, out seedA))
            {
                error = "BAD SEED A";
                return false;
            }

            if (!int.TryParse(parts[4], NumberStyles.Integer, CultureInfo.InvariantCulture, out seedB))
            {
                error = "BAD SEED B";
                return false;
            }

            if (n < 2 || n > 4096)
            {
                error = "MATRIX SIZE OUT OF RANGE";
                return false;
            }

            request.Sequence = seq;
            request.N = n;
            request.SeedA = seedA & 0xFFFF;
            request.SeedB = seedB & 0xFFFF;
            return true;
        }

        private static MatrixResult CalculateMatrixFingerprint(MatrixRequest req)
        {
            Stopwatch sw = Stopwatch.StartNew();
            int n = req.N;
            ushort seedA = (ushort)req.SeedA;
            ushort seedB = (ushort)req.SeedB;

            ulong[] colSumA = new ulong[n];
            ulong[] rowSumB = new ulong[n];
            ulong diag = 0;

            for (int i = 0; i < n; i++)
            {
                ulong rowB = 0;
                for (int k = 0; k < n; k++)
                {
                    uint a = MatrixValue(seedA, i, k);
                    uint b = MatrixValue(seedB, i, k);
                    uint bTransposed = MatrixValue(seedB, k, i);

                    colSumA[k] += a;
                    if (colSumA[k] >= Mod)
                    {
                        colSumA[k] %= Mod;
                    }

                    rowB += b;
                    if (rowB >= Mod)
                    {
                        rowB %= Mod;
                    }

                    diag = (diag + ((ulong)a * (ulong)bTransposed)) % Mod;
                }
                rowSumB[i] = rowB;
            }

            ulong sumAll = 0;
            for (int k = 0; k < n; k++)
            {
                sumAll = (sumAll + ((colSumA[k] % Mod) * (rowSumB[k] % Mod))) % Mod;
            }

            int mid = n / 2;
            ulong c00 = DotCell(seedA, seedB, n, 0, 0);
            ulong cmid = DotCell(seedA, seedB, n, mid, mid);
            ulong clast = DotCell(seedA, seedB, n, n - 1, n - 1);

            sw.Stop();

            MatrixResult r = new MatrixResult();
            r.SumMod = sumAll;
            r.DiagMod = diag;
            r.C00 = c00;
            r.CMid = cmid;
            r.CLast = clast;
            r.ElapsedMs = sw.ElapsedMilliseconds;
            r.TheoreticalMultiplyAdds = (double)n * (double)n * (double)n;
            return r;
        }

        private static ulong DotCell(ushort seedA, ushort seedB, int n, int row, int col)
        {
            ulong sum = 0;
            for (int k = 0; k < n; k++)
            {
                uint a = MatrixValue(seedA, row, k);
                uint b = MatrixValue(seedB, k, col);
                sum = (sum + ((ulong)a * (ulong)b)) % Mod;
            }
            return sum;
        }

        private static uint MatrixValue(ushort seed, int row, int col)
        {
            unchecked
            {
                uint x = seed;
                x ^= (uint)(row + 1) * 0x45d9f3bu;
                x ^= (uint)(col + 1) * 0x27d4eb2du;
                x ^= x >> 15;
                x *= 2246822519u;
                x ^= x >> 13;
                x *= 3266489917u;
                x ^= x >> 16;
                return x % 10000u; // large-looking 0..9999 matrix entries
            }
        }

        private static string BuildResponse(MatrixRequest req, MatrixResult result)
        {
            string body = string.Format(
                CultureInfo.InvariantCulture,
                "RSP,{0:D5},{1:D5},{2:D5},{3:D5},{4:D10},{5:D10},{6:D10},{7:D10},{8:D10},{9:D5}",
                req.Sequence % 100000,
                req.N,
                req.SeedA,
                req.SeedB,
                result.SumMod % Mod,
                result.DiagMod % Mod,
                result.C00 % Mod,
                result.CMid % Mod,
                result.CLast % Mod,
                result.ElapsedMs % 100000);

            return body + "*" + XorChecksum(body).ToString("X2", CultureInfo.InvariantCulture);
        }

        private static string BuildErrorResponse(string error)
        {
            string safe = error ?? "ERROR";
            safe = safe.Replace(',', ' ');
            if (safe.Length > 50)
            {
                safe = safe.Substring(0, 50);
            }
            string body = "ERR," + safe;
            return body + "*" + XorChecksum(body).ToString("X2", CultureInfo.InvariantCulture);
        }

        private static void SafeWriteLine(SerialPort port, string text)
        {
            try
            {
                port.Write(text + "\r\n");
            }
            catch
            {
                // The dashboard will show a serial error on the next loop.
            }
        }

        private static byte XorChecksum(string text)
        {
            byte x = 0;
            for (int i = 0; i < text.Length; i++)
            {
                x ^= (byte)text[i];
            }
            return x;
        }

        private static bool StringEqualsIgnoreCase(string a, string b)
        {
            return string.Equals(a, b, StringComparison.OrdinalIgnoreCase);
        }

        private static bool IsArg(string text, string arg)
        {
            return string.Equals(text, arg, StringComparison.OrdinalIgnoreCase);
        }

        private static void SelfTest()
        {
            Console.WriteLine("XT / 8088 Serial Matrix Co-Processor SELFTEST");
            string body = "MAT,00001,00512,12345,54321";
            string requestLine = body + "*" + XorChecksum(body).ToString("X2", CultureInfo.InvariantCulture);
            Console.WriteLine("Request : " + requestLine);

            MatrixRequest req;
            string error;
            if (!TryParseRequest(requestLine, out req, out error))
            {
                Console.WriteLine("Parse failed: " + error);
                return;
            }

            MatrixResult r = CalculateMatrixFingerprint(req);
            Console.WriteLine("Response: " + BuildResponse(req, r));
            Console.WriteLine("N={0} SeedA={1} SeedB={2}", req.N, req.SeedA, req.SeedB);
            Console.WriteLine("SUM={0:D10} DIAG={1:D10} C00={2:D10} CMID={3:D10} CLAST={4:D10} MS={5}",
                r.SumMod, r.DiagMod, r.C00, r.CMid, r.CLast, r.ElapsedMs);
        }
    }

    internal struct MatrixRequest
    {
        public int Sequence;
        public int N;
        public int SeedA;
        public int SeedB;
    }

    internal struct MatrixResult
    {
        public ulong SumMod;
        public ulong DiagMod;
        public ulong C00;
        public ulong CMid;
        public ulong CLast;
        public long ElapsedMs;
        public double TheoreticalMultiplyAdds;
    }

    internal sealed class Dashboard
    {
        private readonly object _lock = new object();

        public void DrawStatic(string portName, int baudRate)
        {
            lock (_lock)
            {
                Console.CursorVisible = false;
                Console.Clear();
                WriteAt(0, 0, Pad("XT / 8088 SERIAL MATRIX CO-PROCESSOR  -  PC HOST DASHBOARD", 78), ConsoleColor.Green);
                WriteAt(1, 0, Pad("8088 SENDS MATRIX SEEDS -> PC CALCULATES -> 8088 DISPLAYS RESULTS", 78), ConsoleColor.Green);
                WriteAt(2, 0, new string('-', 78), ConsoleColor.DarkGreen);
                WriteAt(3, 0, Pad(string.Format(CultureInfo.InvariantCulture, "PORT: {0,-8}  BAUD: {1,-8}  FORMAT: 8N1     Q/ESC=QUIT   C=CLEAR", portName, baudRate), 78), ConsoleColor.Yellow);
                WriteAt(4, 0, new string('-', 78), ConsoleColor.DarkGreen);

                WriteAt(5, 0, "STATE   :", ConsoleColor.White);
                WriteAt(6, 0, "MESSAGE :", ConsoleColor.White);

                WriteAt(8, 0, "CURRENT 8088 DATA SET", ConsoleColor.White);
                WriteAt(9, 2, "REQ:", ConsoleColor.DarkGreen);
                WriteAt(9, 18, "SIZE:", ConsoleColor.DarkGreen);
                WriteAt(9, 39, "A-SEED:", ConsoleColor.DarkGreen);
                WriteAt(9, 58, "B-SEED:", ConsoleColor.DarkGreen);

                WriteAt(11, 0, "MATRIX RESULT RETURNED TO XT", ConsoleColor.White);
                WriteAt(12, 2, "SUM MOD:", ConsoleColor.DarkGreen);
                WriteAt(12, 31, "DIAG MOD:", ConsoleColor.DarkGreen);
                WriteAt(13, 2, "C00:", ConsoleColor.DarkGreen);
                WriteAt(13, 23, "CMID:", ConsoleColor.DarkGreen);
                WriteAt(13, 45, "CLAST:", ConsoleColor.DarkGreen);
                WriteAt(14, 2, "PC TIME:", ConsoleColor.DarkGreen);

                WriteAt(16, 0, "SERIAL / JOB COUNTERS", ConsoleColor.White);
                WriteAt(17, 2, "RX LINES:", ConsoleColor.DarkGreen);
                WriteAt(17, 22, "GOOD:", ConsoleColor.DarkGreen);
                WriteAt(17, 38, "BAD:", ConsoleColor.DarkGreen);
                WriteAt(17, 53, "JOBS:", ConsoleColor.DarkGreen);
                WriteAt(18, 2, "RX BYTES:", ConsoleColor.DarkGreen);
                WriteAt(18, 28, "TX BYTES:", ConsoleColor.DarkGreen);
                WriteAt(18, 53, "UPTIME:", ConsoleColor.DarkGreen);

                WriteAt(20, 0, "LAST RX:", ConsoleColor.White);
                WriteAt(22, 0, "LAST TX:", ConsoleColor.White);
            }
        }

        public void SetStatus(string state, string message)
        {
            lock (_lock)
            {
                WriteAt(5, 10, Pad(state, 25), ConsoleColor.Yellow);
                WriteAt(6, 10, Pad(message, 66), ConsoleColor.Green);
            }
        }

        public void SetRequest(MatrixRequest req)
        {
            lock (_lock)
            {
                WriteAt(9, 7, req.Sequence.ToString("D5", CultureInfo.InvariantCulture), ConsoleColor.Green);
                WriteAt(9, 24, req.N.ToString("D5", CultureInfo.InvariantCulture) + " x " + req.N.ToString("D5", CultureInfo.InvariantCulture), ConsoleColor.Green);
                WriteAt(9, 47, req.SeedA.ToString("D5", CultureInfo.InvariantCulture), ConsoleColor.Green);
                WriteAt(9, 66, req.SeedB.ToString("D5", CultureInfo.InvariantCulture), ConsoleColor.Green);
            }
        }

        public void SetResult(MatrixResult r, long jobsDone)
        {
            lock (_lock)
            {
                WriteAt(12, 11, r.SumMod.ToString("D10", CultureInfo.InvariantCulture), ConsoleColor.Green);
                WriteAt(12, 41, r.DiagMod.ToString("D10", CultureInfo.InvariantCulture), ConsoleColor.Green);
                WriteAt(13, 7, r.C00.ToString("D10", CultureInfo.InvariantCulture), ConsoleColor.Green);
                WriteAt(13, 29, r.CMid.ToString("D10", CultureInfo.InvariantCulture), ConsoleColor.Green);
                WriteAt(13, 52, r.CLast.ToString("D10", CultureInfo.InvariantCulture), ConsoleColor.Green);
                WriteAt(14, 12, Pad(r.ElapsedMs.ToString(CultureInfo.InvariantCulture) + " ms", 18), ConsoleColor.Green);
            }
        }

        public void SetCounters(long rxLines, long good, long bad, long jobs, long rxBytes, long txBytes, TimeSpan uptime)
        {
            lock (_lock)
            {
                WriteAt(17, 12, rxLines.ToString(CultureInfo.InvariantCulture).PadLeft(8), ConsoleColor.Green);
                WriteAt(17, 28, good.ToString(CultureInfo.InvariantCulture).PadLeft(8), ConsoleColor.Green);
                WriteAt(17, 43, bad.ToString(CultureInfo.InvariantCulture).PadLeft(8), ConsoleColor.Yellow);
                WriteAt(17, 59, jobs.ToString(CultureInfo.InvariantCulture).PadLeft(8), ConsoleColor.Green);
                WriteAt(18, 12, rxBytes.ToString(CultureInfo.InvariantCulture).PadLeft(10), ConsoleColor.Green);
                WriteAt(18, 38, txBytes.ToString(CultureInfo.InvariantCulture).PadLeft(10), ConsoleColor.Green);
                WriteAt(18, 61, FormatTime(uptime), ConsoleColor.Green);
            }
        }

        public void SetLastRx(string line)
        {
            lock (_lock)
            {
                WriteAt(21, 0, Pad(Trim(line, 78), 78), ConsoleColor.Green);
            }
        }

        public void SetLastTx(string line)
        {
            lock (_lock)
            {
                WriteAt(23, 0, Pad(Trim(line, 78), 78), ConsoleColor.Green);
            }
        }

        private static string FormatTime(TimeSpan t)
        {
            return string.Format(CultureInfo.InvariantCulture, "{0:D2}:{1:D2}:{2:D2}", (int)t.TotalHours, t.Minutes, t.Seconds);
        }

        private static string Trim(string text, int width)
        {
            if (text == null)
            {
                return "";
            }
            if (text.Length <= width)
            {
                return text;
            }
            return text.Substring(0, width);
        }

        private static string Pad(string text, int width)
        {
            text = Trim(text, width);
            return text.PadRight(width);
        }

        private static void WriteAt(int row, int col, string text, ConsoleColor color)
        {
            try
            {
                Console.ForegroundColor = color;
                if (row < Console.BufferHeight && col < Console.BufferWidth)
                {
                    Console.SetCursorPosition(col, row);
                    Console.Write(text);
                }
                Console.ResetColor();
            }
            catch
            {
                // Ignore console resize errors.
            }
        }
    }
}