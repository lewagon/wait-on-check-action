#!/usr/bin/env ruby
require "net/http"
require "uri"
require "json"

REPO = ENV["GITHUB_REPOSITORY"]

def query_check_status(ref, check_name, token, workflow_name)
  uri = URI.parse("https://api.github.com/repos/#{REPO}/commits/#{ref}/check-runs#{
    "?check_name=#{check_name}" unless check_name.empty?
  }")
  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/vnd.github.antiope-preview+json"
  token.empty? || request["Authorization"] = "token #{token}"
  req_options = {
    use_ssl: uri.scheme == "https"
  }
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http|
    http.request(request)
  }
  parsed = JSON.parse(response.body)

  parsed["check_runs"].reject { |check| check["name"] == workflow_name }
end

def all_checks_complete(checks)
  checks.all? { |check| check["status"] != "queued" && check["status"] != "in_progress" }
end

# check_name is the name of the "job" key in a workflow, or the full name if the "name" key
# is provided for job. Probably, the "name" key should be kept empty to keep things short
ref, check_name, token, wait, workflow_name = ARGV
wait = wait.to_i
all_checks = query_check_status(ref, check_name, token, workflow_name)

if !check_name.empty? && all_checks.empty?
  puts "The requested check was never run against this ref, exiting..."
  exit(false)
end

until all_checks_complete(all_checks)
  plural_part = all_checks.length > 1 ? "checks aren't" : "check isn't"
  puts "The requested #{plural_part} complete yet, will check back in #{wait} seconds..."
  sleep(wait)
  all_checks = query_check_status(ref, check_name, token, workflow_name)
end

puts "Checks completed:"
puts all_checks.reduce("") { |message, check|
  "#{message}#{check["name"]}: #{check["status"]} (#{check["conclusion"]})\n"
}

# Bail if check is not success
exit(false) unless all_checks.all? { |check| check["conclusion"] === "success" }
