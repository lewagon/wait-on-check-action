# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'

describe GithubChecksVerifier do
  let(:service) do
    described_class.new
  end

  before do
    described_class.config.allowed_conclusions = %w[success skipped]
  end

  describe '#call' do
    before { allow(service).to receive(:wait_for_checks).and_raise(StandardError, 'test error') }

    it 'exit with status false if wait_for_checks fails' do
      expect { with_captured_stdout { service.call } }.to raise_error(SystemExit)
    end
  end

  describe '#wait_for_checks' do
    it 'waits until all checks are completed' do
      all_successful_checks = load_checks_from_yml('all_checks_successfully_completed.json')
      described_class.config.client = instance_double(
        Octokit::Client,
        check_runs_for_ref: OpenStruct.new(check_runs: all_successful_checks)
      )
      cycles = 1 # simulates the method waiting for one cyecle
      allow(service).to receive(:all_checks_complete) do
        (cycles -= 1) && cycles.negative?
      end

      service.workflow_name = 'invoking_check'
      service.wait = 0
      output = with_captured_stdout { service.wait_for_checks }

      expect(output).to include("The requested check isn't complete yet, will check back in #{service.wait} seconds...")
    end
  end

  describe '#all_checks_complete' do
    it 'returns true if all checks are in status complete' do
      expect(service.all_checks_complete(
               [
                 OpenStruct.new(name: 'test', status: 'completed', conclusion: 'success'),
                 OpenStruct.new(name: 'test', status: 'completed', conclusion: 'failure')
               ]
             )).to be true
    end

    context 'when some checks (apart from the invoking one) are not complete' do
      it 'false if some check still queued' do
        expect(service.all_checks_complete(
                 [
                   OpenStruct.new(name: 'test', status: 'completed', conclusion: 'success'),
                   OpenStruct.new(name: 'test', status: 'queued', conclusion: nil)
                 ]
               )).to be false
      end

      it 'false if some check is in progress' do
        expect(service.all_checks_complete(
                 [
                   OpenStruct.new(name: 'test', status: 'completed', conclusion: 'success'),
                   OpenStruct.new(name: 'test', status: 'in_progress', conclusion: nil)
                 ]
               )).to be false
      end
    end
  end

  describe '#query_check_status' do
    it 'filters out the invoking check' do
      all_checks = load_checks_from_yml('all_checks_results.json')
      described_class.config.client = instance_double(
        Octokit::Client,
        check_runs_for_ref: OpenStruct.new(check_runs: all_checks)
      )
      service.config.workflow_name = 'invoking_check'

      result = service.query_check_status

      expect(result.map(&:name)).not_to include('invoking_check')
    end
  end

  describe '#fail_if_requested_check_never_run' do
    it 'raises an exception if check_name is not empty and all_checks is' do
      check_name = 'test'
      all_checks = []

      expect do
        service.fail_if_requested_check_never_run(check_name, all_checks)
      end.to raise_error(StandardError, 'The requested check was never run against this ref, exiting...')
    end
  end

  describe '#fail_unless_all_conclusions_allowed' do
    it 'raises an exception if some check conclusion is not allowed' do
      all_checks = [
        OpenStruct.new(name: 'test', status: 'completed', conclusion: 'success'),
        OpenStruct.new(name: 'test', status: 'completed', conclusion: 'failure')
      ]

      expect do
        service.fail_unless_all_conclusions_allowed(all_checks)
      end.to raise_error(StandardError,
                         'The conclusion of one or more checks were not allowed. Allowed conclusions are: success, '\
                         'skipped. This can be configured with the \'allowed-conclusions\' param.')
    end

    it 'does not raise an exception if all checks conlusions are allowed' do
      all_checks = [
        OpenStruct.new(name: 'test', status: 'completed', conclusion: 'success'),
        OpenStruct.new(name: 'test', status: 'completed', conclusion: 'skipped')
      ]

      expect do
        service.fail_unless_all_conclusions_allowed(all_checks)
      end.not_to raise_error
    end
  end

  describe '#show_checks_conclusion_message' do
    it 'prints successful message to standard output' do
      checks = [OpenStruct.new(name: 'check_completed', status: 'completed', conclusion: 'success')]
      output = with_captured_stdout { service.show_checks_conclusion_message(checks) }

      expect(output).to include('check_completed: completed (success)')
    end
  end

  describe '#apply_filters' do
    it 'filters out all but check_name' do
      checks = [
        OpenStruct.new(name: 'check_name', status: 'queued'),
        OpenStruct.new(name: 'other_check', status: 'queued')
      ]

      service.config.check_name = 'check_name'
      service.apply_filters(checks)
      expect(checks.map(&:name)).to all(eq 'check_name')
    end

    it "does not filter by check_name if it's empty" do
      checks = [
        OpenStruct.new(name: 'check_name', status: 'queued'),
        OpenStruct.new(name: 'other_check', status: 'queued')
      ]

      service.config.check_name = ''
      allow(service).to receive(:apply_regexp_filter).with(checks).and_return(checks)
      service.apply_filters(checks)

      expect(checks.size).to eq 2
    end

    it 'filters out the workflow_name' do
      checks = [
        OpenStruct.new(name: 'workflow_name', status: 'pending'),
        OpenStruct.new(name: 'other_check', status: 'queued')
      ]
      service.config.workflow_name = 'workflow_name'
      service.apply_filters(checks)

      expect(checks.map(&:name)).not_to include('workflow_name')
    end

    it 'apply the regexp filter' do
      checks = [
        OpenStruct.new(name: 'test', status: 'pending'),
        OpenStruct.new(name: 'test', status: 'queued')
      ]
      allow(service).to receive(:apply_regexp_filter)
      service.apply_filters(checks)

      # only assert that the method is called. The functionality will be tested
      # on #apply_regexp_filter tests
      expect(service).to have_received(:apply_regexp_filter)
    end
  end

  describe '#apply_regexp_filter' do
    # rubocop: disable RSpec/MultipleExpectations
    it 'simple regexp' do
      checks = [
        OpenStruct.new(name: 'check_name', status: 'queued'),
        OpenStruct.new(name: 'other_check', status: 'queued')
      ]

      service.check_regexp = Regexp.new('._check')
      service.apply_regexp_filter(checks)

      expect(checks.map(&:name)).to include('other_check')
      expect(checks.map(&:name)).not_to include('check_name')
    end

    it 'complex regexp' do
      checks = [
        OpenStruct.new(name: 'test@example.com', status: 'queued'),
        OpenStruct.new(name: 'other_check', status: 'queued')
      ]

      service.check_regexp = Regexp.new('\A[\w.+-]+@\w+\.\w+\z')
      service.apply_regexp_filter(checks)

      expect(checks.map(&:name)).not_to include('other_check')
      expect(checks.map(&:name)).to include('test@example.com')
    end
    # rubocop: enable RSpec/MultipleExpectations
  end
end
