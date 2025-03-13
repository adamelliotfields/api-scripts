#!/usr/bin/env bash
function _account() {
  read -r -d '' help <<EOF
Get your account details\n
Usage: account.sh [OPTIONS]\n
Options:
  -d <FILE>          Dump headers to file
  -b                 Show balance
  -h                 Print help\n
Environment Variables:
  STABILITY_API_KEY  Your Stability API key (required)
EOF

  local show_balance=false
  local dump_file=''

  while getopts "d:bh" opt ; do
    case $opt in
      d)
        dump_file="$OPTARG" ;;
      b)
        show_balance=true ;;
      h)
        echo -e "$help" ; exit 0 ;;
      *)
        exit 1 ;;
    esac
  done

  shift $((OPTIND - 1))

  local url="https://api.stability.ai/v1/user"
  if [[ $show_balance == true ]] ; then
    url="$url/balance"
  else
    url="$url/account"
  fi

  local curl_opts=(-sSL -X GET)
  if [[ -n $dump_file ]] ; then
    curl_opts+=(-D "$dump_file")
  fi

  local token=${STABILITY_API_KEY:-''}
  if [[ -z $token ]] ; then
    echo "$0: STABILITY_API_KEY not set" >&2
    exit 1
  fi

  local headers=(
    -H "Authorization: Bearer $token"
    -H 'Accept: application/json'
  )

  trap 'echo "$0: Exiting..." >&2 ; exit 1' INT TERM

  curl "${curl_opts[@]}" "${headers[@]}" "$url" | jq
}

_account "$@"
