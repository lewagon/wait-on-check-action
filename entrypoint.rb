#!/usr/bin/env ruby
require_relative "./app/services/github_checks_verifier.rb"

ref, check_name, token, wait, workflow_name, allow_skipped = ARGV
GithubChecksVerifier.call(ref, check_name, token, wait, workflow_name, allow_skipped)
