# Release

This repository publishes release assets through `.github/workflows/release.yml`.

The workflow builds and uploads:

- macOS arm64 `.dmg`
- Windows portable `.zip`
- Linux x86_64 `.AppImage`

## Trigger

The release workflow runs when you push a tag that starts with `v`.

Example:

```bash
git tag v0.1.1
git push origin v0.1.1
```

You can also run the workflow manually from the GitHub Actions UI and provide an existing tag through the `ref` input.

For a dry run against a pre-release tag, use something like:

```bash
git tag v0.1.1-rc1
git push origin v0.1.1-rc1
```

## macOS Runner

The macOS job is designed for a self-hosted Apple Silicon Mac mini with the default GitHub runner labels:

- `self-hosted`
- `macOS`
- `ARM64`

### Required software on the Mac mini

- Xcode command line tools
- `cmake`
- `ninja`
- a working `vcpkg` checkout
- the Qt/toolchain environment already used for local macOS packaging
- a self-hosted GitHub Actions runner registered to this repository or organization

### Required signing state on the Mac mini

- `Developer ID Application` certificate installed in the login keychain
- matching private key present in the same keychain
- `notarytool` credentials stored in Keychain

## GitHub repository configuration

Set these repository-level values before running the workflow.

### Variables

- `MACOS_VCPKG_ROOT`
  - absolute path to the `vcpkg` checkout on the self-hosted Mac mini
  - example: `/Users/yongsheng/repos/vcpkg`

### Secrets

- `MACOS_CODESIGN_IDENTITY`
  - full signing identity string
  - example: `Developer ID Application: Potafree, LLC (DKSW9646HG)`
- `MACOS_NOTARY_PROFILE`
  - keychain profile name created with `xcrun notarytool store-credentials`
  - example: `shinsoku-notary`

## Runner setup

On the Mac mini, install and configure a self-hosted GitHub Actions runner for this repository.

Keep the default labels enabled so the workflow can target:

- `self-hosted`
- `macOS`
- `ARM64`

The release workflow assumes the runner account has access to:

- the login keychain that holds the `Developer ID Application` certificate
- the matching private key
- the stored `notarytool` profile

## Packaging paths

### macOS

The workflow calls:

```bash
cmake --build build-release-macos --config Release --target package_macos_dmg
```

The local packaging script supports:

- unsigned packaging
- signed packaging
- signed + notarized packaging

depending on whether the expected environment variables are present.

### Windows

The workflow uses a GitHub-hosted `windows-2022` runner, installs prebuilt Qt, installs non-Qt dependencies through `vcpkg`, then calls:

```powershell
cmake --build build-release-windows --config Release --target package_windows_portable
```

### Linux

The workflow uses a GitHub-hosted `ubuntu-24.04` runner, installs the required autotools, X11/XCB/EGL, Wayland/PulseAudio, and Qt 6 system packages, installs the non-Qt dependencies through `vcpkg`, builds the release binary, then packages it as an AppImage with `linuxdeploy`.

## Notes

- The release workflow assumes tags are the source of truth for release versioning.
- Asset names are normalized from the pushed tag name.
- macOS signing and notarization happen only on the self-hosted Mac mini.
- Windows and Linux builds use GitHub-hosted runners and upload unsigned artifacts to the same GitHub Release.
- This repository currently uses `vcpkg.json` without a checked-in baseline, so dependency resolution can still drift over time unless you pin the vcpkg checkout used by CI.
