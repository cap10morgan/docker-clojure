#!/usr/bin/env bash
set -e
shopt -s nullglob

if ((BASH_VERSINFO[0] < 4)); then
  echo "You need bash version 4+ to run this script"
  exit 1
fi

# config parameters

OPENJDK_VERSION=8

PAUL='Paul Lam <paul@quantisan.com>'
WES='Wes Morgan <wesmorgan@icloud.com>'

declare -A base_images=(
  [alpine]=openjdk
  [debian]=openjdk
  [fabric8]=fabric8/java-centos-openjdk8-jdk
)

declare -A base_tags=(
  [alpine]=$OPENJDK_VERSION
  [debian]=$OPENJDK_VERSION
  [fabric8]=latest
)

declare -A maintainers=(
  [debian/lein]=$PAUL
  [debian/boot]=$WES
  [alpine]=$WES
  [fabric8]=$WES
)

# Dockerfile generator

variants=( "$@" )
if [ ${#variants[@]} -eq 0 ]; then
  variants=( */*/ )
fi
variants=( "${variants[@]%/}" )

generated_warning() {
  cat <<EOH
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

EOH
}

for variant in "${variants[@]}"; do
  dir="$variant"
  base_variant=${variant%/*}
  base_image=${base_images[$base_variant]}
  base_tag=${base_tags[$base_variant]}
  build_tool=${variant#*/}
  echo "Generating Dockerfile for $dir"
  [ -d "$dir" ] || continue
  template="Dockerfile-$build_tool.template"
  echo "Using template $template"
  if [ "$base_variant" = "alpine" ]; then
    base_tag="${base_tag}-${base_variant}"
  fi
  maintainer=${maintainers[$variant]:-${maintainers[$base_variant]}}
  { generated_warning; cat "$template"; } > "$dir/Dockerfile"
  ( set -x
    sed -i '' 's!%%BASE_IMAGE%%!'"$base_image"'!g' "$dir/Dockerfile"
    sed -i '' 's!%%BASE_TAG%%!'"$base_tag"'!g' "$dir/Dockerfile"
    sed -i '' 's!%%MAINTAINER%%!'"$maintainer"'!g' "$dir/Dockerfile"
    if [ "$base_variant" = "alpine" ]; then
      sed -i '' 's/^%%ALPINE%% //g' "$dir/Dockerfile"
    elif [ "$base_variant" = "fabric8" ]; then
      sed -i '' 's/^%%FABRIC8%% //g' "$dir/Dockerfile"
    fi
    sed -i '' '/^%%ALPINE%%/d' "$dir/Dockerfile"
    sed -i '' '/^%%FABRIC8%%/d' "$dir/Dockerfile"
    sed -i '' '/^$/N;/^\n$/D' "$dir/Dockerfile"
  )
done
