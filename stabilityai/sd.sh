#!/usr/bin/env bash
function _sd() {
  read -r -d '' help <<EOF
Generate an image from a text prompt with Stable Diffusion 1.6.
Note that the 1.6 and XL APIs are different from the newer models.\n
https://platform.stability.ai/docs/api-reference#tag/SDXL-1.0-and-SD1.6/operation/textToImage\n
Usage: sd.sh [OPTIONS] <PROMPT>\n
Arguments:
  <PROMPT>           The text to send to the model\n
Options:
  -o <OUT_FILE>      File to save the image to [default: image.png]
  -w <WIDTH>         Width of the image [default: 512]
  -h <HEIGHT>        Height of the image [default: 512]
  -g <GUIDANCE>      Guidance scale [default: 7]
  -i <STEPS>         Number of inference steps [default: 30]
  -s <SEED>          Random seed to use [default: 0]
  -d <DUMP_FILE>     Dump headers to file
  -H                 Print help\n
Environment Variables:
  STABILITY_API_KEY  Your Stability API key (required)
EOF

  local file='image.png'
  local width=512
  local height=512
  local guidance=7
  local steps=30
  local seed=0
  local dump_file=''
  local print_help=false

  while getopts "o:w:h:g:i:s:d:H" opt ; do
    case $opt in
      o)
        file="$OPTARG" ;;
      w)
        width="$OPTARG" ;;
      h)
        height="$OPTARG" ;;
      g)
        guidance="$OPTARG" ;;
      i)
        steps="$OPTARG" ;;
      s)
        seed="$OPTARG" ;;
      d)
        dump_file="$OPTARG" ;;
      H)
        print_help=true ;;
      *)
        exit 1 ;;
    esac
  done

  shift $((OPTIND - 1))

  local prompt=${1:-''}
  local token=${STABILITY_API_KEY:-''}
  local url="https://api.stability.ai/v1/generation/stable-diffusion-v1-6/text-to-image"

  if [[ $print_help == true ]] ; then
    echo -e "$help"
    exit 0
  fi

  if [[ -z $token ]] ; then
    echo "$0: STABILITY_API_KEY not set" >&2
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

  # For multiple samples, accept application/json to get an array of base64 encoded images.
  local headers=(
    -H "Authorization: Bearer $token"
    -H 'Content-Type: application/json'
    -H 'Accept: image/png'
  )

  # Dimensions must be between 320 and 1536 and divisible by 64.
  # Steps over 30 cost more credits.
  # Use `0` for random seed.
  local body='{
    "text_prompts": [{ "text": "'$prompt'", "weight": 1 }],
    "width": '"$width"',
    "height": '"$height"',
    "seed": '"$seed"',
    "steps": '"$steps"',
    "cfg_scale": '"$guidance"',
    "clip_guidance_preset": "NONE",
    "sampler": "K_DPMPP_2M",
    "style_preset": "enhance",
    "samples": 1
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

_sd "$@"
