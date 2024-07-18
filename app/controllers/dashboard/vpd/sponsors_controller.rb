class Dashboard::Vpd::SponsorsController < DashboardController
  include Dashboard::VpdHelper

  before_action :get_vpd
  before_action :authenticate_verify_user
  before_action :authenticate_vpd_level_user

  # VPD Sponsor actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/sponsors(.:format)
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: SponsorDatatable.new(view_context, current_user, @vpd) }
    end
  end

  # GET   /dashboard/vpd/:vpd_id/sponsors/new(.:format)
  def new
    @sponsor = VpdSponsor.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/vpd/:vpd_id/sponsors(.:format)
  def create
    sponsor = Sponsor.where(name: params[:vpd_sponsor][:name])
    if sponsor.exists?
      sponsor     = sponsor.first
      vpd_sponsor = @vpd.vpd_sponsors.build(sponsor: sponsor)
    else
      sponsor = Sponsor.new(name: params[:vpd_sponsor][:name], status: 0)
      if sponsor.save
        vpd_sponsor = @vpd.vpd_sponsors.build(sponsor: sponsor)
      else
        key, val = sponsor.errors.messages.first
        data = {failure:{msg: sponsor.errors.full_messages.first, element_id: "vpd_sponsor_name"}}
      end
    end

    if data.nil?
      if vpd_sponsor.save
        data = {success:{msg: "Sponsor Added", name: vpd_sponsor.name}}
      else
        key, val = vpd_sponsor.errors.messages.first
        data = {failure:{msg: vpd_sponsor.errors.full_messages.first, element_id: "vpd_sponsor_name"}}
      end
    end

    render json: data
  end

  # POST  /dashboard/vpd/:vpd_id/sponsors/:sponsor_id/update_status(.:format) 
  def update_status
    model   = params[:object].constantize
    object  = model.find(params[:status_id])
    status  = params[:status]

    if model.name == Sponsor.name
      vpd_sponsor = @vpd.vpd_sponsors.build(sponsor: object, status: status)
    else
      vpd_sponsor = object
      vpd_sponsor.assign_attributes(status: status)
    end

    if vpd_sponsor.present? && vpd_sponsor.save
      render json: {success:{msg: "Updated #{params[:object]}", id: object.id.to_s}}
    else
      render json: {failure:{msg: vpd_sponsor.errors.full_messages.first}}
    end
  end
end