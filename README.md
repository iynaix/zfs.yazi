# zfs.yazi

A Yazi plugin for browsing backwards and forwards in time via ZFS snapshots.

https://github.com/user-attachments/assets/6d2fc9e7-f86e-4444-aab6-4e11e51e8b34

## Installation

```sh
ya pack -a iynaix/zfs
```

## Usage

Add keymaps similar to the following to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on = ["z", "h"]
run = "plugin zfs --args=prev"
desc = "Go to previous ZFS snapshot"

[[manager.prepend_keymap]]
on = ["z", "l"]
run = "plugin zfs --args=next"
desc = "Go to next ZFS snapshot"

[[manager.prepend_keymap]]
on = ["z", "e"]
run = "plugin zfs --args=exit"
desc = "Exit browsing ZFS snapshots"
```
