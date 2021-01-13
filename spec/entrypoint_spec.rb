require_relative "../entrypoint"
require "spec_helper"

describe "entrypoint" do
  let(:all_successful_checks) { load_json_sample("all_checks_successfully_completed.json") }
  let(:all_checks) { load_json_sample("all_checks_results.json") }

  describe "wait_for_checks" do
    it "prints successful message to standard output" do
      mock_http_success(with_json: all_successful_checks)
      output = with_captured_stdout{ wait_for_checks("ref", "", "token", 30, "invoking_check") }

      expect(output).to include("check_completed: completed (success)")
    end
  end

  describe "all_checks_complete" do
    it "returns true if all checks are in status complete" do
      expect(all_checks_complete(
        [
          { "status" => "completed" },
          { "status" => "completed" }
        ]
      )).to be true
    end

    context "some checks (apart from the invoking one) are not complete" do
      it "false if some check still queued" do
        expect(all_checks_complete(
          [
            { "status" => "completed" },
            { "status" => "queued" }
          ]
        )).to be false
      end

      it "false if some check is in progress" do
        expect(all_checks_complete(
          [
            { "status" => "completed" },
            { "status" => "in_progress" }
          ]
        )).to be false
      end
    end
  end

  describe "query_check_status" do
    it "filters out the invoking check" do
      mock_http_success(with_json: all_checks)
      result = query_check_status("ref", "", "token", "invoking_check")

      expect(result.map{|check| check["name"]}).not_to include("invoking_check")
    end
  end

  describe "fail_if_requested_check_never_run" do
    it "raises an exception if check_name is not empty and all_checks is" do
      check_name = 'test'
      all_checks = []

      expect do
        fail_if_requested_check_never_run(check_name, all_checks)
      end.to raise_error(StandardError, "The requested check was never run against this ref, exiting...")
    end
  end

  describe "fail_unless_all_success" do
    it "raises an exception if some check is not successful" do
      all_checks = [
        { "name" => "test", "status" => "success" },
        { "name" => "test", "status" => "failure" }
      ]

      expect do
        fail_unless_all_success(all_checks)
      end.to raise_error(StandardError, "One or more checks were not successful, exiting...")
    end
  end
end
