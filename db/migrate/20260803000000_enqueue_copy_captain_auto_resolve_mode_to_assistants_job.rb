class EnqueueCopyCaptainAutoResolveModeToAssistantsJob < ActiveRecord::Migration[7.1]
  def up
    Migration::CopyCaptainAutoResolveModeToAssistantsJob.perform_later if WoodeskApp.enterprise?
  end

  def down; end
end
