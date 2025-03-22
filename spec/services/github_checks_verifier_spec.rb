require "spec_helper"
require "ostruct"

describe GithubChecksVerifier do
  let(:service) do
    described_class.new
  end

  before do
    described_class.config.client = Octokit::Client.new
    described_class.config.allowed_conclusions = ["success", "skipped"]
  end

  describe "#call" do
    before { allow(service).to receive(:wait_for_checks).and_raise(CheckNeverRunError) }

    it "exit with status false if wait_for_checks fails" do
      expect { service.call }.to raise_error(SystemExit)
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
      service.wait = 0
      output = with_captured_stdout { service.call }

      expect(output).to include("The requested check isn't complete yet, will check back in #{service.wait} seconds...")
    end
  end

  describe "#all_checks_complete" do
    it "returns true if all checks are in status complete" do
      checks = [
        OpenStruct.new(name: "test", status: "completed", conclusion: "success"),
        OpenStruct.new(name: "test", status: "completed", conclusion: "failure")
      ]
      expect(service.send(:all_checks_complete, checks)).to be true
    end

    context "some checks (apart from the invoking one) are not complete" do
      it "false if some check still queued" do
        checks = [
          OpenStruct.new(name: "test", status: "completed", conclusion: "success"),
          OpenStruct.new(name: "test", status: "queued", conclusion: nil)
        ]
        expect(service.send(:all_checks_complete, checks)).to be false
      end

      it "false if some check is in progress" do
        checks = [
          OpenStruct.new(name: "test", status: "completed", conclusion: "success"),
          OpenStruct.new(name: "test", status: "in_progress", conclusion: nil)
        ]
        expect(service.send(:all_checks_complete, checks)).to be false
      end
    end
  end

  describe "#query_check_status" do
    it "filters out the invoking check" do
      all_checks = load_checks_from_yml("all_checks_results.json")
      mock_api_response(all_checks)

      service.config.workflow_name = "invoking_check"

      result = service.send(:query_check_status)

      expect(result.map(&:name)).not_to include("invoking_check")
    end
  end

  describe "#fail_if_requested_check_never_run" do
    it "raises an exception if check_name is not empty and all_checks is" do
      service.config.check_name = "test"
      all_checks = []
      allow(service).to receive(:query_check_status).and_return all_checks

      expected_msg = "The requested check was never run against this ref, exiting..."
      expect {
        service.call
      }.to raise_error(SystemExit).and output(/#{expected_msg}/).to_stdout
    end
  end

  describe "#fail_unless_all_conclusions_allowed" do
    it "raises an exception if some check conclusion is not allowed" do
      all_checks = [
        OpenStruct.new(name: "test", status: "completed", conclusion: "success"),
        OpenStruct.new(name: "test", status: "completed", conclusion: "failure")
      ]
      allow(service).to receive(:query_check_status).and_return all_checks

      expected_msg = "The conclusion of one or more checks were not allowed. Allowed conclusions are: " \
                     "success, skipped. This can be configured with the 'allowed-conclusions' param."
      expect {
        service.call
      }.to raise_error(SystemExit).and output(/#{expected_msg}/).to_stdout
    end

    it "does not raise an exception if all checks conlusions are allowed" do
      all_checks = [
        OpenStruct.new(name: "test", status: "completed", conclusion: "success"),
        OpenStruct.new(name: "test", status: "completed", conclusion: "skipped")
      ]
      allow(service).to receive(:query_check_status).and_return all_checks

      expect {
        service.call
      }.not_to raise_error
    end
  end

  describe "#show_checks_conclusion_message" do
    it "prints successful message to standard output" do
      checks = [OpenStruct.new(name: "check_completed", status: "completed", conclusion: "success")]
      allow(service).to receive(:query_check_status).and_return checks
      output = with_captured_stdout { service.call }

      expect(output).to include("check_completed: completed (success)")
    end
  end

  describe "#apply_filters" do
    it "filters out all but check_name" do
      checks = [
        OpenStruct.new(name: "check_name", status: "queued"),
        OpenStruct.new(name: "other_check", status: "queued")
      ]

      service.config.ignore_checks = ["check_name"]
      service.send(:apply_filters, checks)
      expect(checks.map(&:name)).to all(eq "other_check")
    end

    it "filters out only ignore_checks" do
      checks = [
        OpenStruct.new(name: "check_name1", status: "queued"),
        OpenStruct.new(name: "check_name2", status: "queued"),
        OpenStruct.new(name: "other_check", status: "queued")
      ]

      service.config.ignore_checks = ["check_name1", "check_name2"]
      service.send(:apply_filters, checks)
      expect(checks.map(&:name)).to all(eq "other_check")
    end

    it "does not filter by check_name if it's empty" do
      checks = [
        OpenStruct.new(name: "check_name", status: "queued"),
        OpenStruct.new(name: "other_check", status: "queued")
      ]

      service.config.ignore_checks = []
      allow(service).to receive(:apply_regexp_filter).with(checks).and_return(checks)
      service.send(:apply_filters, checks)

      expect(checks.size).to eq 2
    end

    it "filters out the workflow_name" do
      checks = [
        OpenStruct.new(name: "workflow_name", status: "pending"),
        OpenStruct.new(name: "other_check", status: "queued")
      ]
      service.config.workflow_name = "workflow_name"
      service.send(:apply_filters, checks)

      expect(checks.map(&:name)).not_to include("workflow_name")
    end

    it "does not filter if ignore checks are empty" do
      checks = [
        OpenStruct.new(name: "test1", status: "completed", conclusion: "success"),
        OpenStruct.new(name: "test2", status: "completed", conclusion: "skipped")
      ]
      service.config.ignore_checks = []
      service.send(:apply_filters, checks)

      expect(checks.size).to eq 2
    end

    it "apply the regexp filter" do
      checks = [
        OpenStruct.new(name: "test", status: "pending"),
        OpenStruct.new(name: "test", status: "queued")
      ]
      allow(service).to receive(:apply_regexp_filter)
      service.send(:apply_filters, checks)

      # only assert that the method is called. The functionality will be tested
      # on #apply_regexp_filter tests
      expect(service).to have_received(:apply_regexp_filter)
    end
  end

  describe "#apply_regexp_filter" do
    it "simple regexp" do
      checks = [
        OpenStruct.new(name: "check_name", status: "queued"),
        OpenStruct.new(name: "other_check", status: "queued")
      ]

      service.check_regexp = ".?_check"
      service.send(:apply_regexp_filter, checks)

      expect(checks.map(&:name)).to include("other_check")
      expect(checks.map(&:name)).not_to include("check_name")
    end

    it "complex regexp" do
      checks = [
        OpenStruct.new(name: "test@example.com", status: "queued"),
        OpenStruct.new(name: "other_check", status: "queued")
      ]

      service.check_regexp = '\A[\w.+-]+@\w+\.\w+\z'
      service.send(:apply_regexp_filter, checks)

      expect(checks.map(&:name)).not_to include("other_check")
      expect(checks.map(&:name)).to include("test@example.com")
    end
  end
end
