# frozen_string_literal: true

require_relative 'application_service'

# Finds check runs that belong to the current GitHub Actions run.
class GithubActionsRunFilter < ApplicationService
  def initialize(checks, current_run_id:, current_refs:, ref:)
    super()
    @checks = checks
    @current_run_id = current_run_id.to_s
    @current_refs = Array(current_refs)
    @ref = ref.to_s
  end

  def call
    return nil unless enabled?

    checks.select { |check| actions_run_id(check) == current_run_id }
  end

  private

  attr_reader :checks, :current_run_id, :current_refs, :ref

  def enabled?
    !current_run_id.empty? && !ref.empty? && current_refs.any? { |current_ref| refs_match?(current_ref) }
  end

  def refs_match?(current_ref)
    current_ref = current_ref.to_s
    current_ref == ref || commit_sha_prefix?(current_ref)
  end

  def commit_sha_prefix?(current_ref)
    /\A[0-9a-f]{40}\z/i.match?(current_ref) &&
      /\A[0-9a-f]{7,40}\z/i.match?(ref) &&
      current_ref.start_with?(ref)
  end

  def actions_run_id(check)
    actions_check_url(check)&.match(%r{/actions/runs/(\d+)(?:/|$)})&.captures&.first
  end

  def actions_check_url(check)
    %i[details_url html_url].each do |attribute|
      next unless check.respond_to?(attribute)

      value = check.public_send(attribute)
      return value.to_s unless value.to_s.empty?
    end

    nil
  end
end
