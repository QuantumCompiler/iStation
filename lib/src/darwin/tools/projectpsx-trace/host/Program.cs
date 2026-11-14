// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors
//
// A headless console host for ProjectPSX with iStation's trace logging: runs a BIOS image, or a BIOS
// then a PS-EXE, for a number of frames, writing TraceKit's instruction and frame records.
//
//   ProjectPSXTrace --bios <image> [--exe <file>] [--frames <n>] [--instructions <trace>]
//                   [--full-state-interval <n>] [--frame-trace <trace>] [--tty <file>]
//
// Exit status: 0 done, 2 the arguments or an output file were wrong, 3 ProjectPSX stopped with an exception — what was
// recorded until then is kept, and the last line says at which frame — 4 with --exe and --tty, the EXE
// never started (only SCPH-1001's BIOS loads one).
//
// The BIOS is the caller's: the user's own dump, or an image built in code. Nothing is copied.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using ProjectPSX;

sealed class Host : IHostWindow {
    public ProjectPSX.ProjectPSX Console;
    public int Frames;
    public int Limit;

    public void Render(int[] vram) {
        if (Frames < Limit) IStationTrace.Frame(Console.Bus.Ram);
        Frames++;
    }

    public void SetDisplayMode(int horizontalRes, int verticalRes, bool is24BitDepth) { }
    public void SetHorizontalRange(ushort displayX1, ushort displayX2) { }
    public void SetVRAMStart(ushort displayVRAMXStart, ushort displayVRAMYStart) { }
    public void SetVerticalRange(ushort displayY1, ushort displayY2) { }
    public void Play(byte[] samples) { }
}

static class Program {
    static readonly HashSet<string> Known = new() { "bios", "exe", "frames", "instructions", "full-state-interval", "frame-trace", "tty" };

    static int Main(string[] args) {
        // ProjectPSX waits on the console's input after some of its messages (an unhandled CD-ROM
        // command, GP1 command or register): headless, that input is empty, and the run goes on.
        System.Console.SetIn(TextReader.Null);

        var options = new Dictionary<string, string>();
        for (int i = 0; i < args.Length; i++) {
            if (!args[i].StartsWith("--") || i + 1 >= args.Length) { return Usage($"{args[i]} needs a value"); }
            var name = args[i].Substring(2);
            if (!Known.Contains(name)) { return Usage($"unknown option {args[i]}"); }
            options[name] = args[++i];
        }
        if (!options.TryGetValue("bios", out var bios) || !File.Exists(bios)) { return Usage("--bios needs an image that exists"); }
        // ProjectPSX copies the whole file into its 512 KB BIOS buffer, unchecked.
        if (new FileInfo(bios).Length != 0x80000) { return Usage($"{bios} isn't a 512 KB BIOS image"); }
        int frames = 60;
        if (options.TryGetValue("frames", out var f) && (!int.TryParse(f, out frames) || frames < 0)) { return Usage("--frames needs a whole number of at least 0"); }
        uint interval = 0;
        if (options.TryGetValue("full-state-interval", out var n) && !uint.TryParse(n, out interval)) { return Usage("--full-state-interval needs a whole number"); }
        // An EXE, checked before anything is written: ProjectPSX takes it as one only by its lowercase
        // extension, and reads its header unchecked.
        options.TryGetValue("exe", out var exe);
        uint? entry = null;
        if (exe != null) {
            if (!File.Exists(exe) || !exe.EndsWith(".exe", StringComparison.Ordinal)) { return Usage($"--exe needs a file ending in .exe: {exe}"); }
            var header = new byte[0x800];
            using (var file = File.OpenRead(exe)) {
                if (file.Length < header.Length) { return Usage($"{exe} is shorter than a PS-EXE's 2 KB header"); }
                file.ReadExactly(header);
            }
            if (Encoding.ASCII.GetString(header, 0, 8) != "PS-X EXE") { return Usage($"{exe} isn't a PS-EXE"); }
            entry = BitConverter.ToUInt32(header, 0x10);
        }

        BUS.bios = bios;
        // The TTY — the BIOS's putchar and expansion 2's DUART — to its own file, apart from ProjectPSX's
        // log lines. An EXE's starts at its entry point: the BIOS's messages before it aren't the program's.
        try {
            if (options.TryGetValue("tty", out var tty)) {
                IStationTrace.tty = File.Create(tty);
                IStationTrace.ttyFrom = entry;
            }
            if (options.TryGetValue("instructions", out var instructions)) IStationTrace.StartInstructions(instructions, interval);
            if (options.TryGetValue("frame-trace", out var frameTrace)) IStationTrace.StartFrames(frameTrace);
        } catch (Exception error) when (error is IOException || error is UnauthorizedAccessException) {
            return Usage($"an output file can't be written: {error.Message}");
        }

        var host = new Host { Limit = frames };
        var clock = Stopwatch.StartNew();
        try {
            host.Console = new ProjectPSX.ProjectPSX(host, exe ?? "");
            // No disc, ever, and ProjectPSX can't answer "no disc": its CD has no tracks without a disc
            // image, so with the lid closed a GetID or ReadN would throw. The host opens the lid instead,
            // so a BIOS sees an open lid, not an empty closed drive, and its disc checks may take another
            // path than on the other consoles.
            host.Console.toggleCdRomLid();
            while (host.Frames < frames) host.Console.RunFrame();
        } catch (Exception error) {
            // ProjectPSX stopped: keep what was recorded, and say where.
            IStationTrace.Finish();
            IStationTrace.tty?.Dispose();
            System.Console.Error.WriteLine($"[ProjectPSXTrace] stopped at frame {host.Frames}, {IStationTrace.cycles} CPU cycles, {clock.Elapsed.TotalSeconds:F2} s: {error.GetType().Name}: {error.Message}");
            return 3;
        }
        IStationTrace.Finish();
        IStationTrace.tty?.Dispose();
        var summary = $"[ProjectPSXTrace] {host.Frames} frames, {IStationTrace.cycles} CPU cycles, {clock.Elapsed.TotalSeconds:F2} s";
        if (IStationTrace.ttyFrom is uint never) {
            // The PC never reached the EXE's entry: on a BIOS other than SCPH-1001 its load never runs.
            System.Console.Error.WriteLine($"{summary}; the EXE never started (its entry, 0x{never:X8}, was never reached), so its TTY is empty");
            return 4;
        }
        System.Console.Error.WriteLine(summary);
        return 0;
    }

    static int Usage(string why) {
        System.Console.Error.WriteLine($"ProjectPSXTrace: {why}");
        System.Console.Error.WriteLine("usage: ProjectPSXTrace --bios <image> [--exe <file>] [--frames <n>] [--instructions <trace>] [--full-state-interval <n>] [--frame-trace <trace>] [--tty <file>]");
        return 2;
    }
}
