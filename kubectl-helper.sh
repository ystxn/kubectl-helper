# Kubernetes Stuff
_CURRENT_SHELL=$(ps -p $$ -o comm=)
case "$_CURRENT_SHELL" in zsh|bash) ;; *) echo "k8s: requires bash or zsh" >&2; return 2>/dev/null || exit 1 ;; esac

export ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
export ns=${ns:-default}
alias k=kubectl

eval "$(k completion $_CURRENT_SHELL)"

case "$_CURRENT_SHELL" in
  zsh)
    _k8s_completion() {
      local -a resources
      resources=($(kubectl get $1 -n $ns --no-headers | awk '{print $1}'))
      _describe $1 resources
    }
    compdef '_k8s_completion svc' kf
    compdef '_k8s_completion deploy' kd
    compdef '_k8s_completion deploy' kr
    compdef '_k8s_completion cm' kcm
    compdef '_k8s_completion secret' ks
    compdef '_k8s_completion pod' kp
    compdef '_k8s_completion pod' kpw
    compdef '_k8s_completion pod' ke
    compdef '_k8s_completion pod' kew
    compdef '_k8s_completion pod' kb
    compdef '_k8s_completion pod' kl
    compdef '_k8s_completion deploy,pod,svc,ingress,cj' kn
    _k8s_context_completion() {
      local -a contexts
      contexts=($(kubectl config get-contexts -o name))
      _describe contexts contexts
    }
    compdef '_k8s_context_completion' kc
    ;;
  bash)
    _k8s_completion() {
      local resources
      resources=$(kubectl get $1 -n $ns --no-headers 2>/dev/null | awk '{print $1}')
      COMPREPLY=($(compgen -W "$resources" -- "${COMP_WORDS[COMP_CWORD]}"))
    }
    _k8s_complete_svc() { _k8s_completion svc; }
    _k8s_complete_deploy() { _k8s_completion deploy; }
    _k8s_complete_cm() { _k8s_completion cm; }
    _k8s_complete_secret() { _k8s_completion secret; }
    _k8s_complete_pod() { _k8s_completion pod; }
    _k8s_context_completion() {
      local contexts
      contexts=$(kubectl config get-contexts -o name 2>/dev/null)
      COMPREPLY=($(compgen -W "$contexts" -- "${COMP_WORDS[COMP_CWORD]}"))
    }
    complete -F _k8s_complete_svc kf
    complete -F _k8s_complete_deploy kd kr
    complete -F _k8s_complete_cm kcm
    complete -F _k8s_complete_secret ks
    complete -F _k8s_complete_pod kp kpw ke kew kb kl
    complete -F _k8s_context_completion kc
    ;;
esac

_kn_pkgmgr() { for m in apk apt-get brew; do command -v "$m" >/dev/null 2>&1 && { echo "$m"; return; }; done; return 1; }
_kn_sudo() {
  if [ "$(id -u 2>/dev/null)" = 0 ] || ! command -v sudo >/dev/null 2>&1; then "$@"; else sudo "$@"; fi
}
_kn_pm_install() {
  case "$(_kn_pkgmgr)" in
    apk)     _kn_sudo apk add --no-cache "$@" ;;
    apt-get) _kn_sudo apt-get update -qq && _kn_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" ;;
    brew)    brew install "$@" ;;
    *) return 1 ;;
  esac
}
_kn_bindir() {
  if [ "$(id -u 2>/dev/null)" = 0 ] || command -v sudo >/dev/null 2>&1; then echo /usr/local/bin
  else mkdir -p "$HOME/.local/bin" 2>/dev/null && echo "$HOME/.local/bin"; fi
}
_kn_addpath() { case ":$PATH:" in *":$1:"*) ;; *) export PATH="$1:$PATH" ;; esac; }
_kn_ensure_bat() {
  command -v bat >/dev/null 2>&1 && return 0
  command -v batcat >/dev/null 2>&1 || _kn_pm_install bat || return 1
  command -v bat >/dev/null 2>&1 && return 0
  local d; d=$(_kn_bindir) || return 1
  _kn_sudo ln -sf "$(command -v batcat)" "$d/bat" && _kn_addpath "$d"
  command -v bat >/dev/null 2>&1
}
_kn_ensure_neat() {
  command -v kubectl-neat >/dev/null 2>&1 && return 0
  command -v curl >/dev/null 2>&1 || _kn_pm_install curl ca-certificates || _kn_pm_install curl || return 1
  command -v tar  >/dev/null 2>&1 || _kn_pm_install tar || return 1
  local d os arch tmp rc; d=$(_kn_bindir) || return 1
  os="$(uname | tr '[:upper:]' '[:lower:]')"
  case "$(uname -m)" in
    x86_64|amd64)  arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "kn: no kubectl-neat build for arch $(uname -m)" >&2; return 1 ;;
  esac
  tmp="$(mktemp -d)" || return 1
  curl -fsSL "https://github.com/itaysk/kubectl-neat/releases/latest/download/kubectl-neat_${os}_${arch}.tar.gz" \
    | tar -xz -C "$tmp" 2>/dev/null \
    && _kn_sudo cp "$tmp/kubectl-neat" "$d/kubectl-neat" && _kn_sudo chmod 0755 "$d/kubectl-neat"
  rc=$?; rm -rf "$tmp"
  [ $rc -eq 0 ] && _kn_addpath "$d"
  command -v kubectl-neat >/dev/null 2>&1
}
_kn_pager() {
  if command -v bat >/dev/null 2>&1; then bat --style=plain -l=yaml --paging=never; else cat; fi
}
_kn_ensure_jq() { command -v jq >/dev/null 2>&1 || _kn_pm_install jq; }
kn-setup() {
  _kn_pkgmgr >/dev/null || { echo "kn-setup: no supported package manager (apk/apt/brew); skipping" >&2; return 1; }
  _kn_ensure_bat  || echo "kn-setup: bat unavailable; kn/kcm will fall back to cat" >&2
  _kn_ensure_jq   || echo "kn-setup: could not install jq; ks/kcm/kl need it" >&2
  _kn_ensure_neat || echo "kn-setup: could not install kubectl-neat" >&2
}
kn-setup

unalias ns kc pod kp kpw kd kn ks kr kcm kb ke kew kl kf 2>/dev/null
ns() { [ $# -eq 0 ] && echo "Current namespace: $ns" || { export ns=$1; k config set-context --current --namespace=$1; }; }
kc() { [ $# -eq 0 ] && k config get-contexts || { k config use-context $1; export ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null); export ns=${ns:-default}; }; }
pod() { k get pods -n $ns | awk "/$1/{print \$1}" | head -1; }
kp() { k get pods -n $ns | awk "NR==1 || /$1/"; }
kpw() { k get pods -n $ns -w | awk "NR==1 || /$1/"; }
kd() { k get deploy -n $ns | awk "NR==1 || /$1/"; }
kn() { k neat get -- "$@" -n "$ns" | _kn_pager; }
ks() { [ $# -eq 0 ] && k get secrets -n $ns || k get secret -n $ns $1 -o json|jq '.data|map_values(@base64d)'; }
kr() { k rollout restart deployment/$1 -n $ns; }
kcm() { [ $# -ne 1 ] && k get cm || k get cm $1 -o json | jq -r '.data[]' | sed 's/^"//g' | _kn_pager; }
kb() { p=$(pod $1) && [ -n "$p" ] && k exec -n $ns -it $p -- ${2:-/bin/sh} || echo "Pod not found"; }
ke() { p=$(pod $1) && [ -n "$p" ] && k get event -n $ns --field-selector involvedObject.name=$p || echo "Pod not found"; }
kew() { p=$(pod $1) && [ -n "$p" ] && k get event -n $ns --field-selector involvedObject.name=$p -w || echo "Pod not found"; }
kl() {
  p=$(pod $1)
  if [ "$p" = "$1" ]; then
    echo "Tailing logs for pod: $p in namespace: $ns"
    k logs -n $ns "$p" --tail=1000 -f
    return
  fi
  labels=$(k get pod $p -n $ns -o jsonpath="{.metadata.labels}")
  selector=$(echo $labels | jq -r 'to_entries | .[] | select(.key=="app") | "\(.key)=\(.value)"' 2>/dev/null)
  if [ -z "$selector" ]; then
    selector=$(echo $labels | jq -r 'to_entries | .[0] | "\(.key)=\(.value)"' 2>/dev/null)
  fi
  echo "Tailing logs for pods with selector: $selector in namespace: $ns"
  k logs -n $ns -l $selector --tail=1000 -f
}
kf() { p=$(k get svc -n $ns | awk "/$1/{print \$1,\$5}") && port=$(echo $p|grep -o '[0-9]\+'|head -1) && svc=$(echo $p|cut -d' ' -f1|head -1) && k port-forward svc/$svc $port:$port; }

echo "Kubernetes shortcuts loaded"
