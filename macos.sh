#!/bin/bash
# All these applications are independent, so if one
# fails to install, don't stop.
set +e

echo
echo "Installing applications"

# Utilities

brew install --cask flycut
brew install --cask rectangle

brew install --cask dash # api browser
brew install --cask quicklook-json # OSX tool for viewing JSON

set -e
