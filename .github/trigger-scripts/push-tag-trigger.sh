#!/bin/sh
set -eux
prefix=$1
tag_version=$(($RANDOM%100))
tag_name="$prefix$tag_version"

git tag "$tag_name"
trap 'git tag -d "$tag_name"' 0 2
git push origin "$tag_name"
git push --delete origin "$tag_name"
