# frozen_string_literal: true

class RenameWoodeskRecordColumnsToChatwoot < ActiveRecord::Migration[7.1]
  def up
    rename_record_columns(:data_import_items, from: 'woodesk_record', to: 'chatwoot_record')
    rename_record_columns(:data_import_mappings, from: 'woodesk_record', to: 'chatwoot_record')
  end

  def down
    rename_record_columns(:data_import_items, from: 'chatwoot_record', to: 'woodesk_record')
    rename_record_columns(:data_import_mappings, from: 'chatwoot_record', to: 'woodesk_record')
  end

  private

  def rename_record_columns(table_name, from:, to:)
    rename_column(table_name, "#{from}_type", "#{to}_type") if column_exists?(table_name, "#{from}_type")
    rename_column(table_name, "#{from}_id", "#{to}_id") if column_exists?(table_name, "#{from}_id")
  end
end