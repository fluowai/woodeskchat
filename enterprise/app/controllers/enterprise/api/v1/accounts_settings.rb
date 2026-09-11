module Enterprise::Api::V1::AccountsSettings
  def create
    super
    record_marketing_attribution
  end

  private

  # The upgrade banner is a self-hosted nudge; the managed cloud instance is always current.
  def latest_woodesk_version
    return if WoodeskApp.woodesk_cloud?

    super
  end

  def record_marketing_attribution
    return if current_user.present?
    return if @account.blank?

    Internal::Accounts::MarketingAttributionService.new(account: @account, cookies: cookies).perform
  rescue StandardError => e
    WoodeskExceptionTracker.new(e).capture_exception
  end

  def permitted_settings_attributes
    super + [{ conversation_required_attributes: [] }]
  end
end
