#!/usr/bin/env bash
function _text_to_image() {
  read -r -d '' help <<EOF
Generate an image from a text prompt.\n
https://huggingface.co/docs/api-inference/en/tasks/text-to-image\n
Usage: text_to_image.sh [OPTIONS] <PROMPT>\n
Arguments:
  <PROMPT>           The text to send to the model\n
Options:
  -a <ASPECT_RATIO>  Aspect ratio of the image [default: 1:1]
                     [possible values: 1:1, 16:9, 9:16, 7:4, 4:7, 12:5, 5:12]
  -m <MODEL>         Model to use [default: stabilityai/stable-diffusion-3.5-large-turbo]
  -o <OUT_FILE>      File to save the image to [default: image.jpg]
  -n <NEGATIVE>      Negative prompt to use
  -w <WIDTH>         Width of the image
  -h <HEIGHT>        Height of the image
  -g <GUIDANCE>      Guidance scale
  -i <STEPS>         Number of inference steps
  -s <SEED>          Random seed to use
  -d <DUMP_FILE>     Dump headers to file
  -h                 Print help\n
Environment Variables:
  HF_TOKEN           Your Hugging Face API token (required)
EOF

  local aspect_ratio='1:1'
  local width=1024
  local height=1024
  local model='stabilityai/stable-diffusion-3.5-large-turbo'
  local file='image.jpg'
  local negative=''
  local guidance=''
  local steps=''
  local seed=''
  local dump_file=''

  while getopts "a:m:o:n:g:i:s:d:h" opt ; do
    case $opt in
      a)
        aspect_ratio="$OPTARG" ;;
      m)
        model="$OPTARG" ;;
      o)
        file="$OPTARG" ;;
      n)
        negative="$OPTARG" ;;
      g)
        guidance="$OPTARG" ;;
      i)
        steps="$OPTARG" ;;
      s)
        seed="$OPTARG" ;;
      d)
        dump_file="$OPTARG" ;;
      h)
        echo -e "$help" ; exit 0 ;;
      *)
        exit 1 ;;
    esac
  done

  # Set dimensions based on aspect ratio.
  case $aspect_ratio in
    1:1)
      width=1024 ; height=1024 ;;
    16:9)
      width=1152 ; height=896  ;;
    9:16)
      width=896  ; height=1152 ;;
    7:4)
      width=1344 ; height=768  ;;
    4:7)
      width=768  ; height=1344 ;;
    12:5)
      width=1536 ; height=640  ;;
    5:12)
      width=640  ; height=1536 ;;
    *)
      echo "$0: Invalid aspect ratio '$aspect_ratio'" >&2 ; exit 1 ;;
  esac

  shift $((OPTIND - 1))

  local prompt=${1:-''}
  local token=${HF_TOKEN:-''}
  local url="https://api-inference.huggingface.co/models/${model}"

  if [[ -z $token ]] ; then
    echo "$0: HF_TOKEN not set" >&2
    exit 1
  fi

  if [[ -z $prompt ]] ; then
    echo "$0: You must enter a prompt" >&2
    exit 1
  fi

  local curl_opts=(-fsSL -X POST -o "$file")
  if [[ -n $dump_file ]] ; then
    curl_opts+=(-D "$dump_file")
  fi

  local headers=(
    -H "Authorization: Bearer $token"
    -H 'Content-Type: application/json'
    -H 'X-Wait-For-Model: true'
    -H 'X-Use-Cache: false'
    -H 'Accept: image/jpeg' # only jpeg is supported
  )

  local parameters=$(echo '{}' | jq \
  --arg negative "$negative" \
  --arg width "$width" \
  --arg height "$height" \
  --arg guidance "$guidance" \
  --arg steps "$steps" \
  --arg seed "$seed" \
  'if $negative != "" then . + {negative_prompt: $negative} else . end |
   if $width != "" then . + {width: ($width|tonumber)} else . end |
   if $height != "" then . + {height: ($height|tonumber)} else . end |
   if $guidance != "" then . + {guidance_scale: ($guidance|tonumber) } else . end |
   if $steps != "" then . + {num_inference_steps: ($steps|tonumber)} else . end |
   if $seed != "" then . + {seed: ($seed|tonumber)} else . end')

  local body='{
    "inputs": "'$prompt'",
    "parameters": '$parameters'
  }'

  trap 'echo "$0: Exiting..." >&2 ; exit 1' INT TERM

  curl "${curl_opts[@]}" "${headers[@]}" -d "$body" "$url"

  local status=$?
  if [[ $status -ne 0 ]] ; then
    echo "$0: Error generating image" >&2
    exit "$status"
  fi

  if [[ -f $file ]] ; then
    echo "Image saved to '$file'"
  else
    echo "$0: Error saving image" >&2
    exit 1
  fi
}

_text_to_image "$@"
