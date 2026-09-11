module Billing
  class PixService
    pattr_initialize [:account, :conversation, :amount]

    def perform
      # MOCK: Integração Asaas / Mercado Pago
      # Em um ambiente real, aqui faríamos uma chamada HTTP para a API do Asaas:
      # Asaas::Payment.create(
      #   customer: customer_id,
      #   billingType: 'PIX',
      #   value: amount
      # )
      # 
      # E retornaríamos o payload do PIX.

      # Gerando um hash fake simulando um PIX Copia e Cola da Asaas/MP
      transaction_id = SecureRandom.hex(10)
      
      {
        transaction_id: transaction_id,
        copy_paste: "00020126580014br.gov.bcb.pix0136fake-asaas-or-mp-pix-key-#{transaction_id}5204000053039865802BR5925Woodesk Payments LTDA6009Sao Paulo62070503***6304XXXX",
        provider: "asaas"
      }
    end
  end
end
