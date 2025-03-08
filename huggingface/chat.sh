#!/usr/bin/env bash
function _chat() {
  read -r -d '' help <<EOF
Chat with a language model\n
https://huggingface.co/docs/api-inference/en/tasks/chat-completion\n
Usage: chat.sh [OPTIONS] <PROMPT>\n
Arguments:
  <PROMPT>     The text to send to the model\n
Options:
  -m <MODEL>   Model to use [default: HuggingFaceH4/zephyr-7b-beta]
  -s <SYSTEM>  System message to use [default: 'Be precise and concise.']
  -t <TOKENS>  Max tokens to generate [default: 1024]
  -d <FILE>    Dump headers to file
  -u           Unbuffered (streaming) output from the API
  -H           Print help\n
Environment Variables:
  HF_TOKEN     Your Hugging Face API token (required)
EOF

  local model='HuggingFaceH4/zephyr-7b-beta'
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
  local token=${HF_TOKEN:-''}
  local url="https://api-inference.huggingface.co/models/${model}/v1/chat/completions"

  if [[ $print_help == true ]] ; then
    echo -e "$help"
    exit 0
  fi

  if [[ -z $token ]] ; then
    echo "$0: HF_TOKEN not set" >&2
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
    -H "Accept: $accept"
    -H "Authorization: Bearer $token"
    -H 'Content-Type: application/json'
    -H 'X-Wait-For-Model: true'
    -H 'X-Use-Cache: false'
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
  # 3. Extract the "content" field from the JSON
  # 4. Output empty lines as new lines and flush immediately
  # 5. Render as Markdown (`bat` is always unbuffered)
  curl "${curl_opts[@]}" "${headers[@]}" -d "$body" "$url" \
  | stdbuf -oL sed --unbuffered 's/^data: //' \
  | grep -v --line-buffered '^\[DONE\]$' \
  | jq -r --unbuffered '.choices[].delta.content' \
  | awk '{ if ($0 == "") { print "" } else { printf "%s", $0 } fflush() }' \
  | bat -pp -l md --color=always
}

_chat "$@"
