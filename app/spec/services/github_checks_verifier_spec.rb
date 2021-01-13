require "spec_helper"

describe GithubChecksVerifier do
  let(:service) { described_class.new("ref", "check_name", "token", "1", "invoking_check") }

  describe "#wait_for_checks" do
    it "waits until all checks are completed" do
      cycles = 1 # simulates the method waiting for one cyecle
      allow(service).to receive(:all_checks_complete) do
        if cycles > 0
          cycles -= 1
          false
        else
          true
        end
      end

      all_successful_checks = load_json_sample("all_checks_successfully_completed.json")
      mock_http_success(with_json: all_successful_checks)
      output = with_captured_stdout{ service.wait_for_checks }

      expect(output).to include("The requested check isn't complete yet, will check back in 1 seconds...")
    end
  end

  describe "#all_checks_complete" do
    it "returns true if all checks are in status complete" do
      expect(service.all_checks_complete(
        [
          { "status" => "completed" },
          { "status" => "completed" }
        ]
      )).to be true
    end

    context "some checks (apart from the invoking one) are not complete" do
      it "false if some check still queued" do
        expect(service.all_checks_complete(
          [
            { "status" => "completed" },
            { "status" => "queued" }
          ]
        )).to be false
      end

      it "false if some check is in progress" do
        expect(service.all_checks_complete(
          [
            { "status" => "completed" },
            { "status" => "in_progress" }
          ]
        )).to be false
      end
    end
  end

  describe "#query_check_status" do
    it "filters out the invoking check" do
      all_checks = load_json_sample("all_checks_results.json")
      mock_http_success(with_json: all_checks)
      service.check_name = "invoking_check"
      result = service.query_check_status

      expect(result.map{|check| check["name"]}).not_to include("invoking_check")
    end
  end

  describe "#fail_if_requested_check_never_run" do
    it "raises an exception if check_name is not empty and all_checks is" do
      check_name = 'test'
      all_checks = []

      expect do
        service.fail_if_requested_check_never_run(check_name, all_checks)
      end.to raise_error(StandardError, "The requested check was never run against this ref, exiting...")
    end
  end

  describe "#fail_unless_all_success" do
    it "raises an exception if some check is not successful" do
      all_checks = [
        { "name" => "test", "status" => "success" },
        { "name" => "test", "status" => "failure" }
      ]

      expect do
        service.fail_unless_all_success(all_checks)
      end.to raise_error(StandardError, "One or more checks were not successful, exiting...")
    end
  end

  describe "#show_checks_conclusion_message" do
    it "prints successful message to standard output" do
      checks = [{ "name" => "check_completed", "status" => "completed", "conclusion" => "success" }]
      output = with_captured_stdout{ service.show_checks_conclusion_message(checks) }

      expect(output).to include("check_completed: completed (success)")
    end
  end
end
