#!/usr/bin/env ruby
require "app/services/github_checks_verifier"

# ref, check_name, token, wait, workflow_name = ARGV
GithubChecksVerifier.call(ARGV)
