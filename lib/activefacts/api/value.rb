module ActiveFacts
  module Value
    include Instance

    # Value instance methods:
    # REVISIT

    # verbalise this Value
    def verbalise
      "#{self.class.basename} '#{to_s}'"
    end

    module ClassMethods
      include Instance::ClassMethods

      class_def :length do |*args|
	@length = args[0] if args.length > 0
	@length
      end

      class_def :scale do |*args|
	@scale = args[0] if args.length > 0
	@scale
      end

      # verbalise this ValueType
      def verbalise
	# REVISIT: Add length and scale here, if set
	"#{basename} = #{superclass.name}();"
      end
    end

    def Value.included other
      other.send :extend, ClassMethods

      # Register ourselves with the parent module, which has become a Vocabulary:
      vocabulary = other.modspace
      unless vocabulary.respond_to? :concept
	vocabulary.send :extend, Vocabulary
      end
      vocabulary.concept[other.basename] = other
    end
  end
end