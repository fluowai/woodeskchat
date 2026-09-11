# Handles Brazil phone number normalization
# ref: https://github.com/woodesk/woodesk/issues/5840
#
# Brazil changed its mobile number system by adding a "9" prefix to existing numbers.
# This normalizer adds the "9" digit if the number is 12 digits (making it 13 digits total)
# to match the new format: 55 + DDD + 9 + number
class Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer < Whatsapp::PhoneNormalizers::BasePhoneNormalizer
  COUNTRY_CODE_LENGTH = 2
  DDD_LENGTH = 2

  # Normaliza número brasileiro para o formato E.164 (+55DDDNXXXXX)
  # Aceita WAIDs com ou sem o símbolo '+' e com ou sem o dígito "9" adicional.
  # Caso o número tenha 12 dígitos (ex.: 551199999999), adiciona o "9" para o novo padrão móvel.
  def normalize(waid)
    return waid unless handles_country?(waid)

    # Remove possível '+' inicial
    waid = waid.sub(/^\+/, '')
    ddd = waid[COUNTRY_CODE_LENGTH, DDD_LENGTH]
    number = waid[(COUNTRY_CODE_LENGTH + DDD_LENGTH)..]
    # Se o número já possui 9 dígitos locais, mantém; caso contrário, insere o 9.
    number = "9#{number}" if number && number.length == 8 && !number.start_with?("9")
    # Monta no padrão E.164 com '+'
    "+55#{ddd}#{number}"
  end

  private

  def country_code_pattern
    /^55/
  end
end
