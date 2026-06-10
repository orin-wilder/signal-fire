class Host::Events::DescriptionsController < Host::ApplicationController
  # JSON endpoints backing the description-assist Stimulus controller. They take
  # the current textarea contents and return AI-rewritten / summarized text for
  # the host to review — nothing is persisted here.
  def enhance
    with_text { |text| render_assist(Ai::DescriptionAssistant.enhance(text: text)) }
  end

  def summarize
    with_text { |text| render_assist(Ai::DescriptionAssistant.summarize(text: text)) }
  end

  private

  def with_text
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
