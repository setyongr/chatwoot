class Api::OneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    raise "Campaign #{campaign.id} must be a one-off campaign with an API inbox" if campaign.inbox.inbox_type != 'Api' || !campaign.one_off?
    raise 'Cannot execute a campaign that has already been completed' if campaign.completed?

    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    audience_labels = campaign.account.labels.where(id: audience_label_ids).pluck(:title)
    process_audience(audience_labels)
    campaign.completed!
  end

  private

  delegate :inbox, to: :campaign

  def message_delay
    campaign.additional_attributes&.fetch('message_delay', 0).to_f
  end

  def sleep_duration
    base = message_delay
    base + rand(0.0..base)
  end

  def process_audience(audience_labels)
    contacts = campaign.account.contacts.tagged_with(audience_labels, any: true)
    Rails.logger.info "Processing #{contacts.count} contacts for API campaign #{campaign.id}"

    contacts.find_each(batch_size: 100) do |contact|
      process_contact(contact)
      sleep(sleep_duration) if message_delay.positive?
    end

    Rails.logger.info "API campaign #{campaign.id} processing completed"
  end

  def process_contact(contact)
    contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
    return if contact_inbox.nil?

    if contact_inbox.conversations.where(campaign_id: campaign.id).exists?
      Rails.logger.info "Skipping contact #{contact.id} - campaign conversation already exists"
      return
    end

    content = render_message(contact)
    create_conversation_with_message(contact_inbox, content)
  rescue StandardError => e
    Rails.logger.error "[API Campaign #{campaign.id}] Failed to process contact #{contact.id}: #{e.message}"
  end

  def render_message(contact)
    Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)
  rescue StandardError => e
    Rails.logger.error "[API Campaign #{campaign.id}] Liquid template error for contact #{contact.id}: #{e.message}"
    campaign.message
  end

  def create_conversation_with_message(contact_inbox, content)
    ActiveRecord::Base.transaction do
      conversation = Conversation.create!(
        account_id: campaign.account_id,
        inbox_id: inbox.id,
        contact_id: contact_inbox.contact_id,
        contact_inbox_id: contact_inbox.id,
        campaign_id: campaign.id
      )
      Messages::MessageBuilder.new(
        campaign.sender,
        conversation,
        ActionController::Parameters.new(content: content, campaign_id: campaign.id)
      ).perform
    end
  end
end
