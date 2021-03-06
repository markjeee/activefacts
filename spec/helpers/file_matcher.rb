require 'diff/lcs'

module FileMatcher
  class BeDifferentFile
    def initialize(expected)
      expected = File.open(expected).read if expected.is_a?(Pathname)
      @expected = expected.scan(/[^\n]+/)
    end

    def matches?(actual)
      actual = File.open(actual).read if actual.is_a?(Pathname)
      actual_lines = actual.scan(/[^\n]+/)
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

  def have_different_contents(expected)
    BeDifferentFile.new(expected)
  end
end

Spec::Runner.configure do |config|
  config.include(FileMatcher)
end
