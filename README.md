# Heat Releases

Public binary distribution channel and Homebrew tap for Heat and MCP Builder.

This repository is intentionally not the Heat source repository. It contains
release metadata, the Homebrew formula, and public GitHub Release assets for
installing the packaged Heat toolchain.

## Install

```bash
brew tap nchantarotwong/heat-releases https://github.com/nchantarotwong/heat-releases
brew install heat
heat-mcp doctor-install
```

The installed commands are:

- `heatc` - the Heat compiler and full command surface.
- `heat-mcp` - the MCP Builder product entrypoint.

## Release Assets

Each release should publish:

- `heat-darwin-arm64.tar.gz`
- `heat-linux-arm64.tar.gz`
- `heat-linux-x86_64.tar.gz`
- `SHA256SUMS`

The Homebrew formula at `Formula/heat.rb` points at those release assets. Binary
artifacts are built, signed where applicable, and smoke-tested in the private
Heat build pipeline before they are copied here.

## Source Code

This repository does not distribute Heat source code. GitHub may show automatic
"Source code" archives for this repository on release pages; those archives
contain only this distribution repository's files, not the private Heat source
tree.

## License

The packaged Heat binaries and release artifacts are distributed under
`HEAT_BINARY_EULA.md`.

No open-source license is granted for the Heat binaries or private Heat source
code by this repository.
