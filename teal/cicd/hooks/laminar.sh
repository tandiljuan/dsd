#!/bin/bash

EVENT="$(echo $@ | jq --raw-output .event)"
BRANCH="$(echo $@ | jq --raw-output .ref | sed -e 's#refs/heads/##')"

LAMINAR_HOST=laminar.cicd.teal:9997 \
laminarc queue web_build event="${EVENT}" branch="${BRANCH}"
