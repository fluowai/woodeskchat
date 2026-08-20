class Webhooks::PaymentsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def asaas
    # Payload format: { event: "PAYMENT_RECEIVED", payment: { id: "pay_123", value: 100 } }
    event = params[:event]
    
    if event == 'PAYMENT_RECEIVED'
      # Simulating payment confirmation logic
      # We would look up the conversation associated with the payment and send a confirmation message
      Rails.logger.info "Pagamento PIX via Asaas recebido com sucesso: #{params[:payment]}"
    end

    head :ok
  end

  def mercadopago
    # Payload format: { action: "payment.updated", data: { id: "123" } }
    action = params[:action]
    
    if action == 'payment.updated'
      # We would fetch MP API to check if it's approved, and notify the conversation
      Rails.logger.info "Webhook Mercado Pago recebido com sucesso: #{params[:data]}"
    end

    head :ok
  end
end
