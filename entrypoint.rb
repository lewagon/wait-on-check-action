#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative './app/services/github_checks_verifier'
require 'octokit'

ref, check_name, check_regexp, token, wait, workflow_name, allowed_conclusions = ARGV

GithubChecksVerifier.configure do |config|
  config.check_name = check_name
  config.check_regexp = check_regexp
  config.client = Octokit::Client.new(access_token: token)
  config.ref = ref
  config.repo = ENV['GITHUB_REPOSITORY']
  config.wait = wait.to_i
  config.workflow_name = workflow_name
  config.allowed_conclusions = allowed_conclusions.split(',').map(&:strip)
end

GithubChecksVerifier.call
