# frozen_string_literal: true

return unless defined?(RecordingStudioApi)

RecordingStudioApi.configure do |config|
  config.documentation_enabled = true
  config.documentation_access = :public
  config.openapi_title = "Orderable API"
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_fail_closed = false
  config.api_management_authorization_required = false
end

{
  "Workspace" => { keys: %i[name], operations: %i[index show] },
  "Project" => { keys: %i[name slug], operations: %i[index show create update] },
  "Folder" => {
    keys: %i[name slug],
    operations: %i[index show create update],
    capability_actions: %i[reorder move_position],
    auto_capability_actions: false
  },
  "Page" => { keys: %i[title slug body], operations: %i[index show create update] }
}.each do |type, options|
  next if RecordingStudioApi.recordable_registration_for(type)

  keys = options.fetch(:keys)
  RecordingStudioApi.register_recordable_type_api(
    type,
    operations: options.fetch(:operations),
    capability_actions: options[:capability_actions],
    auto_capability_actions: options.fetch(:auto_capability_actions, false),
    serializer: ->(recordable, **) { keys.index_with { |key| recordable.public_send(key) } },
    output_keys: keys,
    writable_attributes: keys
  )
end
