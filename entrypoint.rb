#!/usr/bin/env ruby
require_relative "./app/services/github_checks_verifier"
require "octokit"

allowed_conclusions = ENV["ALLOWED_CONCLUSIONS"]
check_name = ENV["CHECK_NAME"]
check_regexp = ENV["CHECK_REGEXP"]
ref = ENV["REF"]
token = ENV["REPO_TOKEN"]
verbose = ENV["VERBOSE"]
wait = ENV["WAIT_INTERVAL"]
workflow_name = ENV["RUNNING_WORKFLOW_NAME"]

GithubChecksVerifier.configure do |config|
  config.allowed_conclusions = allowed_conclusions.split(",").map(&:strip)
  config.check_name = check_name
  config.check_regexp = check_regexp
  config.client = Octokit::Client.new(access_token: token)
  config.ref = ref
  config.repo = ENV["GITHUB_REPOSITORY"]
  config.verbose = verbose
  config.wait = wait.to_i
  config.workflow_name = workflow_name
end

GithubChecksVerifier.call
