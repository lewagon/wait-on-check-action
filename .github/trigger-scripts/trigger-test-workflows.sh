#!/bin/sh
source ./push-tag-trigger.sh "test-omitting-check-name/v" $RANDOM
source ./push-tag-trigger.sh "test-using-check-name/v" $RANDOM
source ./push-tag-trigger.sh "test-using-regexp/v" $RANDOM
