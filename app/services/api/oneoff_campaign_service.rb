class Api::OneoffCampaignService
  pattr_initialize [:campaign!]

  DEFAULT_RATE_LIMIT = 60
  DEFAULT_MIN_DELAY = 0
  DEFAULT_MAX_DELAY = 0

  def perform
    raise "Campaign must be a one-off API inbox campaign" if campaign.inbox.inbox_type != 'API' || !campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?

    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    audience_labels = campaign.account.labels.where(id: audience_label_ids).pluck(:title)
    process_audience(audience_labels)
    campaign.completed!
  end

  private

  delegate :inbox, to: :campaign

  def rate_limit
    campaign.trigger_rules&.dig('rate_limit').to_i.positive? ? campaign.trigger_rules['rate_limit'].to_i : DEFAULT_RATE_LIMIT
  end

  def min_delay
    campaign.trigger_rules&.dig('min_delay').to_i || DEFAULT_MIN_DELAY
  end

  def max_delay
    delay = campaign.trigger_rules&.dig('max_delay').to_i || DEFAULT_MAX_DELAY
    [delay, min_delay].max
  end

  def process_audience(audience_labels)
    contacts = campaign.account.contacts.tagged_with(audience_labels, any: true)
    Rails.logger.info "[API Campaign #{campaign.id}] Processing #{contacts.count} contacts"

    message_count = 0
    window_start = Time.current

    contacts.each do |contact|
      window_start, message_count = enforce_rate_limit(window_start, message_count)
      send_to_contact(contact)
      message_count += 1
      apply_random_delay
    end
  end

  def enforce_rate_limit(window_start, message_count)
    return [window_start, message_count] if rate_limit <= 0

    if message_count >= rate_limit
      elapsed = Time.current - window_start
      sleep(60 - elapsed) if elapsed < 60
      window_start = Time.current
      message_count = 0
    end

    [window_start, message_count]
  end

  def apply_random_delay
    return if max_delay <= 0

    delay = rand(min_delay..max_delay)
    sleep(delay) if delay.positive?
  end

  def send_to_contact(contact)
    contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
    return if contact_inbox.nil?

    conversation = find_or_create_conversation(contact_inbox)
    return if conversation.nil?

    content = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)
    Messages::MessageBuilder.new(campaign.sender, conversation, message_params(content)).perform
  rescue StandardError => e
    Rails.logger.error "[API Campaign #{campaign.id}] Failed to send to contact #{contact.id}: #{e.message}"
  end

  def find_or_create_conversation(contact_inbox)
    existing = contact_inbox.conversations.where(inbox: inbox).last
    return existing if existing

    Conversation.create!(
      account_id: campaign.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      campaign_id: campaign.id
    )
  end

  def message_params(content)
    ActionController::Parameters.new(
      content: content,
      campaign_id: campaign.id
    )
  end
end
