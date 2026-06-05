# kubectl-helper

A single sourceable shell file (`kubectl-helper.sh`) that adds short, namespace-aware
aliases and functions around `kubectl` for everyday cluster work — switching contexts
and namespaces, fuzzy-matching pods/deployments by substring, tailing logs, decoding
secrets, port-forwarding services, and pretty-printing cleaned-up YAML.

It is designed to be dropped into **any** bash/zsh environment, including ephemeral
debug containers (`kubectl debug`, exec'd pods, etc.). On source it bootstraps its two
optional dependencies — [`bat`](https://github.com/sharkdp/bat) and
[`kubectl-neat`](https://github.com/itaysk/kubectl-neat) — using whatever package
manager the host has (`apk`, `apt`, or `brew`), and degrades gracefully when they're
unavailable.

## Requirements

| Tool | Needed for | Notes |
|------|-----------|-------|
| `bash` or `zsh` | everything | the script refuses to load under other shells |
| `kubectl` | everything | must already be installed and configured |
| `jq` | `ks`, `kcm`, `kl` | not auto-installed; install it yourself if you use these |
| `kubectl-neat` | `kn` | **auto-installed** on source (direct binary download) |
| `bat` | nicer output from `kn`, `kcm` | **auto-installed** on source; falls back to `cat` if unavailable |

Auto-install requires one of `apk` / `apt` / `brew` on `PATH`. On systems without a
supported package manager, the bootstrap is skipped with a notice and the rest of the
helpers still load. If `bat` can't be installed, `kn` and `kcm` simply print plain
output via `cat`.

## Installation

Source it into your shell (add to `~/.zshrc` or `~/.bashrc` to make it permanent):

```sh
source <(curl -s https://k.yong.space)
```

On a successful load you'll see `Kubernetes shortcuts loaded`. Missing `bat` /
`kubectl-neat` are installed on first source; re-sourcing later is cheap.

## Aliases & functions

Most commands take a **substring** and match it against resource names in the current
namespace — e.g. `kl api` tails logs for the pod whose name contains `api`. Tab
completion is wired up for the relevant resource type of each command.

| Command | Usage | What it does |
|---------|-------|--------------|
| `k` | `k <args>` | Alias for `kubectl`. |
| `ns` | `ns` / `ns <namespace>` | With no args, prints the current namespace. With an argument, switches the current context to that namespace (and updates the `$ns` used by every other command). |
| `kc` | `kc` / `kc <context>` | With no args, lists kube contexts. With an argument, switches to that context and refreshes the active namespace. |
| `pod` | `pod <substr>` | Prints the name of the **first** pod matching the substring. Used internally by other commands, but handy on its own. |
| `kp` | `kp <substr>` | Lists pods matching the substring (with the header row). |
| `kpw` | `kpw <substr>` | Same as `kp` but **watches** (`-w`) for changes. |
| `kd` | `kd <substr>` | Lists deployments matching the substring. |
| `kn` | `kn <resource> <name>` | Fetches a resource and pretty-prints **cleaned-up** YAML via `kubectl neat` (strips managed fields, status noise, defaults), piped through `bat` (or `cat`). Completes `deploy`, `pod`, `svc`, `ingress`, `cj`. |
| `ks` | `ks` / `ks <name>` | With no args, lists secrets. With a name, dumps the secret's `data` **base64-decoded** as JSON (needs `jq`). |
| `kr` | `kr <deploy>` | Triggers a `rollout restart` of the named deployment. |
| `kcm` | `kcm` / `kcm <name>` | With no args, lists configmaps. With a name, dumps the configmap's `data` values, pretty-printed via `bat`/`cat` (needs `jq`). |
| `kb` | `kb <substr> [shell]` | Execs an interactive shell into the first matching pod (default `/bin/sh`; pass e.g. `kb api /bin/bash`). |
| `ke` | `ke <substr>` | Shows events for the first matching pod. |
| `kew` | `kew <substr>` | Same as `ke` but **watches** for new events. |
| `kl` | `kl <substr>` | Tails (`-f`, last 1000 lines) logs. If the substring is an exact pod name, tails just that pod; otherwise tails all pods sharing the matched pod's `app` label (or its first label) (needs `jq`). |
| `kf` | `kf <substr>` | Port-forwards to the first service matching the substring, forwarding its port to the same local port. |
| `kn-setup` | `kn-setup` | Re-runs the dependency bootstrap (install `bat` + `kubectl-neat`). Runs automatically on source; call manually to retry after fixing a package manager. |

### Namespace model

All commands operate on the namespace tracked in the `$ns` environment variable, which
is initialised from your current kube context on load and kept in sync by `ns` and `kc`.
Change namespaces with `ns <name>` and every subsequent command targets it — no need to
pass `-n` repeatedly.

## Notes

- `kubectl-neat` builds are published only for `linux`/`darwin` on `amd64`/`arm64`;
  other architectures skip the `kn` install with a notice.
- On Debian/Ubuntu the `bat` package installs the binary as `batcat`; the bootstrap
  symlinks it to `bat` on `PATH` so `kn`/`kcm` work transparently.
- Installs go to `/usr/local/bin` when running as root or with `sudo`, otherwise to
  `~/.local/bin` (added to `PATH`).
