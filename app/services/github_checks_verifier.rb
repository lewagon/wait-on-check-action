# frozen_string_literal: true

require_relative 'application_service'
require_relative 'github_actions_run_filter'
require_relative '../errors/check_conclusion_not_allowed_error'
require_relative '../errors/check_never_run_error'
require 'active_support/configurable'

require 'json'
require 'octokit'

# Verifies the status of GitHub checks for a given repository.
class GithubChecksVerifier < ApplicationService
  include ActiveSupport::Configurable
  config_accessor :check_name, :workflow_name, :client, :repo, :ref, :current_run_id
  config_accessor(:wait) { 30 } # set a default
  config_accessor(:check_regexp) { '' }
  config_accessor(:allowed_conclusions) { %w[success skipped] }
  config_accessor(:verbose) { true }
  config_accessor(:ignore_checks) { [] }
  config_accessor(:current_refs) { [] }

  def call
    wait_for_checks
  rescue CheckNeverRunError, CheckConclusionNotAllowedError => e
    puts e.message
    exit(false)
  end

  private

  def query_check_status
    checks = client.check_runs_for_ref(
      repo, ref, { accept: 'application/vnd.github.antiope-preview+json' }
    ).check_runs
    log_checks(checks, 'Checks running on ref:')

    apply_filters(checks)
  end

  def log_checks(checks, msg)
    return unless verbose

    puts msg
    statuses = checks.map(&:status).uniq
    statuses.each do |status|
      print "Checks #{status}: "
      puts checks.select { |check| check.status == status }.map(&:name).join(', ')
    end
  end

  def apply_filters(checks)
    apply_current_run_filter(checks)
    checks.reject! { |check| [ignore_checks, workflow_name].flatten.include?(check.name) }
    log_checks(checks, 'Checks after ignore checks filter:')
    checks.select! { |check| check.name == check_name } if check_name.present?
    log_checks(checks, 'Checks after check_name filter:')
    apply_regexp_filter(checks)
    log_checks(checks, 'Checks after Regexp filter:')

    checks
  end

  def apply_regexp_filter(checks)
    checks.select! { |check| check.name[Regexp.new(check_regexp)] } if check_regexp.present?
  end

  def apply_current_run_filter(checks)
    checks_for_current_run = current_run_checks(checks)
    return if checks_for_current_run.nil?
    return log_missing_current_run_checks if checks_for_current_run.blank?

    checks.replace(checks_for_current_run)
    log_checks(checks, "Checks after current GitHub Actions run filter (#{current_run_id}):")
  end

  def current_run_checks(checks)
    GithubActionsRunFilter.call(
      checks,
      current_run_id: current_run_id,
      current_refs: current_refs,
      ref: ref
    )
  end

  def log_missing_current_run_checks
    return unless verbose

    puts "No checks found for current GitHub Actions run #{current_run_id}; leaving ref checks unfiltered."
  end

  def all_checks_complete(checks)
    checks.all? { |check| check.status == 'completed' }
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

    raise CheckConclusionNotAllowedError, allowed_conclusions
  end

  def show_checks_conclusion_message(checks)
    puts 'Checks completed:'
    puts checks.reduce('') { |message, check|
      "#{message}#{check.name}: #{check.status} (#{check.conclusion})\n"
    }
  end

  def wait_for_checks
    all_checks = query_check_status

    fail_if_requested_check_never_run(all_checks)

    until all_checks_complete(all_checks)
      plural_part = all_checks.length > 1 ? "checks aren't" : "check isn't"
      puts "The requested #{plural_part} complete yet, will check back in #{wait} seconds..."
      sleep(wait)
      all_checks = query_check_status
    end

    show_checks_conclusion_message(all_checks)

    fail_unless_all_conclusions_allowed(all_checks)
  end
end
