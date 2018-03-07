#!/bin/sh
#
# The MIT License (MIT)
#
# Copyright (c) 2017-2018 Thomas "Ventto" Venriès <thomas.venries@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
DEBUG=false
LOG_DEBUG="/tmp/shun_$(date +"%Y-%m-%d-%H-%M-%S").log"

usage() {
    echo  'Usage: shun [-d] [-wmy] [-a] -b PATH
       shun [-d] [-wmy] [-a] -s PATH
       shun [-d] -c CODE

PATH is either a directory or a file path from a git repository.

Information:
  -h    prints this help and exits
  -v    prints the version and exits
  -d    writes debug logs into /tmp/shun_<date>.log
  -c CODE
        prints shellcheck CODE description

Shellcheck statistics (cannot be used in conjunction):
  -s PATH
        prints statistics per shellcheck code from PATH
  -b PATH
        prints invalid script line number per author from PATH

Data filters (can be used in conjunction with statistics options):
  -w    current week filter
  -m    current month filter
  -y    current year filter
  -a REGEXP
        filter authors who match a specific grep REGEXP
'

    exit "$1"
}

version() {
    echo 'Shun 0.1
Copyright (C) 2018 Thomas "Ventto" Venriès.'
    exit
}

banner() {
    # shellcheck disable=SC2016
    echo '
                 `:++++++++++++:.
               `oy-            -ss`
            -+o+:h`            `h/+o+-
         `+o/`   +o            +o   `:o+.
       `oo.       h. Wait    `h`      .oo`
       y+         :s  Please  o+         /h`
      .y+s:        y-        .h        -o+y-
     .y`  /s/      -y        s:      :s/` `y-
     s:     :s/`  ./h:......-d/-   /s:     -y
     o/      -yo++:``::::::::.`:++oy:      :y
     `oo/--/s/`                     /s+:-:oo`
        .--`                          `--.
'
}

upper_firstchar() {
    echo "$@" | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1'
}

log_debug() {
    $DEBUG && { echo "$@" >> "$LOG_DEBUG"; }
}

shellcheck_code_desc() {
    desc="$(grep -E "^${1}" /usr/share/shun/sc-codes)"
    if [ -z "$desc" ]; then
        printf '%s: No description.\n\n' "$1"
        exit 1
    fi
    printf '%s\n\n' "$desc"
}

datefilter() {
    _range="$1"
    _date="$2"

    case $_range in
        week) [ "$(date +%Y%V)" = "$(date -d @"${_date}" +%Y%V)" ]; return $?;;
        month) [ "$(date +%Y%m)" = "$(date -d @"${_date}" +%Y%m)" ]; return $?;;
        year) [ "$(date +%Y)" = "$(date -d @"${_date}" +%Y)" ]; return $?;;
    esac
}

extract_score() {
    _filename="$1"
    _mode="$2"
    _datefilter="$3"
    _author="$4"

    shc_output=$(shellcheck "$_filename")
    lines=$(echo "$shc_output" | sed -n 's%In .*\.sh line \([0-9]\+\):%\1%p')
    log_debug "---- filename: ${file}"
    for line in $lines; do
        blame=$(git -C "$(dirname "$_filename")" blame \
                    --line-porcelain "$_filename" -L "$line,$line")
        bwho=$(echo "$blame" | sed -n 's%^committer \(.*\)%\1%p')
        bdate=$(echo "$blame" | sed -n 's%^committer-time \([0-9]\+\)%\1%p')

        [ -n "$_author" ] && {
            log_debug "filter[${_author}]:${bwho}\\t"
        }
        [ -n "$_datefilter" ] && {
            log_debug "filter[${_datefilter}]:${bwho}\\t" \
                      "|$(date +'%Y-%m-%V')|$(date -d @"${bdate}" +'%Y-%m-%V')"
        }

        # Filters
        if [ -n "$_author" ] && ! echo "$bwho" \
            | grep -iE "$_author" >/dev/null 2>&1; then
            continue
        fi
        ! datefilter "$_datefilter" "$bdate" && continue

        case $_mode in
            blame)
                printf '%s\n' "${bwho}";;
            codes)
                printf '%s\n' "$(echo "$shc_output" \
                        | sed -n "/In .* line $line/,/In .* line/{//b;p}" \
                        | grep -oE '\-\- SC[0-9]+')";;
        esac
    done
    log_debug "-------------"
}

print_score() {
    _statmode="$1"
    _datefilter="$2"
    _scores="$3"

    case $_datefilter in
        week)  printf 'Date filter: Current week\n';;
        month) printf 'Date filter: Current month (%s)\n' "$(date +%B)";;
        year)  printf 'Date filter: Current year (%s)\n' "$(date +%Y)";;
    esac

    if [ "$_statmode" = 'blame' ]; then
        _scores=$(echo "$_scores" | cut -d'|' -f1)
        _scores=$(upper_firstchar "$_scores")
        printf 'Number of failed lines per author:\n\n'
    else
        printf 'Number of shellcheck codes:\n\n'
    fi

    printf '%s\n' "$(echo "$_scores" | sort | uniq -c | tail -n +2 | sort -rn)"
}

check_path() {
    _path="$1"

    if [ ! -d "$_path" ]; then
        if [ ! -f "$_path" ]; then
            echo "$_path: directory or file not found"; return 1
        fi
    fi

    if ! git -C "$_path" status >/dev/null 2>&1; then
        "${_path}: not a git repository"; return 1
    fi
}

main() {
    [ "$#" -eq 0 ] && usage 1
    while getopts 'hvdwmya:b:s:c:' opt; do
        case $opt in
            h) usage 0;;
            v) version;;
            d) DEBUG=true;;
            b) [ -n "$statmode" ] && usage 2
                statmode='blame'; path="${OPTARG}";;
            s) [ -n "$statmode" ] && usage 2
                statmode='codes'; path="${OPTARG}";;
            a) author="${OPTARG}";;
            w) datefilter='week';;
            m) datefilter='month';;
            y) datefilter='year';;
            c) shellcheck_code_desc "${OPTARG}"; exit;;
            \?) usage 2;;
            :)  usage 2;;
        esac
    done

    check_path "$path" || usage 2

    banner; printf 'Results...\n\n'

    # Statistics
    find "$path" -type f -name '*.sh' | {
        while IFS= read -r file; do
            score="$(extract_score "${file}" "$statmode" \
                                   "$datefilter" "$author")"
            [ -n "$score" ] && scores="${scores}\\n${score}"
        done

        if [ -n "$scores" ]; then
            print_score "$statmode" "$datefilter" "$scores"
        else
            echo "Shit ! No croissant for us..."
        fi
    }
}

main "$@"
