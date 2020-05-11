#!/usr/bin/env ruby
require "net/http"
require "uri"
require "json"

REPO = ENV["GITHUB_REPOSITORY"]

def query_check_status(ref, check_name, token)
  uri = URI.parse("https://api.github.com/repos/#{REPO}/commits/#{ref}/check-runs?check_name=#{check_name}")
  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/vnd.github.antiope-preview+json"
  request["Authorization"] = "token #{token}"
  req_options = {
    use_ssl: uri.scheme == "https"
  }
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http|
    http.request(request)
  }
  parsed = JSON.parse(response.body)
  return [nil, nil] if parsed["total_count"].zero?

  [
    parsed["check_runs"][0]["status"],
    parsed["check_runs"][0]["conclusion"]
  ]
end

# check_name is the name of the "job" key in a workflow, or the full name if the "name" key
# is provided for job. Probably, the "name" key should be kept empty to keep things short
ref, check_name, token, wait = ARGV
wait = wait.to_i
current_status, conclusion = query_check_status(ref, check_name, token)

if current_status.nil?
  puts "The requested check was never run against this ref, exiting..."
  exit(false)
end

while current_status == "in_progress"
  puts "Requested check is still in progress, will check back in 10 seconds..."
  sleep(wait)
  current_status, conclusion = query_check_status(ref, check_name, token)
end

puts "Check completed with a status #{current_status}, and conclusion #{conclusion}"
# Bail if check is not success
exit(false) unless conclusion == "success"
