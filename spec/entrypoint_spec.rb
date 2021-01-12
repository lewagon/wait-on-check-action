require_relative '../entrypoint'
require 'spec_helper'

RSpec.describe 'wait_for_checks' do
  let(:all_successful_actions) { load_json_sample("all_actions_successfully_completed.json") }

  it 'prints successful message to standard output' do
    mock_http_success(with_json: all_successful_actions)
    output = with_captured_stdout{ wait_for_checks("ref", "", "token", 30, "invoking_check") }

    expect(output).to include("check_completed: completed (success)")
  end
end