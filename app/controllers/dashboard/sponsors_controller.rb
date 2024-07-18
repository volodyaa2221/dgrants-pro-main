class Dashboard::SponsorsController < DashboardController
  before_action :authenticate_verify_user
  before_action :authenticate_super_admin

  # Sponsor actions
  #----------------------------------------------------------------------
  # GET   /dashboard/sponsors(.:format)
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: SponsorDatatable.new(view_context, current_user) }
    end
  end

  # GET /dashboard/sponsors/new
  def new
    @sponsor = Sponsor.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/sponsors(.:format)
  def create
    sponsor = Sponsor.new(sponsor_params)
    if sponsor.save
      data = {success:{msg: "Sponsor Added", name: sponsor.name}}
    else
      key, val = sponsor.errors.messages.first
      data = {failure:{msg: sponsor.errors.full_messages.first, element_id: "sponsor_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/sponsors/:id/edit(.:format)
  def edit
    @sponsor = Sponsor.find(params[:id])
    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/sponsors/:id(.:format) 
  def update
    sponsor = Sponsor.find(params[:id])
    if sponsor.update_attributes(sponsor_params)
      data = {success:{msg: "Sponsor Updated", name: sponsor.name}}
    else
      key, val = sponsor.errors.messages.first
      data = {failure:{msg: sponsor.errors.full_messages.first, element_id: "sponsor_#{key}"}}
    end

    render json: data
  end


  # Private methods
  #----------------------------------------------------------------------
  private

  def sponsor_params
    params.require(:sponsor).permit(:name)
  end
end