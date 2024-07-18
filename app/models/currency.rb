class Currency < ActiveRecord::Base

  # Constants
  #----------------------------------------------------------------------
  API_BASE_URL = "https://devapi.thecurrencycloud.com/v2"
  API_KEY = "71c91c83e7d2e7b07b45d4f73458918ab33fa7cd8a133b5e00548454815a92ce"
  API_USER = "hugo.cc%40latholdings.com"

  # Associations
  #----------------------------------------------------------------------
  has_many :vpd_currencies
  has_many :trial_schedules
  has_many :site_schedules
  has_many :invoices

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of   :code, :rate
  validates_uniqueness_of :code, case_sensitive: false

  # Scopes
  #----------------------------------------------------------------------
  scope :activated_currencies, -> {where(status: 1)}

  # Callbacks
  #----------------------------------------------------------------------
  after_update :update_currencies

  # Class methods
  #----------------------------------------------------------------------
  # Update exchange rates with API
  def self.update_rates
    p "$$$$$$$$$$$$$$$$$ Currency.update_rates : START $$$$$$$$$$$$$$$$$$$$$$$$$$$"
    p "Start updating exchange rates..."

    token = Currency.currency_cloud_token
    return unless token.present?
    p "$$$$$ Token: #{token}"

    response = RestClient::Request.execute(url: "#{API_BASE_URL}/reference/currencies", method: :get, verify_ssl: false, headers: {"X-Auth-Token" => token}) 
    return if response.code != 200
    response = JSON.parse(response)
    codes = response["currencies"].map{|currency| currency["code"]}
    currency_pairs = nil
    Currency.where("code != 'USD'").each do |currency|
      if codes.include?(currency.code)
        if currency_pairs.present?
          currency_pairs = "#{currency_pairs},#{currency.code}USD" 
        else
          currency_pairs = "#{currency.code}USD" 
        end
      end
    end

    response = RestClient::Request.execute(url: "#{API_BASE_URL}/rates/find?currency_pair=#{currency_pairs}", method: :get, verify_ssl: false, headers: {"X-Auth-Token" => token}) 
    return if response.code != 200
    response = JSON.parse(response)
    rates = response["rates"]
    rates.each do |rate|
      code = rate[0].gsub("USD", '')
      currency = Currency.where(code: code).first
      p "$$$$$ #{rate[0]}, #{rate[1]}, #{currency.code}"
      currency.update_attributes(rate: rate[1][0].to_f)
    end    
    p "$$$$$$$$$$$$$$$$$ Currency.update_rates : END $$$$$$$$$$$$$$$$$$$$$$$$$$$"
  end

  # Get required beneficiary details for payment with API
  def self.required_beneficiary_details(currency, bank_account_country)
    p "$$$$$$$$$$$$$$$$$ Currency.required_beneficiary_details : START $$$$$$$$$$$$$$$$$$$$$$$$$$$"

    token = Currency.currency_cloud_token
    return unless token.present?

    response = RestClient::Request.execute(url: "#{API_BASE_URL}/reference/beneficiary_required_details?currency=#{currency}&bank_account_country=#{bank_account_country}", 
                                          method: :get, verify_ssl: false, headers: {"X-Auth-Token" => token}) 
    return nil if response.code != 200
    response = JSON.parse(response)
    p "$$$$$ #{response}"
    p "$$$$$$$$$$$$$$$$$ Currency.required_beneficiary_details : END $$$$$$$$$$$$$$$$$$$$$$$$$$$"
    return response
  end
  # Collection methods
  #----------------------------------------------------------------------

  # Attribute methods
  #----------------------------------------------------------------------
  # Public: Set code as CAPs
  def code=(val)
    self[:code] = val.upcase
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  # Private: Update VPD Currencies, Transactions and Invoices when the Currency is changed
  def update_currencies
    currency = self
    unless currency.status_changed?
      vpd_currencies.each {|vpd_currency| vpd_currency.update_attributes(code: currency.code, description: currency.description, symbol: currency.symbol, rate: currency.rate)}
      if currency.rate_changed?
        site_schedules.each do |schedule|
          p "$$$$$ #{schedule.site.site_id}, #{schedule.site.transactions.count}"
          Transaction.where(site: schedule.site, paid: false).each do |transaction|
            transaction.update_attributes(usd_rate: rate)
          end          
        end

        Invoice.where("currency_id = #{self.id} AND status != #{Invoice::STATUS[:paid_offline]} AND status != #{Invoice::STATUS[:successful]}").each {|invoice| invoice.update_attributes(usd_rate: rate)}
      end
    end
  end

  # Private: Get token from CurrencyCloud API
  def self.currency_cloud_token
    response = RestClient::Request.execute(url: "#{API_BASE_URL}/authenticate/api?login_id=#{API_USER}&api_key=#{API_KEY}", method: :post, verify_ssl: false) 
    return nil if response.code != 200
    response = JSON.parse(response)
    return response["auth_token"]    
  end
end