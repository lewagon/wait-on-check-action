# frozen_string_literal: true
require_relative "./application_service"
require "net/http"
require "uri"
require "json"

class GithubChecksVerifier < ApplicationService
  attr_accessor :check_name, :token, :wait, :workflow_name, :github_api_uri

  def call
    wait_for_checks
  rescue StandardError => e
    puts e.message
    exit(false)
  end

  # check_name is the name of the "job" key in a workflow, or the full name if the "name" key
  # is provided for job. Probably, the "name" key should be kept empty to keep things short
  def initialize(ref, check_name, token, wait, workflow_name)
    @check_name = check_name
    @token = token
    @wait = wait.to_i
    @workflow_name = workflow_name
    @github_api_uri = "https://api.github.com/repos/#{ENV["GITHUB_REPOSITORY"]}/commits/#{ref}/check-runs#{
      "?check_name=#{check_name}" unless check_name.empty?
    }"
  end

  def query_check_status
    uri = URI.parse(github_api_uri)
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github.antiope-preview+json"
    token.empty? || request["Authorization"] = "token #{token}"
    req_options = {
      use_ssl: uri.scheme == "https"
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http|
      http.request(request)
    }
    parsed = JSON.parse(response.body)

    parsed["check_runs"].reject { |check| check["name"] == workflow_name }
  end

  def all_checks_complete(checks)
    checks.all? { |check| check["status"] == "completed" }
  end

  def fail_if_requested_check_never_run(check_name, all_checks)
    return unless !check_name.empty? && all_checks.empty?

    raise StandardError, "The requested check was never run against this ref, exiting..."
  end

  def fail_unless_all_success(checks)
    return if checks.all? { |check| check["conclusion"] === "success" }

    raise StandardError, "One or more checks were not successful, exiting..."
  end

  def show_checks_conclusion_message(checks)
    puts "Checks completed:"
    puts checks.reduce("") { |message, check|
      "#{message}#{check["name"]}: #{check["status"]} (#{check["conclusion"]})\n"
    }
  end

  def wait_for_checks
    all_checks = query_check_status

    fail_if_requested_check_never_run(check_name, all_checks)

    until all_checks_complete(all_checks)
      plural_part = all_checks.length > 1 ? "checks aren't" : "check isn't"
      puts "The requested #{plural_part} complete yet, will check back in #{wait} seconds..."
      sleep(wait)
      all_checks = query_check_status
    end

    show_checks_conclusion_message(all_checks)

    fail_unless_all_success(all_checks)
  end
end
