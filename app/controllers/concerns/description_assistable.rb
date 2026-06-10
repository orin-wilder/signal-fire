# Shared JSON endpoints for AI description assist. Takes the current text and
# returns AI-rewritten ("enhance") or condensed ("summarize") text for review —
# nothing is persisted. Included by both the host event form and the admin
# bulletin-post form.
module DescriptionAssistable
  extend ActiveSupport::Concern

  def enhance
    with_assist_text { |text| render_assist(Ai::DescriptionAssistant.enhance(text: text)) }
  end

  def summarize
    with_assist_text { |text| render_assist(Ai::DescriptionAssistant.summarize(text: text)) }
  end

  private

  def with_assist_text
    text = params[:text].to_s
    if text.strip.blank?
      render json: { error: "Write a description first." }, status: :unprocessable_entity
    else
      yield text
    end
  end

  def render_assist(result)
    if result.ok
      render json: { text: result.text }
    else
      render json: { error: "Couldn't do that right now. Try again." }, status: :unprocessable_entity
    end
  end
end
