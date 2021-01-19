# frozen_string_literal: true

module Helpers
  SAMPLE_RESPONSES_BASE_PATH = "spec/github_api_sample_responses/"

  def load_json_sample(file_name)
    File.read(SAMPLE_RESPONSES_BASE_PATH + file_name)
  end

  def mock_http_success(with_json:)
    response = Net::HTTPSuccess.new(1.0, '200', 'OK')
    allow_any_instance_of(Net::HTTP).to receive(:request) { response }
    allow(response).to receive(:body) { with_json }  
  end

  def with_captured_stdout
    original_stdout = $stdout  # capture previous value of $stdout
    $stdout = StringIO.new     # assign a string buffer to $stdout
    yield                      # perform the body of the user code
    $stdout.string             # return the contents of the string buffer
  ensure
    $stdout = original_stdout  # restore $stdout to its previous value
  end
end

RSpec.configure do |config|
  config.include Helpers
end
