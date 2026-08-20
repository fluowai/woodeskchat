# frozen_string_literal: true

class AccountBuilder
  include CustomExceptions::Account
  pattr_initialize [:account_name, :email!, :confirmed, :user, :user_full_name, :user_password, :super_admin, :locale]

  def perform
    if @user.nil?
      validate_email
      validate_user
    end
    ActiveRecord::Base.transaction do
      @account = create_account
      @user = create_and_link_user
    end
    [@user, @account]
  rescue StandardError => e
    Rails.logger.debug e.inspect
    raise e
  end

  private

  def user_full_name
    # the empty string ensures that not-null constraint is not violated
    @user_full_name || ''
  end

  def account_name
    # the empty string ensures that not-null constraint is not violated
    @account_name || ''
  end

  def validate_email
    Account::SignUpEmailValidationService.new(@email).perform
  end

  def validate_user
    if User.exists?(email: @email)
      raise UserExists.new(email: @email)
    else
      true
    end
  end

  def create_account
    @account = Account.create!(
      name: account_name,
      locale: 'pt_BR', # Forcing pt_BR default for Brazilian market
      custom_attributes: { 'onboarding_step' => 'account_details' }
    )
    Current.account = @account

    # Create native Brazilian custom attributes for the new account
    @account.custom_attribute_definitions.create!([
      {
        attribute_display_name: 'CPF',
        attribute_key: 'cpf',
        attribute_description: 'Cadastro de Pessoa Física',
        attribute_model: 'contact_attribute',
        attribute_display_type: 'text'
      },
      {
        attribute_display_name: 'CNPJ',
        attribute_key: 'cnpj',
        attribute_description: 'Cadastro Nacional da Pessoa Jurídica',
        attribute_model: 'contact_attribute',
        attribute_display_type: 'text'
      }
    ])
  end

  def create_and_link_user
    if @user.present? || create_user
      link_user_to_account(@user, @account)
      @user
    else
      raise UserErrors.new(errors: @user.errors)
    end
  end

  def link_user_to_account(user, account)
    AccountUser.create!(
      account_id: account.id,
      user_id: user.id,
      role: AccountUser.roles['administrator']
    )
  end

  def create_user
    @user = User.new(email: @email,
                     password: user_password,
                     password_confirmation: user_password,
                     name: user_full_name)
    @user.type = 'SuperAdmin' if @super_admin
    @user.confirm if @confirmed
    @user.save!
  end
end
