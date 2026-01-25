# frozen_string_literal: true

# Raised when a required input is not provided.
class RequiredInputError < StandardError
  def initialize(name)
    super("The #{name} parameter is required but was not provided.")
  end
end
