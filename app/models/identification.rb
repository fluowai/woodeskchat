class Identification < ApplicationRecord
  belongs_to :account

  IDENTIFIER_TYPES = %w[cpf cnpj rg other].freeze

  validates :identifier_type, presence: true, inclusion: { in: IDENTIFIER_TYPES }
  validates :value, presence: true, uniqueness: { scope: [:account_id, :identifier_type] }
  validates :zip_code, format: { with: /\A\d{5}-\d{3}\z/, message: 'formato CEP inválido' }, allow_blank: true

  # Helpers for common Brazilian identifiers
  def formatted_value
    case identifier_type
    when 'cpf'
      value.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\\1.\\2.\\3-\\4')
    when 'cnpj'
      value.gsub(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '\\1.\\2.\\3/\\4-\\5')
    else
      value
    end
  end
end