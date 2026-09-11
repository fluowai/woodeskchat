module Enterprise::Concerns::User
  extend ActiveSupport::Concern

  included do
    before_validation :ensure_installation_pricing_plan_quantity, on: :create

    has_many :captain_responses, class_name: 'Captain::AssistantResponse', dependent: :nullify, as: :documentable
    has_many :copilot_threads, dependent: :destroy_async
  end

  def ensure_installation_pricing_plan_quantity
    return unless WoodeskHub.pricing_plan == 'premium'

    errors.add(:base, 'User limit reached. Please purchase more licenses from super admin') if User.count >= WoodeskHub.pricing_plan_quantity
  end
end
