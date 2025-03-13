#!/bin/bash
function _cli() {
  read -r -d '' help <<EOF
View the scripts in this repository from the command line\n
Usage: cli.sh [OPTIONS] [PROVIDER]\n
Arguments:
  [PROVIDER]  Optional provider to filter by\n
Options:
  -l          List providers
  -h          Print help
EOF

  local list_providers=0
  local bat_opts='-pp --color=always'
  local fd_opts=(-E .devcontainer -E .vscode)

  # print the file name with leading dot-slash on enter
  local fzf_opts=(
    --layout=reverse
    --preview="bat $bat_opts {}"
    --preview-window='wrap,right:75%'
    --bind='enter:execute(echo ./{})+abort'
  )

  while getopts ":lh" opt ; do
    case $opt in
      l)
        list_providers=1 ;;
      h)
        echo -e "$help" ; exit 0 ;;
      # opt will be set to `:` for missing arguments
      :)
        echo "$0: option requires an argument -- $OPTARG" >&2 ; exit 1 ;;
      # opt will be set to `?` for invalid options
      \?)
        echo "$0: illegal option -- $OPTARG" >&2 ; exit 1 ;;
    esac
  done

  # remove parsed options from positional parameters
  # use double parens for arithmetic
  shift $((OPTIND - 1))

  # list providers
  if [[ $list_providers -eq 1 ]] ; then
    fd_opts+=(--max-depth=1 --type=directory --exec=basename)
    fd "${fd_opts[@]}"
    exit 0
  fi

  # use min-depth=2 to filter out the root directory
  if [[ -z "$1" ]] ; then
    fd_opts+=(--min-depth=2 --type=file)
    fd "${fd_opts[@]}" | fzf "${fzf_opts[@]}"
    exit 0
  fi

  # ensure provider directory exists
  if [[ ! -d "$1" ]] ; then
    echo "$0: $1 is not a directory" >&2
    exit 1
  fi

  # use with-nth=2.. to skip the first segment (the provider)
  # to only show the last segment (the file) use with-nth=-1
  fd_opts+=(--search-path="$1" --type=file)
  fzf_opts+=(--delimiter='/' --with-nth=2..)
  fd "${fd_opts[@]}" | fzf "${fzf_opts[@]}"
  exit 0
}

_cli "$@"
