# arch-simple-installer
#### An extremely basic Arch Linux installer, configuring Arch, GRUB, NetworkManager, and iwd.

# Features
- Consistently reproducible
- Installs GRUBv2 portable
- Follows the Arch Wiki verbatim
- AMD and Intel microcode install
- NetworkManager + IWD install
- Supports SSH out of the box
- Bare minimum universal installation

# Comparing Alternatives
- [archfi](https://github.com/MatMoul/archfi): Bloated, large final install, lots of steps.
- [aui](https://github.com/helmuthdu/aui): Manual partitioning, over complicated, requires `unzip` package.
- [alis](https://picodotdev.github.io/alis/): Massive configuration file, does far more than the bare minimum.
- arch-simple-installer: Manual partitioning, only 10 manual configs, bare minimum install.

# Usage
1. Boot Arch Linux live image
2. Connect to the internet

```console
$ curl -Lo installer bit.ly/3VVIPDu
$ bash installer`
```
