#!/usr/bin/env bash
function _get_models() {
  read -r -d '' help <<EOF
Get a list of models available for use in the API or information about a specific model\n
https://platform.openai.com/docs/api-reference/models/list\n
Usage: get_models.sh [OPTIONS]\n
Options:
  -m <MODEL>      Model to use
  -d <FILE>       Dump headers to file
  -H              Print help\n
Environment Variables:
  OPENAI_API_KEY  Your OpenAI API key (required)
EOF

  local model=''
  local dump_file=''
  local print_help=false

  while getopts "m:d:H" opt ; do
    case $opt in
      m)
        model="$OPTARG" ;;
      d)
        dump_file="$OPTARG" ;;
      H)
        print_help=true ;;
      *)
        exit 1 ;;
    esac
  done

  shift $((OPTIND - 1))

  local token=${OPENAI_API_KEY:-''}
  local url="https://api.openai.com/v1/models"

  if [[ $print_help == true ]] ; then
    echo -e "$help"
    exit 0
  fi

  if [[ -z $token ]] ; then
    echo "$0: OPENAI_API_KEY not set" >&2
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
    -H "Authorization: Bearer $token"
    -H 'Accept: application/json'
  )

  trap 'echo "$0: Exiting..." >&2 ; exit 1' INT TERM

  curl "${curl_opts[@]}" "${headers[@]}" "$url" | jq
}

_get_models "$@"
