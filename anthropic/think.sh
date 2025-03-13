#!/usr/bin/env bash
function _think() {
  read -r -d '' help <<EOF
Include a thinking content block in the response. Requires a minimum budget of
1024 tokens.\n
https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking\n
Usage: think.sh [OPTIONS] <PROMPT>\n
Arguments:
  <PROMPT>           The text to send to the model\n
Options:
  -s <SYSTEM>        System message to use [default: 'Be precise and concise.']
  -t <TOKENS>        Maximum tokens to generate [default: 2048]
  -b <BUDGET>        Budget for thinking tokens [default: 1024]
  -d <FILE>          Dump headers to file
  -h                 Print help\n
Environment Variables:
  ANTHROPIC_API_KEY  Your Anthropic API key (required)
EOF

  # only supported model for now
  local MODEL='claude-3-7-sonnet-20250219'

  local system='Be precise and concise.'
  local max_tokens=2048
  local budget_tokens=1024
  local dump_file=''

  while getopts "s:t:b:d:h" opt ; do
    case $opt in
      s)
        system="$OPTARG" ;;
      t)
        max_tokens="$OPTARG" ;;
      b)
        budget_tokens="$OPTARG" ;;
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
  local url='https://api.anthropic.com/v1/messages'

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
    -H 'accept: application/json'
  )

  local body='{
    "stream": false,
    "model": "'$MODEL'",
    "system": "'$system'",
    "max_tokens": '"$max_tokens"',
    "messages":[{ "role": "user", "content": "'$prompt'" }],
    "thinking": {
      "type": "enabled",
      "budget_tokens": '"$budget_tokens"'
    }
  }'

  trap 'echo "$0: Exiting..." >&2 ; exit 1' INT TERM

  local response=$(curl "${curl_opts[@]}" "${headers[@]}" -d "$body" "$url")
  local bat_opts=(-pp --language=md --color=always)

  # print thoughts, wrapped in tags, indented 2 spaces
  echo '<thinking>'
  echo "$response" | jq -r '.content[] | .thinking // empty' | sed 's/^/  /' | bat "${bat_opts[@]}"
  echo '</thinking>'
  echo ''

  # print text
  echo "$response" | jq -r '.content[] | .text // empty' | bat "${bat_opts[@]}"
}

_think "$@"
