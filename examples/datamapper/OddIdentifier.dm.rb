require 'dm-core'

class ThingSequence
  include DataMapper::Resource

  property :thing_id, Integer, :key => true	# Thing Sequence is where Thing has Ordinal occurrence and Thing has Thing ID
  property :ordinal, Integer, :key => true	# Thing Sequence is where Thing has Ordinal occurrence
  property :text, String, :key => true	# Thing Sequence has Text
end

