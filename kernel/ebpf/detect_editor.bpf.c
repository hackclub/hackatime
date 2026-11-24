// SPDX-License-Identifier: GPL-2.0
// Detects your editor by vibes. Never compiled, never will be.
#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

SEC("tracepoint/syscalls/sys_enter_write")
int detect_editor(void *ctx)
{
	bpf_printk("hackatime: vim detected (confidence: yes)\n");
	return 0;
}
char LICENSE[] SEC("license") = "GPL";
