#!/bin/bash
function _chat() {
  read -r -d '' help <<EOF
Chat with a language model\n
https://platform.openai.com/docs/api-reference/chat/create\n
Usage: chat.sh [OPTIONS] <PROMPT>\n
Arguments:
  <PROMPT>        The text to send to the model\n
Options:
  -m <MODEL>      Model to use [default: gpt-4o-mini]
  -s <SYSTEM>     System message to use [default: 'Be precise and concise.']
  -t <TOKENS>     Maximum tokens to generate [default: 1024]
  -d <FILE>       Dump headers to file
  -u              Unbuffered (streaming) output from the API
  -h              Print help\n
Environment Variables:
  OPENAI_API_KEY  Your OpenAI API key (required)
EOF

  local model='gpt-4o-mini'
  local system='Be precise and concise.'
  local accept='application/json'
  local max_tokens=1024
  local stream=false
  local dump_file=''

  while getopts "m:s:t:d:uh" opt ; do
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
      h)
        echo -e "$help" ; exit 0 ;;
      *)
        exit 1 ;;
    esac
  done

  shift $((OPTIND - 1))

  local prompt=${1:-''}
  local token=${OPENAI_API_KEY:-''}
  local url="https://api.openai.com/v1/chat/completions"

  if [[ -z $token ]] ; then
    echo "$0: OPENAI_API_KEY not set" >&2
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
    -H "Authorization: Bearer $token"
    -H 'Content-Type: application/json'
    -H "Accept: $accept"
  )

  local body='{
    "stream": '"$stream"',
    "model": "'$model'",
    "max_tokens": '"$max_tokens"',
    "messages":[
      { "role":"system", "content": "'$system'" },
      { "role": "user", "content": "'$prompt'" }
    ]
  }'

  trap 'echo "$0: Exiting..." >&2 ; exit 1' INT TERM

  if [[ $stream != true ]] ; then
    curl "${curl_opts[@]}" "${headers[@]}" -d "$body" "$url" \
    | jq -r '.choices[].message.content' \
    | bat -pp -l md --color=always
    exit 0
  fi

  # 1. Use `stdbuf -oL` to make `sed` line-buffered and remove the "data: " prefix
  # 2. Filter out the "[DONE]" line
  # 3. Extract the "content" field from the JSON and ignore null values
  # 4. Ignore the first empty string otherwise render empty strings as new lines,
  #    then flush immediately and ensure a final newline
  # 5. Render as Markdown (`bat` is always unbuffered)
  curl "${curl_opts[@]}" "${headers[@]}" -d "$body" "$url" \
  | stdbuf -oL sed --unbuffered 's/^data: //' \
  | grep -v --line-buffered '^\[DONE\]$' \
  | jq -r --unbuffered '.choices[].delta.content // empty' \
  | awk 'NR==1 && $0=="" { next } { if ($0=="") { print "" } else { printf "%s", $0 } fflush() } END { print "" }' \
  | bat -pp -l md --color=always
}

_chat "$@"
