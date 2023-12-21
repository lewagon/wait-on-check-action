#!/usr/bin/env ruby
require_relative "app/services/github_checks_verifier"
require "octokit"

allowed_conclusions = ENV["ALLOWED_CONCLUSIONS"]
check_name = ENV["CHECK_NAME"]
check_regexp = ENV["CHECK_REGEXP"]
ref = ENV["REF"]
token = ENV["REPO_TOKEN"]
verbose = ENV["VERBOSE"]
wait = ENV["WAIT_INTERVAL"]
workflow_name = ENV["RUNNING_WORKFLOW_NAME"]
api_endpoint = ENV.fetch("API_ENDPOINT", "")
ignore_checks = ENV["IGNORE_CHECKS"]
 

GithubChecksVerifier.configure do |config|
  config.allowed_conclusions = allowed_conclusions.split(",").map(&:strip)
  config.ignore_checks = ignore_checks.split(",").map(&:strip)
  config.check_name = check_name
  config.check_regexp = check_regexp
  config.client = Octokit::Client.new(auto_paginate: true)
  config.client.api_endpoint = api_endpoint unless /\A[[:space:]]*\z/.match?(api_endpoint)
  config.client.access_token = token
  config.ref = ref
  config.repo = ENV["GITHUB_REPOSITORY"]
  config.verbose = verbose
  config.wait = wait.to_i
  config.workflow_name = workflow_name
end

GithubChecksVerifier.call
