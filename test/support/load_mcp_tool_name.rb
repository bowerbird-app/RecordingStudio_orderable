# frozen_string_literal: true

module LoadMcpToolName
  SOURCE = "https://github.com/bowerbird-app/RecordingStudio_MCP.git"
  TAG = "v0.45.2"

  module_function

  def load!
    return if defined?(::RecordingStudioMcp) && ::RecordingStudioMcp.respond_to?(:tool_name)

    require "recording_studio_api" unless defined?(::RecordingStudioApi)
    lib = lib_path
    $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
    require "recording_studio_mcp/tool_name"
    return if ::RecordingStudioMcp.respond_to?(:tool_name)

    ::RecordingStudioMcp.define_singleton_method(:tool_name) do |type, action|
      ::RecordingStudioMcp::ToolName.call(type, action)
    end
  end

  def lib_path
    spec = Gem.loaded_specs["recording_studio_mcp"]
    return File.join(spec.full_gem_path, "lib") if spec

    root = "/tmp/recording_studio_mcp-#{TAG}"
    script = File.join(root, "lib/recording_studio_mcp/tool_name.rb")
    clone_source(root) unless File.exist?(script)
    File.join(root, "lib")
  end

  def clone_source(root)
    system(
      "git", "clone", "--quiet", "--depth", "1", "--branch", TAG, SOURCE, root,
      exception: true, out: File::NULL, err: File::NULL
    )
  end
end
