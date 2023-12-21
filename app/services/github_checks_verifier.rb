# frozen_string_literal: true

require_relative "application_service"
require_relative "../errors/check_conclusion_not_allowed_error"
require_relative "../errors/check_never_run_error"
require "active_support/configurable"

require "json"
require "octokit"

class GithubChecksVerifier < ApplicationService
  include ActiveSupport::Configurable
  config_accessor :check_name, :workflow_name, :client, :repo, :ref
  config_accessor(:wait) { 30 } # set a default
  config_accessor(:check_regexp) { "" }
  config_accessor(:allowed_conclusions) { ["success", "skipped"] }
  config_accessor(:verbose) { true }
  config_accessor(:ignore_checks) { [] }

  def call
    wait_for_checks
  rescue CheckNeverRunError, CheckConclusionNotAllowedError => e
    puts e.message
    exit(false)
  end

  private

  def query_check_status
    checks = client.check_runs_for_ref(
      repo, ref, {accept: "application/vnd.github.antiope-preview+json"}
    ).check_runs
    log_checks(checks, "Checks running on ref:")

    apply_filters(checks)
  end

  def log_checks(checks, msg)
    return unless verbose

    puts msg
    statuses = checks.map(&:status).uniq
    statuses.each do |status|
      print "Checks #{status}: "
      puts checks.select { |check| check.status == status }.map(&:name).join(", ")
    end
  end

  def apply_filters(checks)
    checks.reject! { |check| [ignore_checks, workflow_name].flatten.include?(check.name) }
    log_checks(checks, "Checks after ignore checks filter:")
    checks.select! { |check| check.name == check_name } if check_name.present?
    log_checks(checks, "Checks after check_name filter:")
    apply_regexp_filter(checks)
    log_checks(checks, "Checks after Regexp filter:")

    checks
  end

  def apply_regexp_filter(checks)
    checks.select! { |check| check.name[Regexp.new(check_regexp)] } if check_regexp.present?
  end

  def all_checks_complete(checks)
    checks.all? { |check| check.status == "completed" }
  end

  def filters_present?
    check_name.present? || check_regexp.present?
  end

  def check_conclusion_allowed(check)
    allowed_conclusions.include? check.conclusion
  end

  def fail_if_requested_check_never_run(all_checks)
    return unless filters_present? && all_checks.blank?

    raise CheckNeverRunError
  end

  def fail_unless_all_conclusions_allowed(checks)
    return if checks.all? { |check| check_conclusion_allowed(check) }

    raise CheckConclusionNotAllowedError.new(allowed_conclusions)
  end

  def show_checks_conclusion_message(checks)
    puts "Checks completed:"
    puts checks.reduce("") { |message, check|
      "#{message}#{check.name}: #{check.status} (#{check.conclusion})\n"
    }
  end

  def wait_for_checks
    all_checks = query_check_status

    fail_if_requested_check_never_run(all_checks)

    until all_checks_complete(all_checks)
      plural_part = (all_checks.length > 1) ? "checks aren't" : "check isn't"
      puts "The requested #{plural_part} complete yet, will check back in #{wait} seconds..."
      sleep(wait)
      all_checks = query_check_status
    end

    show_checks_conclusion_message(all_checks)

    fail_unless_all_conclusions_allowed(all_checks)
  end
end
