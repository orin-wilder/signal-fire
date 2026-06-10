class Host::Events::DescriptionsController < Host::ApplicationController
  # Enhance + summarize JSON endpoints backing the description-assist Stimulus
  # controller on the host event form. Logic lives in DescriptionAssistable.
  include DescriptionAssistable
end
