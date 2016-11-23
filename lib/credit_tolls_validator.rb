PLUGIN_NAME = 'discourse-credit'.freeze

module DiscourseCredit
  class CreditTollsValidator
    def initialize(post)
      @post = post
    end

    def validate_credit_tolls
      tolls = {}

      return tolls unless @post.is_first_post?

      unless @post.archetype != Archetype.private_message
        @post.errors.add(:base, I18n.t("credit.not_normal_topic"))
        return false
      end

      extracted_credit_tolls = DiscourseCredit::extract(@post.raw, @post.topic_id, @post.user_id)

      unless unique_toll?(extracted_credit_tolls)
        @post.errors.add(:base, I18n.t("credit.not_unique"))
        return false
      end

      unless valid_credit?(extracted_credit_tolls)
        @post.errors.add(:base, I18n.t("credit.invalid_credit"))
      end

      extracted_credit_tolls.each do |t|
        tolls[t["id"]] = t
      end

      tolls
    end

    private

    def unique_toll?(tolls)
      ids = tolls.map { |t| t["id"] }
      p "---------"*8,ids
      ids.uniq == ids && ids.size <= 1
    end

    def valid_credit?(tolls)
      tolls.each do |t|
        credit = t["credit"].to_i
        if credit <= 0 || credit > SiteSetting.credit_toll_max_permit
          return false
        end
      end

      true
    end
  end
end
