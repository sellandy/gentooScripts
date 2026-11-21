# Gentoo Kernel Update with Nitrokey LUKS Support

Automated kernel build workflow for Gentoo Linux using `genkernel`, including Nitrokey-based LUKS unlocking support in the initramfs.

The scripts automate the preparation of the kernel configuration, compilation of the Nitrokey LUKS helper, integration of its runtime dependencies into the initramfs overlay, and the kernel/initramfs build.

## Features

- Kernel source selection via `eselect kernel`
- Automatic backup and restoration of the previous kernel configuration
- Configuration migration using `make olddefconfig`
- Configuration diff before compilation
- Automatic compilation of the Nitrokey LUKS helper
- Automatic detection and copying of required shared libraries
- Automatic detection and copying of the ELF interpreter
- Integration of a modified `initrd.scripts` into the genkernel initramfs
- Kernel and initramfs generation using `genkernel all`

## Requirements

- Gentoo Linux
- Bash
- `eselect`
- Linux kernel sources installed under `/usr/src`
- `genkernel`
- GCC / G++
- Git
- curl
- patch
- binutils (`readelf`)
- Standard system utilities (`ldd`, `install`, `cp`, `make`)
- Nitrokey device compatible with the NitroLUKS project
- LUKS-encrypted root filesystem

## Directory Structure

The scripts are installed in the following locations:

```text
/etc/
├── kernels/
│   ├── postbuild.d/
│   │   ├── 20-nitrokey.sh
│   │   └── create_lib.sh
│   └── nitro/
│       ├── bin/
│       │   └── nitro_luks
│       ├── etc/
│       │   ├── initrd.scripts
│       │   └── ld.so.conf.d/
│       ├── lib64/
│       │   └── ld-linux-x86-64.so.2
│       └── usr/
│           ├── lib64/
│           └── lib/gcc/
└── genkernel.conf
```

The kernel update script can be stored in a personal scripts directory, for example:

```text
~/scripts/kernel-update.sh
```

**Important:** Build scripts must not be placed in `/etc/bash/bashrc.d/`. That directory is intended for interactive Bash configuration and is loaded automatically when Bash starts.

## Configuration

### genkernel

The following setting must be configured in `/etc/genkernel.conf`:

```bash
INITRAMFS_OVERLAY="/etc/kernels/nitro"
```

This directory is used as the genkernel initramfs overlay.

### Nitrokey preparation

`20-nitrokey.sh` performs the following tasks:

1. Loads the genkernel configuration.
2. Validates the configured overlay path.
3. Creates a temporary build directory.
4. Downloads the NitroLUKS source code.
5. Compiles the `nitro_luks` helper.
6. Installs the binary into the initramfs overlay.
7. Executes `create_lib.sh`.
8. Downloads and applies the modified genkernel initrd script.
9. Places the modified script in the overlay.

The script uses the following NitroLUKS source:

https://github.com/amedeos/nitroluks

The initrd patch is retrieved from:

https://raw.githubusercontent.com/amedeos/amedeos.github.io/master/scripts/genkernel/initrd.scripts.patch

### Shared library handling

`create_lib.sh` automatically detects the shared library dependencies of the compiled `nitro_luks` binary using `ldd`.

It then:

- Checks for unresolved dependencies.
- Copies the required shared libraries into the overlay.
- Detects the ELF interpreter using `readelf`.
- Copies the interpreter to its original absolute path inside the overlay.

For example:

```text
/lib64/ld-linux-x86-64.so.2
```

is copied to:

```text
/etc/kernels/nitro/lib64/ld-linux-x86-64.so.2
```

This is required for dynamically linked executables to run inside the initramfs.

## Kernel Update Workflow

The main entry point is `kernel-update.sh`.

Run it with root privileges:

```bash
doas ./kernel-update.sh
```

The script performs the following steps:

1. Checks root privileges and required commands.
2. Asks the user to confirm that the Gentoo system is up to date.
3. Backs up the current kernel configuration.
4. Displays available kernel source versions using `eselect kernel list`.
5. Lets the user select the desired kernel source.
6. Changes the `/usr/src/linux` symlink.
7. Cleans the kernel build directory.
8. Restores the previous kernel configuration.
9. Runs `make olddefconfig`.
10. Displays configuration changes.
11. Asks for confirmation before compiling.
12. Executes `20-nitrokey.sh`.
13. Runs `genkernel all`.

Kernel configuration backups are stored in:

```text
/usr/src/.kernel_config_backups/
```

## Manual Build

The individual build steps can also be executed manually.

### 1. Select kernel sources

```bash
eselect kernel list
doas eselect kernel set <number>
```

### 2. Restore kernel configuration

```bash
doas cp /usr/src/.kernel_config_backups/<backup-file> \
    /usr/src/linux/.config
```

### 3. Update configuration

```bash
cd /usr/src/linux
doas make olddefconfig
```

### 4. Prepare Nitrokey initramfs overlay

```bash
doas /etc/kernels/postbuild.d/20-nitrokey.sh
```

### 5. Build kernel and initramfs

```bash
doas genkernel all
```

## Verification

After the build, verify that the Nitrokey overlay contains the expected files:

```bash
find /etc/kernels/nitro -type f | sort
```

Check the most important components:

```bash
test -x /etc/kernels/nitro/bin/nitro_luks \
    && echo "NitroLUKS binary: OK"

test -x /etc/kernels/nitro/lib64/ld-linux-x86-64.so.2 \
    && echo "ELF interpreter: OK"

test -f /etc/kernels/nitro/etc/initrd.scripts \
    && echo "Initrd script: OK"
```

Before rebooting, verify that:

- The new kernel was built successfully.
- The initramfs was generated successfully.
- The correct kernel and initramfs files are installed on the EFI partition.
- Secure Boot signatures are valid.
- The bootloader configuration points to the correct files.

## Secure Boot

Kernel and initramfs generation are handled by `genkernel`.

EFI installation and Secure Boot signing are intentionally not automated by this project. These steps depend on the local bootloader and signing configuration.

Verify the generated files and their signatures before rebooting.

## Troubleshooting

### Nitrokey helper is not executed

Check whether the binary exists:

```bash
ls -l /etc/kernels/nitro/bin/nitro_luks
```

### Missing shared libraries

Run:

```bash
doas /etc/kernels/postbuild.d/create_lib.sh
```

Check dependencies:

```bash
ldd /etc/kernels/nitro/bin/nitro_luks
```

No dependency should report `not found`.

### ELF interpreter missing

Check:

```bash
ls -l /etc/kernels/nitro/lib64/ld-linux-x86-64.so.2
```

### Build scripts execute when opening a shell

Make sure that `create_lib.sh` and `20-nitrokey.sh` are not located in:

```text
/etc/bash/bashrc.d/
```

They belong in:

```text
/etc/kernels/postbuild.d/
```

## Notes

- The initramfs overlay is deleted and recreated by `20-nitrokey.sh` on every build.
- Do not store persistent files inside `/etc/kernels/nitro/`.
- The kernel configuration backup is retained independently of the overlay.
- The scripts must be executed with root privileges.
- Always verify EFI installation and Secure Boot signing before rebooting.

## License

Add the license appropriate for your repository and the included scripts. The NitroLUKS project and the referenced initrd patch may have separate licensing terms.
