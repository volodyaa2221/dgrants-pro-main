class Dashboard::Site::PaymentController < DashboardController
  include Dashboard::SiteHelper

  before_action :get_site
  before_action :authenticate_verify_user
  before_action :authenticate_site_details_editable_user, only: [:new, :create, :edit, :update]
  before_action :authenticate_site_editable_user,         except: :index
  before_action :authenticate_site_level_user,            only: :index

  # Site Payment actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/:site_id/payment_information(.:format)
  def payment_information
    @src_url = build_iframe_url("DrugDev", @site.id.to_s, "QKkdTMYktsY43tJJP9ZDLe+oN2i2kBgPwrR2bcKC+Bjvyy0SMXOTBgVizeiQWHss")

    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
    end
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  def build_iframe_url(payer, payee_id, secret_key, parameters=nil)
    # base_url = "https://ui.tipalti.com" # production
    base_url = "https://ui.sandbox.tipalti.com" # sandbox
    base_url + "/Payees/PayeeDashboard.aspx?" + build_query_string(payer, payee_id, secret_key, parameters)
  end

  def build_query_string(payer, payee_id, secret_key, parameters=nil)
    ts = Time.now.to_i # timestamp is seconds since Unix epoch in seconds.
    query_pairs = {"payer" => payer, "idap" => payee_id, "ts" => ts.to_s} # Hash["payer" => payer, "idap" => payee_id, "ts" => ts.to_s]

    # add the optionsal parameters
    parameters.each{|k, v| query_pairs[k] = v} unless parameters.nil?
    p query_pairs
    qs = query_pairs.map{|k, v| "#{URI.encode(k)}=#{URI.encode(v)}"}.join("&")
    qs += "&hashkey=#{encrypt_query_string(qs, secret_key)}"  
  end

  def encrypt_query_string(qs, secret)
    # hmac256 -> convert to hex -> add leading 0 to values below 0x10
    OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), secret, qs).each_byte.map{|b| b.to_s(16).rjust(2, '0')}.join
  end
end