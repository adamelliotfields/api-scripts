#!/usr/bin/env bash
function _get_models() {
  read -r -d '' help <<EOF
Get a list of models available for use in the API or information about a specific model\n
https://docs.anthropic.com/en/api/models\n
Usage: get_models.sh [OPTIONS]\n
Options:
  -m <MODEL>         Model to use
  -d <FILE>          Dump headers to file
  -h                 Print help\n
Environment Variables:
  ANTHROPIC_API_KEY  Your Anthropic API key (required)
EOF

  local model=''
  local dump_file=''

  while getopts "m:d:h" opt ; do
    case $opt in
      m)
        model="$OPTARG" ;;
      d)
        dump_file="$OPTARG" ;;
      h)
        echo -e "$help" ; exit 0 ;;
      *)
        exit 1 ;;
    esac
  done

  shift $((OPTIND - 1))

  local token=${ANTHROPIC_API_KEY:-''}
  local url="https://api.anthropic.com/v1/models"

  if [[ -z $token ]] ; then
    echo "$0: ANTHROPIC_API_KEY not set" >&2
    exit 1
  fi

  if [[ -n $model ]] ; then
    url="$url/$model"
  fi

  local curl_opts=(-sSL -X GET)
  if [[ -n $dump_file ]] ; then
    curl_opts+=(-D "$dump_file")
  fi

  local headers=(
    -H "x-api-key: $token"
    -H 'anthropic-version: 2023-06-01'
    -H 'accept: application/json'
  )

  trap 'echo "$0: Exiting..." >&2 ; exit 1' INT TERM

  curl "${curl_opts[@]}" "${headers[@]}" "$url" | jq
}

_get_models "$@"
