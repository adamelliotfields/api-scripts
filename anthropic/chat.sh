#!/usr/bin/env bash
function _chat() {
  read -r -d '' help <<EOF
Chat with a language model\n
https://docs.anthropic.com/en/api/messages\n
Usage: chat.sh [OPTIONS] <PROMPT>\n
Arguments:
  <PROMPT>           The text to send to the model\n
Options:
  -m <MODEL>         Model to use [default: claude-3-5-haiku-20241022]
  -s <SYSTEM>        System message to use [default: 'Be precise and concise.']
  -t <TOKENS>        Maximum tokens to generate [default: 1024]
  -d <FILE>          Dump headers to file
  -u                 Unbuffered (streaming) output from the API
  -H                 Print help\n
Environment Variables:
  ANTHROPIC_API_KEY  Your Anthropic API key (required)
EOF

  local model='claude-3-5-haiku-20241022'
  local system='Be precise and concise.'
  local accept='application/json'
  local max_tokens=1024
  local print_help=false
  local stream=false
  local dump_file=''

  while getopts "m:s:t:d:uH" opt ; do
    case $opt in
      m)
        model="$OPTARG" ;;
      s)
        system="$OPTARG" ;;
      t)
        max_tokens="$OPTARG" ;;
      d)
        dump_file="$OPTARG" ;;
      u)
        stream=true ; accept='text/event-stream' ;;
      H)
        print_help=true ;;
      *)
        exit 1 ;;
    esac
  done

  shift $((OPTIND - 1))

  local prompt=${1:-''}
  local token=${ANTHROPIC_API_KEY:-''}
  local url='https://api.anthropic.com/v1/messages'

  if [[ $print_help == true ]] ; then
    echo -e "$help"
    exit 0
  fi

  if [[ -z $token ]] ; then
    echo "$0: ANTHROPIC_API_KEY not set" >&2
    exit 1
  fi

  if [[ -z $prompt ]] ; then
    echo "$0: You must enter a prompt" >&2
    exit 1
  fi

  local curl_opts=(-fsSL -X POST)
  if [[ -n $dump_file ]] ; then
    curl_opts+=(-D "$dump_file")
  fi

  local headers=(
    -H "x-api-key: $token"
    -H 'anthropic-version: 2023-06-01'
    -H 'content-type: application/json'
    -H "accept: $accept"
  )

  local body='{
    "stream": '"$stream"',
    "model": "'$model'",
    "system": "'$system'",
    "max_tokens": '"$max_tokens"',
    "messages":[{ "role": "user", "content": "'$prompt'" }]
  }'

  trap 'echo "$0: Exiting..." >&2 ; exit 1' INT TERM

  if [[ $stream != true ]] ; then
    curl "${curl_opts[@]}" "${headers[@]}" -d "$body" "$url" \
    | jq -r '.content[] | .text' \
    | bat -pp --language=md --color=always
    exit 0
  fi

  # TODO: not quite right
  curl "${curl_opts[@]}" "${headers[@]}" -d "$body" "$url" \
  | stdbuf -oL sed --unbuffered 's/^data: //' \
  | grep --line-buffered '"text_delta"' \
  | jq -r --unbuffered '.delta.text' \
  | awk '{printf "%s", $0}' \
  | bat -pp --language=md --color=always
}

_chat "$@"
