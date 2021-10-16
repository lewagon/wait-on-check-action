# frozen_string_literal: true

class CheckNeverRunError < StandardError
  def initialize(all_checks)
    names = all_checks.empty? ? ["No checks"] : all_checks.map{|x| x.name}
    msg = <<~EOS
    The requested check was never run against this ref.

    Checks that ran:
    #{names.map{ |x| "- " + x }.join("\n")}

    Exiting...
    EOS
    super(msg)
  end
end
