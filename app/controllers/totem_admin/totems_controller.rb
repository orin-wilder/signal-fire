class TotemAdmin::TotemsController < TotemAdmin::ApplicationController
  def index
    @totems = moderated_totems
  end
end
