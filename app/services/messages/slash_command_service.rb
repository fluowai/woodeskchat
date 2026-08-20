class Messages::SlashCommandService
  pattr_initialize [:message]

  def perform
    return unless message.outgoing? && message.content.to_s.start_with?('/')
    
    command, *args = message.content.split(' ')

    case command
    when '/pix'
      process_pix_command(args)
    end
  end

  private

  def process_pix_command(args)
    # /pix 100.00
    amount = args.first
    return unless amount.present?

    # Using our new PixService to generate the PIX code
    # This acts as a proxy for Asaas or Mercado Pago
    pix_payload = Billing::PixService.new(
      account: message.account,
      conversation: message.conversation,
      amount: amount
    ).perform

    # Send a new message to the customer with the PIX Copia e Cola
    pix_message = message.conversation.messages.create!(
      account_id: message.account_id,
      inbox_id: message.inbox_id,
      message_type: :outgoing,
      content: "Aqui está o seu PIX no valor de R$ #{amount}:\n\n#{pix_payload[:copy_paste]}\n\nApós o pagamento, o sistema confirmará automaticamente.",
      private: false
    )
  end
end
