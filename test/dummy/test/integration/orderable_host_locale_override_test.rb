# frozen_string_literal: true

require_relative "../test_helper"

class OrderableHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  HOST_BODY_AFTER = "HOST on the parent type whose children should be sortable."
  HOST_SUBTITLE =
    "HOST Opt in per recordable type. Sibling position lives on the child recording, not as a tree object."
  OVERRIDE_KEY = "recording_studio.orderable.home.body_after"
  SUBTITLE_KEY = "recording_studio.orderable.home.subtitle"
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_orderable_host.en.yml")
  FRESH_HOST_LOCALE = Rails.root.join("test/locales/orderable_host_override.en.yml")

  setup do
    @load_path_before = I18n.load_path.dup
    @backend_before = I18n.backend
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    Current.actor = @user
  end

  teardown do
    I18n.backend = @backend_before if @backend_before
    assert_equal @load_path_before, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  # Real-boot-order guard: host file under config/locales must win without any
  # test-time load_path mutation. Render assertion uses the rarely shown body_after.
  test "host locale override for recording_studio.orderable wins on boot order" do
    assert File.exist?(BOOT_HOST_LOCALE)
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_BODY_AFTER
    assert_equal HOST_BODY_AFTER, I18n.t(OVERRIDE_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    sign_in @user
    get "/recording_studio_orderable"

    assert_response :success
    assert_includes response.body, HOST_BODY_AFTER
    assert_includes response.body, "Recording Studio Orderable"
    refute_includes response.body, "translation missing"
  end

  # Test-only fixture applied via backend.load_translations(file) on top of the
  # already-initialized backend — never mutates I18n.load_path (Marshal).
  test "fresh-backend last-file-wins host fixture overrides gem english on overview" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_SUBTITLE

    sign_in @user

    snapshot = i18n_backend_translations_snapshot
    I18n.t(SUBTITLE_KEY)
    I18n.backend.load_translations(FRESH_HOST_LOCALE.to_s)

    assert_equal @load_path_before, I18n.load_path
    assert_equal HOST_SUBTITLE, I18n.t(SUBTITLE_KEY)
    assert_equal HOST_BODY_AFTER, I18n.t(OVERRIDE_KEY)

    get "/recording_studio_orderable"
    assert_response :success
    assert_includes response.body, HOST_SUBTITLE
    assert_includes response.body, HOST_BODY_AFTER
  ensure
    restore_i18n_backend_translations(snapshot) if snapshot
  end

  private

  def i18n_backend_translations_snapshot
    backend = I18n.backend
    backend.send(:init_translations) unless backend.initialized?
    translations =
      if backend.respond_to?(:translations)
        backend.translations
      else
        backend.instance_variable_get(:@translations)
      end
    return unless translations

    deep_plain_copy(translations)
  end

  def restore_i18n_backend_translations(snapshot)
    backend = I18n.backend
    backend.instance_variable_set(:@translations, snapshot)
    backend.instance_variable_set(:@initialized, true) if backend.instance_variable_defined?(:@initialized)
  end

  def deep_plain_copy(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, child), copy| copy[key] = deep_plain_copy(child) }
    when Array
      value.map { |child| deep_plain_copy(child) }
    else
      value
    end
  end
end
