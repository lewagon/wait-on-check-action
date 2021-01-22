# frozen_string_literal: true

require_relative "./application_service"
require "active_support/configurable"

require "json"
require "octokit"

class GithubChecksVerifier < ApplicationService
  include ActiveSupport::Configurable
  config_accessor :check_name, :workflow_name, :client, :repo, :ref
  config_accessor(:wait) { 30 } # set a default
  config_accessor(:check_regexp) { "" }

  def call
    wait_for_checks
  rescue => e
    puts e.message
    exit(false)
  end

  def query_check_status
    checks = client.check_runs_for_ref(repo, ref, {accept: "application/vnd.github.antiope-preview+json"}).check_runs
    apply_filters(checks)
  end

  def apply_filters(checks)
    checks.reject! { |check| check.name == workflow_name }
    checks.select! { |check| check.name == check_name } if check_name.present?
    apply_regexp_filter(checks)

    checks
  end

  def apply_regexp_filter(checks)
    checks.select! { |check| check.name[check_regexp] } if check_regexp.present?
  end

  def all_checks_complete(checks)
    checks.all? { |check| check.status == "completed" }
  end

  def filters_present?
    check_name.present? || check_regexp.present?
  end

  def fail_if_requested_check_never_run(check_name, all_checks)
    return unless check_name.present? && all_checks.blank?

    raise StandardError, "The requested check was never run against this ref, exiting..."
  end

  def fail_unless_all_success(checks)
    return if checks.all? { |check| check.conclusion == "success" }

    raise StandardError, "One or more checks were not successful, exiting..."
  end

  def show_checks_conclusion_message(checks)
    puts "Checks completed:"
    puts checks.reduce("") { |message, check|
      "#{message}#{check.name}: #{check.status} (#{check.conclusion})\n"
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
