#!/usr/bin/env bash
function _sdxl() {
  read -r -d '' help <<EOF
Generate an image from a text prompt with Stable Diffusion XL 1.0.
Note that the 1.6 and XL APIs are different from the newer models.\n
https://platform.stability.ai/docs/api-reference#tag/SDXL-1.0-and-SD1.6/operation/textToImage\n
Usage: sdxl.sh [OPTIONS] <PROMPT>\n
Arguments:
  <PROMPT>           The text to send to the model\n
Options:
  -a <ASPECT_RATIO>  Aspect ratio of the image [default: 1:1]
                     [possible values: 1:1, 16:9, 9:16, 7:4, 4:7, 12:5, 5:12]
  -o <OUT_FILE>      File to save the image to [default: image.png]
  -g <GUIDANCE>      Guidance scale [default: 7]
  -i <STEPS>         Number of inference steps [default: 30]
  -s <SEED>          Random seed to use [default: 0]
  -d <DUMP_FILE>     Dump headers to file
  -h                 Print help\n
Environment Variables:
  STABILITY_API_KEY  Your Stability API key (required)
EOF

  local aspect_ratio='1:1'
  local width=1024
  local height=1024
  local file='image.png'
  local guidance=7
  local steps=30
  local seed=0
  local dump_file=''

  while getopts "a:o:g:i:s:d:h" opt ; do
    case $opt in
      a)
        aspect_ratio="$OPTARG" ;;
      o)
        file="$OPTARG" ;;
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
  local token=${STABILITY_API_KEY:-''}
  local url="https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image"

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
    exit 1
  fi

  if [[ -f $file ]] ; then
    echo "Image saved to '$file'"
  else
    echo "$0: Error saving image" >&2
    exit 1
  fi
}

_sdxl "$@"
