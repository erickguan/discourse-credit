# name: Discourse Credit
# version: 0.2
# authors: Erick Guan (fantasticfears@gmail.com)

PLUGIN_NAME = 'discourse-credit'.freeze
CREDIT_FIELD_NAME = 'credit'.freeze
DATA_PREFIX ||= 'data-credit-toll-'.freeze

enabled_site_setting :credit_enabled

after_initialize do
  module ::DiscourseCredit
    DEFAULT_CREDIT_TOLL_NAME = 'credit_toll'.freeze
    CREDIT_TOLLS_CUSTOM_FIELD = 'credit_tolls'.freeze

    autoload :CreditTollsValidator, "#{Rails.root}/plugins/discourse-credit/lib/credit_tolls_validator"
    autoload :CreditTollsUpdater, "#{Rails.root}/plugins/discourse-credit/lib/credit_tolls_updater"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseCredit
    end

    def self.extract(raw, topic_id, user_id = nil)
      # TODO: we should fix the callback mess so that the cooked version is available
      # in the validators instead of cooking twice
      cooked = PrettyText.cook(raw, topic_id: topic_id, user_id: user_id)
      parsed = Nokogiri::HTML(cooked)

      extracted_tolls = []

      # extract tolls
      parsed.css("div.credit-toll").each do |p|
        toll = { "id" => [], "credit" => 0 }

        # extract attributes
        p.attributes.values.each do |attribute|
          if attribute.name.start_with?(DATA_PREFIX)
            toll[attribute.name[DATA_PREFIX.length..-1]] = attribute.value
          end
        end

        # add the toll
        extracted_tolls << toll
      end

      extracted_tolls
    end
  end

  DiscourseCredit::Engine.routes.draw do
    post '/credits' => 'credits#create'
    get '/credits/:post_id' => 'credits#show_records'

    post '/tolls' => 'tolls#create'
    get '/tolls/:post_id/:toll_id' => 'tolls#show'
    post '/tolls/:post_id/:toll_id' => 'tolls#purchase'
  end

  Discourse::Application.routes.append do
    mount ::DiscourseCredit::Engine, at: "/discourse_credit"
  end

  class DiscourseCredit::CreditManager
    def initialize(opts)
      @post = Post.find(opts[:post_id])
      @credit = opts[:credit]&.to_i
    end

    def create
      raise Discourse::InvalidParameters if @post.post_number != 1 || @post&.topic.archetype != Archetype.default
      raise Discourse::InvalidParameters if @credit > SiteSetting.credit_max_permit || credit < SiteSetting.credit_min_permit || credit == 0

      # post credit record
      credits = PluginStore.get(PLUGIN_NAME, post.id) || []
      credits.push('user_id' => current_user.id, 'credit' => credit)
      total = credits.sum { |c| c['credit'] }
      PluginStore.set(PLUGIN_NAME, post.id, credits)
      pf = PostCustomField.find_or_initialize_by(name: CREDIT_FIELD_NAME, post_id: post.id)
      pf.value = total
      pf.save!

      # user credit record
      user = post.user
      user_credits = PluginStore.get(PLUGIN_NAME, user.id) || []
      user_credits.push(user_id: current_user.id, post_id: post.id, credit: credit)
      PluginStore.set(PLUGIN_NAME, user.id, user_credits)

      # user credit
      user_credit = UserCustomField.find_or_initialize_by(user: user, name: CREDIT_FIELD_NAME)
      user_credit.value = user_credit.value.to_i + credit
      user_credit.save

      total
    end

    def purchase(customer)
      owner = @post.user
      return false if owner == customer

      purchased_record = PluginStore.get(PLUGIN_NAME, "#{@post.id}_purchased") || []
      return true if purchased_record.include?(customer.id)

      owner_credit = UserCustomField.find_or_initialize_by(user: owner, name: CREDIT_FIELD_NAME)
      customer_credit = UserCustomField.find_or_initialize_by(user: customer, name: CREDIT_FIELD_NAME)

      raise Discourse::InvalidAccess.new("Not enough credit") if customer_credit.value.to_i < @credit

      owner_credit.value = owner_credit.value.to_i + @credit
      owner_credit.save
      customer_credit.value = customer_credit.value.to_i - @credit
      customer_credit.save

      purchased_record.push(customer.id)
      PluginStore.set(PLUGIN_NAME, "#{@post.id}_purchased", purchased_record)

      true
    end
  end

  class DiscourseCredit::CreditsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in
    before_action :ensure_staff

    def create
      manager = DiscourseCredit::CreditManager.new(params)

      total = manager.create

      render json: { credit: total }, status: 201
    end

    def show_records
      post = Post.find(params[:post_id])
      record = PluginStore.get(PLUGIN_NAME, post.id)

      if record
        result = record.map { |r| { credit: r['credit'], user: BasicUserSerializer.new(User.find(r['user_id']), root: false).as_json } }
        render json: result, status: 200
      else
        render nothing: true, status: 404
      end
    end
  end

  class DiscourseCredit::TollsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in, except: [:show]

    def create
      raw = params[:content]
      credit = params[:credit].to_i

      raise Discourse::InvalidParameters if credit <= 0

      cooked = PrettyText.cook(raw)
      id = SecureRandom.hex
      PluginStore.set(PLUGIN_NAME, id, {
          raw: raw, cooked: cooked, credit: credit
      })

      render json: { id: id }, status: 200
    end

    def show
      return render json: { purchased: false } if current_user == nil

      post = Post.find(params[:post_id])
      guardian = Guardian.new(current_user)
      guardian.ensure_can_see!(post)

      toll_id = params[:toll_id]
      unless toll = post.custom_fields[DiscourseCredit::CREDIT_TOLLS_CUSTOM_FIELD][toll_id]
        raise Discourse::InvalidAccess.new("Can't see")
      end

      purchased_record = PluginStore.get(PLUGIN_NAME, "#{post.id}_purchased") || []
      if purchased_record.include?(current_user.id) || current_user.id == post.user.id || guardian.is_staff?
        render json: { purchsed: true, cooked: PluginStore.get(PLUGIN_NAME, toll_id)["cooked"] }, status: 200
      else
        render json: { purchased: false }, status: 200
      end
    end

    def purchase
      post = Post.find(params[:post_id])
      guardian = Guardian.new(current_user)
      guardian.ensure_can_see!(post)

      toll_id = params[:toll_id]
      unless toll = post.custom_fields[DiscourseCredit::CREDIT_TOLLS_CUSTOM_FIELD][toll_id]
        raise Discourse::InvalidAccess.new("Can't see")
      end

      manager = DiscourseCredit::CreditManager.new({post_id: post.id, credit: toll["credit"]})
      if manager.purchase(current_user)
        render json: success_json, status: 200
      else
        render nothing: true, status: 400
      end
    end
  end

  validate(:post, :validate_credit_tolls) do
    return if !SiteSetting.credit_enabled?

    # only care when raw has changed!
    return unless self.raw_changed?

    validator = DiscourseCredit::CreditTollsValidator.new(self)

    return unless (tolls = validator.validate_credit_tolls)

    # are we updating a post?
    if self.id.present?
      DistributedMutex.synchronize("#{PLUGIN_NAME}-#{self.id}") do
        DiscourseCredit::CreditTollsUpdater.update(self, tolls)
      end
    else
      custom_fields[DiscourseCredit::CREDIT_TOLLS_CUSTOM_FIELD] = tolls
    end

    true
  end

  Post.register_custom_field_type(DiscourseCredit::CREDIT_TOLLS_CUSTOM_FIELD, :json)

  # add_to_class(:post, :credit_score) { custom_fields[CREDIT_SCORE_FIELD_NAME] }
  add_to_serializer(:basic_post, :credit) { PostCustomField.find_by(name: CREDIT_FIELD_NAME, post_id: object.id)&.value&.to_i }
  add_to_serializer(:user, :credit) { UserCustomField.find_by(user_id: object.id, name: CREDIT_FIELD_NAME)&.value&.to_i || 0 }

  # new user
  DiscourseEvent.on(:user_created) do |user|
    user.custom_fields[CREDIT_FIELD_NAME] = 5
    user.save!
  end
  # new topic
  DiscourseEvent.on(:topic_created) do |_, _, user|
    user.custom_fields[CREDIT_FIELD_NAME] = user.custom_fields[CREDIT_FIELD_NAME].to_i + 1
    user.save!
  end
  # new post, replied post
  DiscourseEvent.on(:post_created) do |post, _, user|
    user.custom_fields[CREDIT_FIELD_NAME] = user.custom_fields[CREDIT_FIELD_NAME].to_i + 1
    user.save!
    replied_post = post.reply_to_post
    if replied_post && replied_post.user
      replied_post.user.custom_fields[CREDIT_FIELD_NAME] = replied_post.user.custom_fields[CREDIT_FIELD_NAME].to_i + 1
      replied_post.user.save!
    end
  end
  #like
  add_model_callback(:post_action, :after_create) do
    if is_like?
      post.user.custom_fields[CREDIT_FIELD_NAME] = post.user.custom_fields[CREDIT_FIELD_NAME].to_i + 2
      post.user.save!
    end
  end

  #post destory
  DiscourseEvent.on(:post_destroyed) do |post, _, _|
    post.user.custom_fields[CREDIT_FIELD_NAME] = post.user.custom_fields[CREDIT_FIELD_NAME].to_i - 3
    post.user.save!
  end

  #topic destroy
  DiscourseEvent.on(:topic_destroyed) do |topic, _|
    topic.user.custom_fields[CREDIT_FIELD_NAME] = topic.user.custom_fields[CREDIT_FIELD_NAME].to_i - 10
    topic.user.save!
  end
end