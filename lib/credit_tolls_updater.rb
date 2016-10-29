module DiscourseCredit
  class CreditTollsUpdater
    VALID_TOLLS_CONFIGS = %w{id credit}.map(&:freeze)

    def self.update(post, tolls)
      # load previous tolls
      previous_tolls = post.custom_fields[DiscourseCredit::CREDIT_TOLLS_CUSTOM_FIELD] || {}

      if tolls_updated?(tolls, previous_tolls)
        post.custom_fields[DiscourseCredit::CREDIT_TOLLS_CUSTOM_FIELD] = tolls
        post.save_custom_fields(true)
      end
    end

    def self.tolls_updated?(current_tolls, previous_tolls)
      return true if (current_tolls.keys.sort != previous_tolls.keys.sort)

      current_tolls.each_key do |toll_name|
        if !previous_tolls[toll_name] ||
           (current_tolls[toll_name].values_at(*VALID_TOLLS_CONFIGS) != previous_tolls[toll_name].values_at(*VALID_TOLLS_CONFIGS))

          return true
        end
      end

      false
    end
  end
end
