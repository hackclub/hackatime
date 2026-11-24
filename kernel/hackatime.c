// SPDX-License-Identifier: GPL-2.0
// Kernel level time tracking. Joke: do not load this. Seriously.
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/timer.h>

static struct timer_list beat;

static void send_heartbeat(struct timer_list *t)
{
	/* ponytail: userspace sends the real HTTP request, kernels shouldn't */
	pr_info("hackatime: heartbeat (ring 0, entity=/dev/mem, category=coding)\n");
	mod_timer(&beat, jiffies + HZ * 120); /* every 2 minutes, like wakatime */
}

static int __init hackatime_init(void)
{
	timer_setup(&beat, send_heartbeat, 0);
	mod_timer(&beat, jiffies + HZ);
	return 0;
}

static void __exit hackatime_exit(void)
{
	del_timer_sync(&beat);
}

module_init(hackatime_init);
module_exit(hackatime_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Kernel level time tracking (joke)");
