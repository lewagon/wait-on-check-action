# frozen_string_literal: true

# Raised when the requested check was never run.
class CheckNeverRunError < StandardError
  def initialize(msg = 'The requested check was never run against this ref, exiting...')
    super
  end
end
