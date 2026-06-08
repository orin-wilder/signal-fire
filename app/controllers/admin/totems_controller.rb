class Admin::TotemsController < Admin::ApplicationController
  before_action :set_totem, only: [:edit, :update, :destroy, :qr, :board_qr]

  def index
    @totems = Totem.includes(:host_totem_assignments)
                   .order(:name)
    @totems = @totems.where("name ILIKE :q OR location ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
  end

  def new
    @totem = Totem.new
  end

  def create
    @totem = Totem.new(totem_params)

    if @totem.save
      redirect_to admin_totems_path, notice: "Totem created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @totem.update(totem_params)
      redirect_to admin_totems_path, notice: "Totem updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @totem.destroy
    redirect_to admin_totems_path, notice: "Totem deleted."
  end

  def qr
    url = totem_board_url(slug: @totem.slug)
    qr = RQRCode::QRCode.new(url)
    png = qr.as_png(size: 300, border_modules: 4)
    send_data png.to_s,
              type: "image/png",
              disposition: "attachment",
              filename: "#{@totem.slug}-qr.png"
  end

  # QR pointing at the public bulletin board (the paint-stick sign target).
  def board_qr
    url = bulletin_board_url(@totem.slug)
    qr = RQRCode::QRCode.new(url)
    png = qr.as_png(size: 300, border_modules: 4)
    send_data png.to_s,
              type: "image/png",
              disposition: "attachment",
              filename: "#{@totem.slug}-board-qr.png"
  end

  private

  def set_totem
    @totem = Totem.find(params[:id])
  end

  def totem_params
    params.require(:totem).permit(:name, :location, :sublocation, :active, :character_description, :neighborhood)
  end
end
