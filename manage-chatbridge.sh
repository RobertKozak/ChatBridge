#!/bin/bash
# ChatBridge Management Wrapper
# This script provides a convenient entry point at the root level

cd "$(dirname "$0")"
exec ./setup/manage.sh "$@"
