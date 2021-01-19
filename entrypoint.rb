#!/usr/bin/env ruby
require_relative "./app/services/github_checks_verifier.rb"
require "octokit"

# check_name is the name of the "job" key in a workflow, or the full name if the "name" key
# is provided for job. Probably, the "name" key should be kept empty to keep things short
ref, check_name, check_regexp, token, wait, workflow_name = ARGV

GithubChecksVerifier.configure do |config|
  config.check_name = check_name
  config.check_regexp = check_regexp
  config.client = Octokit::Client.new(access_token: token)
  config.ref = ref
  config.repo = ENV["GITHUB_REPOSITORY"]
  config.wait = wait.to_i
  config.workflow_name = workflow_name
end

GithubChecksVerifier.call
