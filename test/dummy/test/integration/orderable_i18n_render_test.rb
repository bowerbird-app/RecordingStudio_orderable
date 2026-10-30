# frozen_string_literal: true

require_relative "../test_helper"

# Render-level literal-English asserts for orderable overview copy.
# English output must match main. Boot-order HOST override for body_after is
# asserted in OrderableHostLocaleOverrideTest, not here.
class OrderableI18nRenderTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    Current.actor = @user
  end

  test "engine overview page renders literal english from gem keys" do
    sign_in @user
    get "/recording_studio_orderable"

    assert_response :success
    assert_select "h1", count: 1, text: "Recording Studio Orderable"
    assert_select "body[data-recording-studio-default-layout='true']"
    assert_includes response.body, "Orderable"
    assert_includes response.body, "Home"
    assert_includes response.body, "Recording Studio Orderable"
    assert_includes response.body, "Opt in per recordable type. Sibling position lives on the child recording, not as a tree object."
    assert_includes response.body, "Enable ordering"
    assert_includes response.body, "include RecordingStudio::Capabilities::Orderable.to HOST"
    assert_includes response.body, "Add this to the parent type whose children should be sortable."
    refute_includes response.body, "translation missing"
  end

  test "engine overview falls back to english default when locale has no key" do
    sign_in @user
    previous_locale = I18n.locale
    previous_available = I18n.available_locales

    I18n.available_locales = previous_available | [:fr]
    I18n.locale = :fr
    get "/recording_studio_orderable"

    assert_response :success
    assert_includes response.body, "Recording Studio Orderable"
    assert_includes response.body, "Opt in per recordable type. Sibling position lives on the child recording, not as a tree object."
    assert_includes response.body, "Enable ordering"
    assert_includes response.body, "Add this to the parent type whose children should be sortable."
    refute_includes response.body, "translation missing"
  ensure
    I18n.locale = previous_locale if previous_locale
    I18n.available_locales = previous_available if previous_available
  end
end
