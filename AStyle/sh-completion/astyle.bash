_astyle() {
    local IFS=$' \t\n'
    local args cur prev cmd opts arg
    args=("${COMP_WORDS[@]}")
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--style --indent --attach-namespaces --attach-classes --attach-inlines --attach-extern-c --attach-closing-while --indent-classes --indent-modifiers --indent-switches --indent-cases --indent-namespaces --indent-after-parens --indent-continuation --indent-labels --indent-preproc-block --indent-preproc-cond --indent-preproc-define --indent-col1-comments --min-conditional-indent --max-continuation-indent --break-blocks --pad-oper --pad-comma --pad-negation --pad-include --pad-paren --pad-first-paren-out --pad-header --pad-brackets --pad-semicolon --delete-empty-lines --fill-empty-lines --align-pointer --align-reference --break-closing-braces --break-elseifs --break-one-line-headers --add-braces --add-one-line-braces --remove-braces --remove-braces=one-line --break-return-type --attach-return-type --keep-one-line-blocks --keep-one-line-statements --convert-tabs --close-templates --remove-comment-prefix --max-code-length --max-code-length-mode --break-after-logical --mode --line-between-members --pad-method-prefix --pad-return-type --pad-param-type --align-method-colon --pad-method-colon --suffix --recursive --dry-run --error-on-changes --exclude --ignore-exclude-errors --ignore-exclude-errors-x --errors-to-stdout --preserve-date --verbose --formatted --quiet --lineend --options --project --ascii --version --help --html --stdin --stdout --squeeze-lines --squeeze-ws --preserve-ws --indent-lambda --accept-empty-list"

    case "$prev" in
        --style)
            COMPREPLY=($(compgen -W "allman java kr stroustrup whitesmith vtk ratliff gnu linux horstmann 1tbs google mozilla webkit pico lisp none" -- "$cur"))
            return 0
            ;;
        --indent)
            COMPREPLY=($(compgen -W "spaces tab force-tab force-tab-x none" -- "$cur"))
            return 0
            ;;
        --indent-continuation)
            COMPREPLY=($(compgen -W "0 1 2 3 4" -- "$cur"))
            return 0
            ;;
        --min-conditional-indent)
            COMPREPLY=($(compgen -W "0 1 2 3" -- "$cur"))
            return 0
            ;;
        --max-continuation-indent)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
        --break-blocks)
            COMPREPLY=($(compgen -W "all" -- "$cur"))
            return 0
            ;;
        --break-elseifs)
            COMPREPLY=($(compgen -W "no-indent" -- "$cur"))
            return 0
            ;;
        --pad-negation)
            COMPREPLY=($(compgen -W "before" -- "$cur"))
            return 0
            ;;
        --pad-include)
            COMPREPLY=($(compgen -W "none" -- "$cur"))
            return 0
            ;;
        --pad-paren)
            COMPREPLY=($(compgen -W "in out none" -- "$cur"))
            return 0
            ;;
        --pad-brackets)
            COMPREPLY=($(compgen -W "in out none" -- "$cur"))
            return 0
            ;;
        --pad-semicolon)
            COMPREPLY=($(compgen -W "none" -- "$cur"))
            return 0
            ;;
        --break-return-type)
            COMPREPLY=($(compgen -W "decl" -- "$cur"))
            return 0
            ;;
        --attach-return-type)
            COMPREPLY=($(compgen -W "decl" -- "$cur"))
            return 0
            ;;
        --pad-method-prefix)
            COMPREPLY=($(compgen -W "none" -- "$cur"))
            return 0
            ;;
        --pad-return-type)
            COMPREPLY=($(compgen -W "none" -- "$cur"))
            return 0
            ;;
        --pad-param-type)
            COMPREPLY=($(compgen -W "none" -- "$cur"))
            return 0
            ;;
        --align-pointer)
            COMPREPLY=($(compgen -W "type middle name" -- "$cur"))
            return 0
            ;;
        --align-reference)
            COMPREPLY=($(compgen -W "none type middle name" -- "$cur"))
            return 0
            ;;
        --max-code-length)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
        --max-code-length-mode)
            COMPREPLY=($(compgen -W "code total ignore-side-comments" -- "$cur"))
            return 0
            ;;
        --mode)
            COMPREPLY=($(compgen -W "c java cs objc js gsc ghc" -- "$cur"))
            return 0
            ;;
        --line-between-members)
            COMPREPLY=($(compgen -W "all" -- "$cur"))
            return 0
            ;;
        --pad-method-colon)
            COMPREPLY=($(compgen -W "none all after before" -- "$cur"))
            return 0
            ;;
        --suffix)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
        --exclude)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
        --lineend)
            COMPREPLY=($(compgen -W "windows linux macold" -- "$cur"))
            return 0
            ;;
        --options)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
        --project)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
        --stdin)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
        --stdout)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
        --squeeze-lines)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
    esac

    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _astyle -o bashdefault -o default astyle
