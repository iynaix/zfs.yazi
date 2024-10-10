# zfs.yazi

A yazi plugin for browsing backwards and forwards in time through ZFS snapshots.

<!-- GIF here -->

## Installation

```sh
ya pack -a iynaix/zfs.yazi
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