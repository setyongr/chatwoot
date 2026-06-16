class Api::V1::Accounts::CampaignsController < Api::V1::Accounts::BaseController
  before_action :campaign, except: [:index, :create]
  before_action :check_authorization

  def index
    @campaigns = Current.account.campaigns
  end

  def show; end

  def report
    conversations = Conversation.where(campaign_id: @campaign.id)
    messages = Message.where("additional_attributes->>'campaign_id' = ?", @campaign.id.to_s)

    render json: {
      total_contacts: conversations.count,
      messages_sent: messages.count,
      messages_failed: @campaign.failed_count,
      status: @campaign.campaign_status,
      scheduled_at: @campaign.scheduled_at
    }
  end

  def create
    @campaign = Current.account.campaigns.create!(campaign_params)
  end

  def update
    @campaign.update!(campaign_params)
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  private

  def campaign
    @campaign ||= Current.account.campaigns.find_by(display_id: params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:title, :description, :message, :enabled, :trigger_only_during_business_hours, :inbox_id, :sender_id,
                                     :scheduled_at, audience: [:type, :id], trigger_rules: {}, template_params: {})
  end
end
