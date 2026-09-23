# How it works

The widget has no compiled backend — it reads from the system through the `executable`
DataEngine, parses the output in QML, and pushes it into a rolling history buffer that
the charts draw.

- **CPU / memory / network / disk** come from **ksystemstats**, the same daemon Plasma's
  own system monitor widgets use. It reads `/proc` in-process every 500 ms and pushes
  values over D-Bus, so the reading happens once for the whole machine however many
  widgets ask for it — no subprocess of ours. That 500 ms tick is both the floor on the
  update rate and the clock the widget samples on: one sample per delivery, and update
  intervals round to a whole number of daemon frames. Sampling on a timer of our own
  instead would beat against it — at an interval of exactly 500 ms the two run at the same
  rate with a drifting phase, and a read landing either side of the daemon's update
  duplicates a value or skips one. Two guards cover what a delivery cannot say on its own:
  a push carries only what *changed*, so an idle interface reporting the same 0 B/s emits
  nothing at all, and a watchdog keeps that graph scrolling flat instead of freezing.
- **Without that daemon** the widget falls back to reading `/proc` itself: `/proc/stat`,
  `/proc/meminfo`, `/proc/net/dev` and `/proc/diskstats` fetched by a single `cat` per
  poll and split back apart in QML, so the four busiest sections still share one process
  rather than forking one each.
- **Ping** runs `ping` per target and parses RTT / loss.
- **Network identity** — SSID / IP come from `iwgetid` / `iw` / `nmcli` and `ip`.
- **GPU** uses `nvidia-smi` on NVIDIA, sysfs on AMD, and DRM `fdinfo` on Intel/others —
  the per-engine breakdown sums each engine's counters across processes and diffs them
  between polls to derive utilization. Each metric appears only when the backend reports it.
  That `fdinfo` scan reads every process's open file descriptors, so it only runs when the
  per-engine breakdown is switched on, or when it is the card's only source of utilization.
- **Sensors** parse `sensors -j`.

## Chart rendering

All charts go through one `Diagram` component with two renderers:

- **GPU (default)** — [`shaders/diagram.frag`](../package/contents/shaders/diagram.frag) draws
  lines, areas, bars, donuts and pies with analytic anti-aliasing and glow. Samples reach
  the shader in a small data texture (16-bit values, any number of lines — a 32-thread CPU
  costs the same as one line), so a new sample is one texture upload and one pass into a
  cached layer; scrolling only slides that layer. Grid and threshold lines are a separate,
  unscrolled pass. Text never goes through the shader.
- **Canvas** — the original Context2D renderer with its GPU bloom, kept as a switch under
  Performance and used automatically on software rendering.

Measured with `make benchmark` (four cards, twelve core lines, 60 fps smooth scrolling, on
the author's machine): the shader path used **about 20–25 % less CPU per rendered frame**
(0.28–0.30 % vs 0.35–0.40 %); without animation the two are within noise. Most of what a
scrolling widget costs is Qt redrawing the window every frame, which no renderer avoids —
the frame-rate cap and turning smooth scrolling off remain the big levers.

`make parity` shows every chart style from both renderers side by side.

Between data updates the charts scroll, and they do it at the frame rate — a line that is
visibly moving is redrawn every frame, which is the only thing that reads as smooth. The
saving is elsewhere: a chart whose data arrives so rarely that a frame cannot show its
motion (a custom command polled every couple of minutes crawls at a thousandth of a pixel
per frame) redraws on every N-th frame instead, N being how many frames it needs to travel
a twentieth of a pixel. Whole frames, never a "has it moved far enough yet" test — that
one falls due after one frame sometimes and two the next, and an uneven cadence looks like
stutter even when its average rate is right. The ticker stops entirely when there is
nothing to animate: while the popup is closed, for the chart types that do not scroll
(donut, pie, horizontal bars, text), and while the widget is covered by another window.

That last one has no API behind it — nothing tells a plasmoid it has been covered up. But
a `Canvas` only runs its paint handler during a real render pass, so a paint that was
requested and never arrived means nothing is drawing us. The widget watches for that and
drops to one probe per second until a paint lands again. Data collection carries on
throughout, so uncovering the widget shows a complete chart rather than a gap.

Data never arrives exactly on time, and the scroll is built so that this never shows. Each
chart slides by one history step per update, so a sample landing *early* would otherwise
snap the line forward and a *late* one would leave it stranded — the widget carries the
difference into the next cycle instead, and the line keeps the speed it already had
straight through the update. When a sample is late enough to run the scroll off the end of
its step, the motion eases to a stop over a quarter second rather than halting on a frame,
and picks up from exactly there when the data lands. The upshot is that no update interval
looks different from any other: the line glides at a near-constant rate whether the samples
behind it are early, late, or missing.

