# frozen_string_literal: true

require_relative "../test_helper"

class OrderableHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  GEM_BODY_AFTER = "Add this to the parent type whose children should be sortable."
  HOST_BODY_AFTER = "HOST Add this to the parent type whose children should be sortable."
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
    refute_includes File.read(BOOT_HOST_LOCALE), "body_after: \"#{GEM_BODY_AFTER}\""
    assert_equal HOST_BODY_AFTER, I18n.t(OVERRIDE_KEY)
    refute_equal GEM_BODY_AFTER, I18n.t(OVERRIDE_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    sign_in @user
    get "/recording_studio_orderable"

    assert_response :success
    assert_includes response.body, HOST_BODY_AFTER
    assert_includes response.body, "Recording Studio Orderable"
    refute_includes response.body, "translation missing"
  end

  # Fixture lives on a fresh backend chained in front of the booted backend.
  # Teardown puts the original backend back. I18n.load_path stays untouched.
  test "fresh-backend last-file-wins host fixture overrides gem english on overview" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_SUBTITLE

    sign_in @user

    front = I18n::Backend::Simple.new
    front.eager_load!
    front.load_translations(FRESH_HOST_LOCALE.to_s)
    I18n.backend = front

    assert_equal @load_path_before, I18n.load_path
    assert_equal HOST_SUBTITLE, I18n.t(SUBTITLE_KEY)
    assert_equal GEM_BODY_AFTER, I18n.t(OVERRIDE_KEY)

    get "/recording_studio_orderable"
    assert_response :success
    assert_includes response.body, HOST_SUBTITLE
    assert_includes response.body, GEM_BODY_AFTER
  end
end
