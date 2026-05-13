module ApplicationHelper
  def page_order_page_cell(row)
    safe_join([
      content_tag(:span, row.recording.recordable.title, class: "font-medium"),
      render(
        FlatPack::Badge::Component.new(
          text: row.explicitly_ordered ? "Explicit" : "Auto-appended eligible page",
          style: row.explicitly_ordered ? :info : :warning,
          size: :sm,
          class: "ml-2"
        )
      )
    ])
  end
end
