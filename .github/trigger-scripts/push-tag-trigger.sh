#!/bin/sh
set -eux
prefix=$1
random_number=$2
tag_version="`echo $random_number % 100 | bc`"
tag_name="$prefix$tag_version"

git tag "$tag_name"
trap 'git tag -d "$tag_name"' 0 2
git push origin "$tag_name"
git push --delete origin "$tag_name"
