#!/usr/bin/env ruby

# frozen_string_literal: true

require_relative "app/services/github_checks_verifier"
require "octokit"

allowed_conclusions = ENV.fetch("ALLOWED_CONCLUSIONS", nil)
check_name = ENV.fetch("CHECK_NAME", nil)
check_regexp = ENV.fetch("CHECK_REGEXP", nil)
ref = ENV.fetch("REF", nil)
token = ENV.fetch("REPO_TOKEN", nil)
verbose = ENV.fetch("VERBOSE", nil)
wait = ENV.fetch("WAIT_INTERVAL", nil)
workflow_name = ENV.fetch("RUNNING_WORKFLOW_NAME", nil)
api_endpoint = ENV.fetch("API_ENDPOINT", "")
ignore_checks = ENV.fetch("IGNORE_CHECKS", nil)

GithubChecksVerifier.configure do |config|
  config.allowed_conclusions = allowed_conclusions.split(",").map(&:strip)
  config.ignore_checks = ignore_checks.split(",").map(&:strip)
  config.check_name = check_name
  config.check_regexp = check_regexp
  config.client = Octokit::Client.new(auto_paginate: true)
  config.client.api_endpoint = api_endpoint unless /\A[[:space:]]*\z/.match?(api_endpoint)
  config.client.access_token = token
  config.ref = ref
  config.repo = ENV.fetch("GITHUB_REPOSITORY", nil)
  config.verbose = verbose
  config.wait = wait.to_i
  config.workflow_name = workflow_name
end

GithubChecksVerifier.call
