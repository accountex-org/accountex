#!/usr/bin/env bash
#---
# excerpted from "engineering elixir applications",
# published by the pragmatic bookshelf.
# copyrights apply to this code. it may not be used to create training material,
# courses, books, articles, and the like. contact us if you are in doubt.
# we make no guarantees that this code is fit for any purpose.
# visit https://pragprog.com/titles/beamops for more book information.
#---
# in scripts/asdf_plugins.sh
# install necessary plugins
plugins=(
  "github-cli"
  "packer"
  "terraform"
  "awscli"
  "elixir"
  "erlang"
  "postgres"
  "jq"
  "age"
  "sops"
)
for plugin in "${plugins[@]}"; do
  asdf plugin-add "$plugin" || true
  # the "|| true" ignore errors if a certain plugin already exists
done

echo "ASDF plugins installation complete."
echo "please restart your terminal or source your profile file."
