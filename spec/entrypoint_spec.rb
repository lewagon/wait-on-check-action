# frozen_string_literal: true

require "spec_helper"

describe "entrypoint" do
  it "calls the GithubChecksVerifier service" do
    allow(GithubChecksVerifier).to receive(:call)
    allow(GithubChecksVerifier).to receive(:configure)

    require_relative "../entrypoint"

    expect(GithubChecksVerifier).to have_received(:call)
  end
end
