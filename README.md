# Distrobox

[Distrobox](https://github.com/89luca89/distrobox) packed for
[onelf](https://github.com/QaidVoid/onelf) packages. The scripts are
upstream's and its [documentation](https://github.com/89luca89/distrobox/tree/main/docs)
describes them; this repository only repacks them into one file that
runs on hosts with nothing installed.

| | |
|---|---|
| Description | A tool to manage containers on Linux |
| Upstream | <https://github.com/89luca89/distrobox> |
| License | GPL-3.0-only |

## The repack

- Ships upstream's POSIX shell scripts as they publish; there is
  nothing to compile. The shell releases are the stable line, the Go
  rewrite's releases are all pre-releases.
- Carries one host binary: curl, the only tool outside POSIX and
  coreutils the scripts call, for `create --compatibility`. The
  `distrobox-run` launcher puts bin/ ahead of the host's PATH and
  keeps the caller's working directory.
- Needs a container manager on PATH: distrobox detects it with
  `command -v`, and the [podman](https://github.com/onelf-pkgs/podman)
  package installs itself as `podman`. `create` mounts the tree's
  `distrobox-init` into the container as `/usr/bin/entrypoint`, so the
  tree has to stay reachable for as long as the container lives, the
  same property the podman package's namespace handling secures.
