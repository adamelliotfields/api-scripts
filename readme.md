# api-scripts

A collection of Bash scripts for interacting with various API providers.

## Installation

You need some popular Rust/Go/C programs:

```sh
apt install bat fd-find fzf jq

# or

brew install bat fd fzf jq
```

## Setup

Ensure each provider has the appropriate environment variable set:

```sh
export HF_TOKEN=hf_...
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-...
export STABILITY_API_KEY=sk-...
```

## Usage

Each script is self-contained and executable with `getopts` for portability. All use `-h` for help, for example:

```
$ ./openai/chat.sh -h

Chat with a language model

https://platform.openai.com/docs/api-reference/chat/create

Usage: chat.sh [OPTIONS] <PROMPT>

Arguments:
  <PROMPT>        The text to send to the model

Options:
  -m <MODEL>      Model to use [default: gpt-4o-mini]
  -s <SYSTEM>     System message to use [default: 'Be precise and concise.']
  -t <TOKENS>     Maximum tokens to generate [default: 1024]
  -d <FILE>       Dump headers to file
  -u              Unbuffered (streaming) output from the API
  -h              Print help

Environment Variables:
  OPENAI_API_KEY  Your OpenAI API key (required)
```

## Motivation

1. Have a working reference for various API providers.
2. Write more Bash.
