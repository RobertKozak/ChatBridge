#!/bin/bash
# ChatBridge Installation Wrapper
# This script provides a convenient entry point at the root level

cd "$(dirname "$0")"
exec ./setup/setup.sh "$@"
