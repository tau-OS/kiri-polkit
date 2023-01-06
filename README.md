# tauOS PolKit agent

This is a Polkit agent for tauOS. It adds a prompt when trying to access Polkit actions that require authentication.

## Building

To build, use meson
```bash
meson builddir
meson compile -C builddir
```

## Installing

To install, run the following:
```bash
sudo meson install -C builddir
```