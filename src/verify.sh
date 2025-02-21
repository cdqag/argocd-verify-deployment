#!/usr/bin/env bash

# Copyright (c) CDQ AG

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
source "$SCRIPT_DIR/helpers/log_helpers.sh"

while getopts "n:v:o:h" opt; do
	case "${opt}" in
	n)
		log_debug "-n argument is $OPTARG"
		APP_NAME="$OPTARG"
		;;
	v)
		log_debug "-v argument is $OPTARG"
		APP_VERSION="$OPTARG"
		;;
	o)
		log_debug "-o argument is $OPTARG"
		DOCKER_ORG="$OPTARG"
		;;
	r)
		log_debug "-r argument is provided"
		HARD_REFRESH="true"
		;;
	h)
		echo_err "Usage: $0 -n <app_name> -v <app_version> -o <docker_org> [-h]"
		echo_err "  -n <app_name>            The name of the application."
		echo_err "  -v <app_version>         The version of the application."
		echo_err "  -o <docker_org>          The docker organization to use."
		echo_err "  -h                       Display this help message, then exit."
		exit 0
		;;
	esac
done

if [[ -z "$APP_NAME" ]]; then
	log_error "Invalid input" "app_name cannot be an empty string"
	exit 11
fi

if [[ -z "$APP_VERSION" ]]; then
	log_error "Invalid input" "app_version cannot be an empty string"
	exit 12
fi

if [[ -z "$DOCKER_ORG" ]]; then
	log_error "Invalid input" "docker_org cannot be an empty string"
	exit 13
fi

if [[ -z "$HARD_REFRESH" ]]; then
	HARD_REFRESH="false"
fi

function app_get() {
	local cmd="argocd app get $APP_NAME --output=json"
	if [[ "$HARD_REFRESH" == "true" ]]; then
		cmd="$cmd --hard-refresh"
	fi
	echo "$($cmd)"
}

state=$(app_get)
images=$(echo "$state" | jq -rc 'if .status.summary.images == null or (.status.summary.images | length == 0) then null else .status.summary.images end')
log_debug "Found images: $images"

if [[ "$images" == "null" ]]; then
	log_notice "ArgoCD App Deployment Verification Skipped" "Deployed ArgoCD App '$APP_NAME' has no images running. This probably means that no pods are running. Skipping verification."
	exit 0
fi

verification=$(echo "$images" | jq -rc --arg org "$DOCKER_ORG" --arg version "$APP_VERSION" 'any(.[]; test("\($org)/[^:]+:\($version)"))')
if [[ "$verification" == "true" ]]; then
	log_info "Everything looks fine!"
else
	log_error "Deployed ArgoCD App Verification Failed" "Deployed ArgoCD App '$APP_NAME' has not passed the verification. Neither running pod is using the image with tag '$APP_VERSION'. Found images: $images"
	exit 14
fi
