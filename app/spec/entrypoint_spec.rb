require "spec_helper"

describe "entrypoint" do
  it "calls the GithubChecksVerifier service" do
    allow(GithubChecksVerifier).to receive(:call)
    require_relative "../../entrypoint.rb"

    expect(GithubChecksVerifier).to have_received(:call)
  end
end
