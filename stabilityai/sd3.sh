#!/usr/bin/env bash
function _sd3() {
  read -r -d '' help <<EOF
Generate an image from a text prompt with Stable Diffusion 3.\n
https://platform.stability.ai/docs/api-reference#tag/Generate/paths/~1v2beta~1stable-image~1generate~1sd3/post\n
Usage: sd3.sh [OPTIONS] <PROMPT>\n
Arguments:
  <PROMPT>              The text to send to the model\n
Options:
  -m <MODEL>            Model to use [default: sd3.5-large-turbo]
                        [possible values: sd3.5-large, sd3.5-large-turbo, sd3.5-medium, sd3-large, sd3-large-turbo, sd3-medium]
  -a <ASPECT_RATIO>     Aspect ratio of the image [default: 1:1]
                        [possible values: 16:9, 1:1, 21:9, 2:3, 3:2, 4:5, 5:4, 9:16, 9:21]
  -o <OUT_FILE>         File to save the image to [default: image.png]
  -g <GUIDANCE_SCALE>   Guidance scale [default: 1.0]
  -s <SEED>             Random seed to use [default: 0]
  -n <NEGATIVE_PROMPT>  Negative prompt to use (non-turbo models only)
  -d <DUMP_FILE>        Dump headers to file
  -h                    Print help\n
Environment Variables:
  STABILITY_API_KEY     Your Stability API key (required)
EOF

  local model='sd3.5-large-turbo'
  local aspect_ratio='1:1'
  local file='image.png'
  local cfg_scale=1
  local seed=0
  local negative_prompt=''
  local dump_file=''

  while getopts "m:a:o:g:s:n:d:h" opt ; do
    case $opt in
      m)
        model="$OPTARG" ;;
      a)
        aspect_ratio="$OPTARG" ;;
      o)
        file="$OPTARG" ;;
      g)
        cfg_scale="$OPTARG" ;;
      s)
        seed="$OPTARG" ;;
      n)
        negative_prompt="$OPTARG" ;;
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
  local token=${STABILITY_API_KEY:-''}
  local url="https://api.stability.ai/v2beta/stable-image/generate/sd3"

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
    -H 'Content-Type: multipart/form-data'
    -H 'Accept: image/*'
  )

  local form=(
    -F "prompt=$prompt"
    -F "aspect_ratio=$aspect_ratio"
    -F "model=$model"
    -F "cfg_scale=$cfg_scale"
    -F "seed=$seed"
    -F 'mode=text-to-image'
    -F 'output_format=png'
  )

  # Turbo models don't support negative prompt.
  if [[ $model != 'sd3.5-large-turbo' && $model != 'sd3-large-turbo' ]] ; then
    form+=(-F "negative_prompt=$negative_prompt")
  fi

  trap 'echo "$0: Exiting..." >&2 ; exit 1' INT TERM

  curl "${curl_opts[@]}" "${headers[@]}" "${form[@]}" "$url"

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

_sd3 "$@"
