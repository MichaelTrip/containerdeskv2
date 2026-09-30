#!/bin/sh

# Only interactive Bash shells support these completions and aliases.
if [ -n "${BASH_VERSION:-}" ]; then
    case $- in
        *i*)
            if [ -z "${XRDP_K8S_COMPLETION_LOADED:-}" ]; then
                XRDP_K8S_COMPLETION_LOADED=1
                if [ -r /usr/share/bash-completion/bash_completion ]; then
                    . /usr/share/bash-completion/bash_completion
                fi
                for completion in kubectl helm kubectx kubens argocd sofka fj; do
                    if [ -r "/etc/bash_completion.d/$completion" ]; then
                        . "/etc/bash_completion.d/$completion"
                    fi
                done
                unset completion
                alias k=kubectl
                if type __start_kubectl >/dev/null 2>&1; then
                    complete -o default -F __start_kubectl k
                fi
            fi
            ;;
    esac
fi
