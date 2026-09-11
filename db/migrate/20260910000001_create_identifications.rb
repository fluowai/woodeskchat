class CreateIdentifications < ActiveRecord::Migration[7.1]
  def change
    create_table :identifications do |t|
      t.references :account, null: false, foreign_key: true
      t.string :identifier_type, null: false # :cpf, :cnpj, :rg, etc.
      t.string :value, null: false
      t.string :name
      t.string :fantasy_name
      t.string :state_registration
      t.string :municipal_registration
      t.string :zip_code
      t.string :address
      t.string :city
      t.string :state
      t.string :country, default: 'BR'
      t.timestamps
    end
    add_index :identifications, [:account_id, :identifier_type, :value], unique: true, name: 'index_identifications_on_account_and_type_and_value'
  end
end