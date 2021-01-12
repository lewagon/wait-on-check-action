require_relative '../entrypoint'
require 'spec_helper'

describe 'entrypoint' do
  let(:all_successful_checks) { load_json_sample("all_checks_successfully_completed.json") }
  let(:all_checks) { load_json_sample("all_checks_results.json") }
  describe 'wait_for_checks' do
    it 'prints successful message to standard output' do
      mock_http_success(with_json: all_successful_checks)
      output = with_captured_stdout{ wait_for_checks("ref", "", "token", 30, "invoking_check") }
  
      expect(output).to include("check_completed: completed (success)")
    end
  end
  
  describe 'all_checks_complete' do
    it 'returns true if all checks are in status complete' do
      expect(all_checks_complete(
        [
          { "status" => "completed" },
          { "status" => "completed" }
        ]
      )).to be true
    end

    context 'some checks (apart from the invoking one) are not complete' do
      it 'false if some check still queued' do
        expect(all_checks_complete(
          [
            { "status" => "completed" },
            { "status" => "queued" }
          ]
        )).to be false
      end

      it 'false if some check is in progress' do
        expect(all_checks_complete(
          [
            { "status" => "completed" },
            { "status" => "in_progress" }
          ]
        )).to be false
      end
    end
  end
end