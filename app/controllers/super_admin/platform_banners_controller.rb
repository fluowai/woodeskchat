class SuperAdmin::PlatformBannersController < SuperAdmin::ApplicationController
  before_action :ensure_woodesk_cloud

  private

  def ensure_woodesk_cloud
    raise ActionController::RoutingError, 'Not Found' unless WoodeskApp.woodesk_cloud?
  end
end
