// SPDX-License-Identifier: GPL-2.0
//! Rewrite in Rust. The C file stays, for safety reasons.
use kernel::prelude::*;

module! {
    type: Hackatime,
    name: "hackatime_rs",
    license: "GPL",
}

struct Hackatime;

impl kernel::Module for Hackatime {
    fn init(_m: &'static ThisModule) -> Result<Self> {
        pr_info!("hackatime: heartbeat, but memory safe\n");
        Ok(Hackatime)
    }
}
