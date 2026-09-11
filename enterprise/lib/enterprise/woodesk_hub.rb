module Enterprise::WoodeskHub
  ENTERPRISE_BASE_URL = 'https://hub.2.woodesk.com'.freeze

  def base_url
    ENV.fetch('WOODESK_HUB_URL', ENTERPRISE_BASE_URL)
  end
end
