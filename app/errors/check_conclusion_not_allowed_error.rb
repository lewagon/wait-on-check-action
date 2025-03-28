# frozen_string_literal: true

# Raised when the conclusions of one or more checks are not allowed.
class CheckConclusionNotAllowedError < StandardError
  def initialize(allowed_conclusions)
    msg = 'The conclusion of one or more checks were not allowed. Allowed conclusions are: ' \
          "#{allowed_conclusions.join(', ')}. This can be configured with the 'allowed-conclusions' param."
    super(msg)
  end
end
