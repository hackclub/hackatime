# Kernel level time tracking

Editor plugins can be uninstalled. The kernel cannot (without a reboot).

`hackatime.ko` sends a heartbeat every 2 minutes from ring 0, so your coding
time is tracked even if you are not coding. Build with `make`, load with
`insmod`, regret with `rmmod`.

**This is a joke PR. Do not merge. Do not load this on a machine you like.**
