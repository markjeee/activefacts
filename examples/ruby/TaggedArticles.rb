require 'activefacts/api'

module ::TaggedArticles

  class ArticleID < SignedInteger
    value_type :length => 32
  end

  class Tag < String
    value_type 
  end

  class Tagging
    identified_by :article_id, :tag
    has_one :article_id, :class => ArticleID, :mandatory => true  # See ArticleID.all_tagging
    has_one :tag, :mandatory => true            # See Tag.all_tagging
  end

end
