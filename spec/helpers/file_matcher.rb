require 'diff/lcs'

module FileMatcher
  class BeDifferent
    def initialize(expected)
      @expected = expected.scan(/[^\r\n]+/)
    end

    def matches?(actual)
      actual_lines = actual.scan(/[^\r\n]+/)
      differences = Diff::LCS::diff(@expected, actual_lines)
      @diff = differences.map do |chunk|
          added_at = (add = chunk.detect{|d| d.action == '+'}) && add.position+1
          removed_at = (remove = chunk.detect{|d| d.action == '-'}) && remove.position+1
          "Line #{added_at}/#{removed_at}:\n"+
          chunk.map do |change|
            "#{change.action} #{change.element}"
          end*"\n"
        end*"\n"
      @diff != ''
    end

    def failure_message
      "expected a difference, but got none"
    end

    def negative_failure_message
      "expected no difference, but got:\n#{@diff}"
    end
  end

  def differ_from(expected)
    BeDifferent.new(expected)
  end
end

Spec::Runner.configure do |config|
  config.include(FileMatcher)
end
