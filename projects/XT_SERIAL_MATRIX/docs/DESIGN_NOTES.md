# Design Notes

## Goal

This project makes the 8088 feel like it has a serial-attached math co-processor. The XT is still in charge: it generates the work, sends the request, receives the answer, and displays the result. The PC performs the heavy math.

## Why not send all matrix values?

A 4096 x 4096 matrix has 16,777,216 elements. Two matrices have 33,554,432 elements. Sending that much raw data over an XT serial port would make the demo mostly a transfer-speed demo rather than a live co-processor demo.

Instead, the XT sends deterministic random seeds. The PC expands those seeds into the same large data set every time for that job. Each new XT job uses new seeds, so every cycle is a new matrix job.

## What the PC calculates

The PC performs deterministic matrix-multiplication work and returns compact result fingerprints and sample cells. This gives the XT a clean display and proves the PC processed the requested data set without requiring the XT to receive a giant matrix back.

## Why fixed-width output?

The 8088 display uses direct text-mode output. Fixed-width fields prevent ugly wrapping and make the screen easier to watch on real VGA/SVGA hardware.

## Runtime philosophy

- Keep the XT side understandable.
- Avoid disk writes while running.
- Use polled serial I/O instead of IRQs for simplicity.
- Use no-scroll dashboards on both machines.
- Keep the serial protocol human-readable.
