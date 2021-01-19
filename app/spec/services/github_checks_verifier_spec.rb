require "spec_helper"
require "ostruct"

describe GithubChecksVerifier do
  let(:service) do
    described_class.config.client = Octokit::Client.new
    described_class.new
  end

  describe "#call" do
    before { allow(service).to receive(:wait_for_checks).and_raise(StandardError, "test error") }

    it "exit with status false if wait_for_checks fails" do
      expect { with_captured_stdout { service.call } }.to raise_error(SystemExit)
    end
  end

  describe "#wait_for_checks" do
    it "waits until all checks are completed" do
      cycles = 1 # simulates the method waiting for one cyecle
      allow(service).to receive(:all_checks_complete) do
        (cycles -= 1) && cycles < 0
      end

      all_successful_checks = load_checks_from_yml("all_checks_successfully_completed.json")
      mock_api_response(all_successful_checks)
      service.workflow_name = "invoking_check"
      output = with_captured_stdout{ service.wait_for_checks }

      expect(output).to include("The requested check isn't complete yet, will check back in #{service.wait} seconds...")
    end
  end

  describe "#all_checks_complete" do
    it "returns true if all checks are in status complete" do
      expect(service.all_checks_complete(
        [
          OpenStruct.new(name: "test", status: "completed", conclusion: "success"),
          OpenStruct.new(name: "test", status: "completed", conclusion: "failure")
        ]
      )).to be true
    end

    context "some checks (apart from the invoking one) are not complete" do
      it "false if some check still queued" do
        expect(service.all_checks_complete(
          [
            OpenStruct.new(name: "test", status: "completed", conclusion: "success"),
            OpenStruct.new(name: "test", status: "queued", conclusion: nil)
          ]
        )).to be false
      end

      it "false if some check is in progress" do
        expect(service.all_checks_complete(
          [
            OpenStruct.new(name: "test", status: "completed", conclusion: "success"),
            OpenStruct.new(name: "test", status: "in_progress", conclusion: nil)
          ]
        )).to be false
      end
    end
  end

  describe "#query_check_status" do
    it "filters out the invoking check" do
      all_checks = load_checks_from_yml("all_checks_results.json")
      mock_api_response(all_checks)

      service.config.workflow_name = "invoking_check"

      result = service.query_check_status

      expect(result.map(&:name)).not_to include("invoking_check")
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
        OpenStruct.new(name: "test", status: "completed", conclusion: "success"),
        OpenStruct.new(name: "test", status: "completed", conclusion: "failure")
      ]

      expect do
        service.fail_unless_all_success(all_checks)
      end.to raise_error(StandardError, "One or more checks were not successful, exiting...")
    end
  end

  describe "#show_checks_conclusion_message" do
    it "prints successful message to standard output" do
      checks = [OpenStruct.new(name: "check_completed", status: "completed", conclusion: "success")]
      output = with_captured_stdout{ service.show_checks_conclusion_message(checks) }

      expect(output).to include("check_completed: completed (success)")
    end
  end

  describe "#apply_filters" do
    it "filters out all but check_name" do
      checks = [
        OpenStruct.new(name: "check_name", status: "queued"),
        OpenStruct.new(name: "other_check", status: "queued")
      ]

      service.config.check_name = "check_name"
      service.apply_filters(checks)
      expect(checks.map(&:name)).to all( eq "check_name" )
    end

    it "does not filter by check_name if it's empty" do
      checks = [
        OpenStruct.new(name: "check_name", status: "queued"),
        OpenStruct.new(name: "other_check", status: "queued")
      ]

      service.config.check_name = ""
      allow(service).to receive(:apply_regexp_filter).with(checks).and_return(checks)
      service.apply_filters(checks)

      expect(checks.size).to eq 2
    end

    it "filters out the workflow_name" do
      checks = [
        OpenStruct.new(name: "workflow_name", status: "pending"),
        OpenStruct.new(name: "other_check", status: "queued")
      ]
      service.config.workflow_name = "workflow_name"
      service.apply_filters(checks)

      expect(checks.map(&:name)).not_to include("workflow_name")
    end
  end
end
