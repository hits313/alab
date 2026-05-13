# alab bash/zsh completion
# Install:
#   bash:  source ~/tools/android-lab/completions/alab.bash    (or symlink into /etc/bash_completion.d/)
#   zsh:   autoload -U bashcompinit && bashcompinit && source ~/tools/android-lab/completions/alab.bash

_alab_cmds="start stop screen snapshot doctor version frida-sync root setup magisk denylist denylist-add denylist-ls frida frida-stop burp-cert proxy-on proxy-off certs unpin unpin-frida unpin-full install pull-apk decompile strings manifest grep hunt screenshot logcat pull-data activities launch status help"

_alab_pkgs() {
  if command -v adb >/dev/null 2>&1; then
    adb shell 'pm list packages -3' 2>/dev/null | sed 's/^package://' | tr -d '\r'
  fi
}

_alab() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$_alab_cmds" -- "$cur") )
    return
  fi

  case "$prev" in
    hunt|pull-apk|pull-data|activities|denylist-add|unpin|unpin-frida|unpin-full|logcat|grep)
      COMPREPLY=( $(compgen -W "$(_alab_pkgs)" -- "$cur") ) ;;
    install|decompile|strings|manifest)
      COMPREPLY=( $(compgen -f -X '!*.apk' -- "$cur") ) ;;
    snapshot)
      COMPREPLY=( $(compgen -W "save load list" -- "$cur") ) ;;
    *) ;;
  esac
}
complete -F _alab alab
