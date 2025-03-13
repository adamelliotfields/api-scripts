#!/usr/bin/env bash
function _count_tokens() {
  read -r -d '' help <<EOF
Count the number of tokens in an input\n
https://docs.anthropic.com/en/api/messages-count-tokens\n
Usage: count_tokens.sh [OPTIONS] <PROMPT>\n
Arguments:
  <PROMPT>           The text to count tokens for\n
Options:
  -m <MODEL>         The model to use [default: claude-3-5-haiku-20241022]
  -s <SYSTEM>        The system message to use [default: 'Be precise and concise.']
  -d <FILE>          Dump headers to file
  -h                 Print help\n
Environment Variables:
  ANTHROPIC_API_KEY  Your Anthropic API key (required)
EOF

  local model='claude-3-5-haiku-20241022'
  local system='Be precise and concise.'
  local dump_file=''

  while getopts "m:s:d:h" opt ; do
    case $opt in
      m)
        model="$OPTARG" ;;
      s)
        system="$OPTARG" ;;
      d)
        dump_file="$OPTARG" ;;
      h)
        echo -e "$help" ; exit 0 ;;
      *)
        exit 1 ;;
    esac
  done

  shift $((OPTIND - 1))

  local prompt=${1:-''}
  local token=${ANTHROPIC_API_KEY:-''}
  local url='https://api.anthropic.com/v1/messages/count_tokens'

  if [[ -z $token ]] ; then
    echo "$0: ANTHROPIC_API_KEY not set" >&2
    exit 1
  fi

  if [[ -z $prompt ]] ; then
    echo "$0: You must enter a prompt" >&2
    exit 1
  fi

  local curl_opts=(-sSL -X POST)
  if [[ -n $dump_file ]] ; then
    curl_opts+=(-D "$dump_file")
  fi

  local headers=(
    -H "x-api-key: $token"
    -H 'anthropic-version: 2023-06-01'
    -H 'content-type: application/json'
    -H 'accept: application/json'
  )

  local body='{
    "model": "'$model'",
    "system": "'$system'",
    "messages":[{ "role": "user", "content": "'$prompt'" }]
  }'

  trap 'echo "$0: Exiting..." >&2 ; exit 1' INT TERM

  curl "${curl_opts[@]}" "${headers[@]}" -d "$body" "$url" | jq
}

_count_tokens "$@"
