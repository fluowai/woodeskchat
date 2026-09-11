json.partial! 'api/v1/models/account', formats: [:json], resource: @account
json.latest_woodesk_version @latest_woodesk_version
json.partial! 'enterprise/api/v1/accounts/partials/account', account: @account if WoodeskApp.enterprise?
