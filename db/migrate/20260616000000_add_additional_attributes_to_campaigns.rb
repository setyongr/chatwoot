class AddAdditionalAttributesToCampaigns < ActiveRecord::Migration[7.1]
  def change
    add_column :campaigns, :additional_attributes, :jsonb, default: {}
  end
end
