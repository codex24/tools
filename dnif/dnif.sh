dnif () {
    # Recursively list a file from PWD up the directory tree to root
    [[ -n $1 ]] || { echo "dnif [ls-opts] name"; return 1; }
    local THERE=$PWD RC=2
    while [[ $THERE != / ]]
        do [[ -e $THERE/${2:-$1} ]] && { ls ${2:+$1} $THERE/${2:-$1}; RC=0; }
            THERE=$(dirname $THERE)
        done
    [[ -e $THERE/${2:-$1} ]] && { ls ${2:+$1} /${2:-$1}; RC=0; }
    return $RC
}
