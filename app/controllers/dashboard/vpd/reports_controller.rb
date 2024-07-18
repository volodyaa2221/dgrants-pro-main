class Dashboard::Vpd::ReportsController < DashboardController
  include Dashboard::VpdHelper

  before_action :get_vpd
  before_action :authenticate_verify_user
  before_action :authenticate_vpd_level_user

  # VPD Report actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/reports(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: VpdReportDatatable.new(view_context, @vpd) }
    end
  end

  # GET   /dashboard/vpd/:vpd_id/reports/new(.:format) 
  def new
    @report = VpdReport.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/vpd/:vpd_id/reports(.:format) 
  def create
    report = @vpd.vpd_reports.build(report_params)
    if report.save
      render json: {success:{msg: "Report Added", name: report.name}}
    else
      key, val = vpd.errors.messages.first
      render json: {failure:{msg: vpd.errors.full_messages.first, element_id: "vpd_report_#{key}"}}
    end
  end

  # GET   /dashboard/vpd/:vpd_id/reports/:id/edit(.:format) 
  def edit
    
  end

  # PUT|PATCH   /dashboard/vpd/:vpd_id/reports/:id(.:format) 
  def update
    
  end

  # GET   /dashboard/vpd/:vpd_id/reports/:id(.:format)
  def show
    @report = VpdReport.find(params[:id])
    render layout: params[:type] != "ajax"
  end


  # Private methods
  #----------------------------------------------------------------------
  private
  def report_params
    params.require(:vpd_report).permit(:name, :url)
  end
end