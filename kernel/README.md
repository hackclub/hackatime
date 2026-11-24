# Kernel level time tracking

Editor plugins can be uninstalled. The kernel cannot (without a reboot).

`hackatime.ko` sends a heartbeat every 2 minutes from ring 0, so your coding
time is tracked even if you are not coding. Build with `make`, load with
`insmod`, regret with `rmmod`.

**This is a joke PR. Do not merge. Do not load this on a machine you like.**

## Benchmarks

| | WakaTime plugin | hackatime.ko |
|---|---|---|
| Uptime tracked | 6 h/day | 24 h/day |
| Hours coded / year | 2,190 | 8,760 |
| Can be disabled | yes | after a reboot |
| Lines of code | many | 25 |
| Reviewer enthusiasm | n/a | 0 |

## Panic on broken streak

```
Kernel panic - not syncing: streak < 1 day
CPU: 0 PID: 1 Comm: hackatime Tainted: G  HACKATIME_TAINT
Hardware name: your disappointment
---[ end Kernel panic - you should have coded ]---
```
