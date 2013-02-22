require 'stamps_shipping_gateway'

class Order < ActiveRecord::Base
  include StampsShippingGateway
  include CardInfo
  
  attr_accessible :status, :user_id, :balance_amount,
                  :shipping_first_name, :shipping_last_name, :shipping_address, :shipping_optional_address,
                  :shipping_city, :shipping_state, :shipping_zip_code, :shipping_country, :shipping_method,
                  :candidate_addresses, :shipping_zip_code_add_on, :is_candidate_address, :token_key, :email

  validates :shipping_first_name, :shipping_last_name, :shipping_address, :shipping_city, :shipping_state, 
            :shipping_zip_code, :shipping_country, :presence => true

  attr_accessor :candidate_addresses, :is_candidate_address, :token_key, :email

  belongs_to :user
  
  has_many :order_products
  has_many :products, :through => :order_products

  has_many :shipping_stamps, :order => "created_at desc"
  has_many :notifications, :as => :notify_object, :class_name => "Notification"
  
  before_save  :calc_balance_amount
  after_create :create_notification
  #after_create :adjust_current_balance

  STATUES = {:pending => 0, :completed => 1, :declined => 2, :cancelled => 3, :confirmed_to_ship => 4}
  SHIPPING_METHODS = {:box => "box", :usps => "usps", :fedex => "fedex"}

  SHIPPING_METHOD_NAMES = { :box => "A box and prepaid label", 
                            :usps => "Prepaid USPS Shipping Label", 
                            :fedex => "Prepaid FedEx Shipping Label"}


  scope :not_completed, :conditions => ["status != ?", STATUES[:completed]]
  
  
  def status_title
    return "Completed" if self.status && self.status == STATUES[:completed]
    return "Declined" if self.status && self.status == STATUES[:declined] 
    return "Cancelled" if self.status && self.status == STATUES[:cancelled] 
    return "Confirmed, wait to ship" if self.status && self.status == STATUES[:confirmed_to_ship] 
    return "Pending, waiting for arrival"
  end
  
  def shipping_method_name
    return "" if self.shipping_method.nil || self.shipping_method.blank?
    SHIPPING_METHOD_NAMES[self.shipping_method.to_sym]
  end
  
  def shipping_address_valid?
    
    #for testing only
    if Rails.env == 'production'
      result = verify_shipping_address
    else
    #  result = true
      result = self.is_candidate_address && self.is_candidate_address.to_s == "true"
      self.candidate_addresses = [{:address1 => "2310 ROCK ST APT (Range 52 - 55)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                {:address1 => "2310 ROCK ST APT (Range 56 - 59)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                {:address1 => "2310 ROCK ST APT (Range 60 - 65)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                {:address1 => "2310 ROCK ST APT (Range 66 - 69)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                #{:address1 => "2310 ROCK ST APT (Range 70 - 75)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                #{:address1 => "2310 ROCK ST APT (Range 76 - 79)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                #{:address1 => "2310 ROCK ST APT (Range 80 - 85)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                #{:address1 => "2310 ROCK ST APT (Range 86 - 89)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                #{:address1 => "2310 ROCK ST APT (Range 90 - 95)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                #{:address1 => "2310 ROCK ST APT (Range 46 - 49)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                {:address1 => "2310 ROCK ST APT (Range 40 - 45)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                {:address1 => "2310 ROCK ST APT (Range 36 - 39)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"},
                                {:address1 => "2310 ROCK ST APT (Range 30 - 35)", :address2 => "", :city => "MOUNTAIN VIEW", :state => "CA", :zip_code => "94043"}] unless result
    end
    #return true if is_candidate_address && !result && candidate_addresses && !candidate_addresses.empty? 
    if !result && self.candidate_addresses && !self.candidate_addresses.empty? 
      errors.add(:shipping_address, "is not confirmed with the shipping service accurately. Please confirm before continuing.") 
    elsif !result
      errors.add(:shipping_address, "could not be found") 
    end
    return result
  end
  
  def create_new_stamps
    #if self.order_products.for_buy.count > 0
    #  weight_total = 0
    #  self.order_products.for_buy.each { |order_product| weight_total += order_product.weight_lb }
    #  stamp = create_stamp(weight_total, :for_buy)
    #  ShippingStamp.create_from_stamp_api(self, stamp.merge(:sell_or_buy => "buy"))
    #end
    
    if self.order_products.for_sell.count > 0
      weight_total = 0
      self.order_products.for_sell.each { |order_product| weight_total += order_product.weight_lb }
      #for testing only
      if Rails.env == 'production'
        stamp = create_stamp(weight_total, :for_sell)
      else
        stamp = create_test_stamp
      end 
      return ShippingStamp.create_from_stamp_api(self, stamp.merge(:sell_or_buy => "sell"))
    end
  end
  
  def shipping_fullname
    [shipping_first_name, shipping_last_name].join(" ")
  end

  def shipping_full_address
    html = shipping_address 
    html += "(Optional: #{shipping_optional_address})" if shipping_optional_address && !shipping_optional_address.blank?
    html += "#{shipping_city}, #{shipping_state}, #{shipping_zip_code}"
    return html
  end
  
  def create_notification
    notification = self.notifications.new(:user_id => self.user.id)
    notification.title = "Order Processing"
    notification.description = "Order processing: #{balance_amount_label}" 
    notification.save
  end
  
  def create_notification_to_decline
    notification = self.notifications.new(:user_id => self.user.id)
    notification.title = "Order Declined"
    notification.description = "Order - #{id} - Declined" 
    notification.save
    
    OrderNotifier.product_declined(self).deliver
  end
  
  def create_notification_to_reminder
    new_stamp = self.create_new_stamps
    notification = self.notifications.new(:user_id => self.user.id)
    notification.title = "Order Reminder"
    notification.description = "Order - #{id} - Reminder" 
    notification.save

    OrderNotifier.reminder(self, new_stamp).deliver
  end
    
  def create_notification_to_cancel
    notification = self.notifications.new(:user_id => self.user.id)
    notification.title = "Order Canceled"
    notification.description = "Order - #{id} - Canceled" 
    notification.save
    
    OrderNotifier.order_cancel(self).deliver
  end
  
  
  def create_notification_to_complete
    notification = self.notifications.new(:user_id => self.user.id)
    notification.title = "Order Completed"
    notification.description = "Order - #{id} - Completed." 
    notification.save
    
    OrderNotifier.trade_ins_complete(self).deliver
  end
  
  def generate_product_title
    return if self.product_title && !self.product_title.blank?
    if self.product && !self.product.title.blank?
      self.product_title = self.product.title 
    elsif self.product && self.product.product_model
      self.product_title = "#{self.product.category.title} #{self.product.product_model.title}"
    end
  end
  
  def shipping_address_blank?
    return (self.shipping_first_name || "").blank? && (self.shipping_last_name || "").blank? && 
           (self.shipping_address || "").blank? && (self.shipping_optional_address || "").blank? &&
           (self.shipping_city || "").blank? && (self.shipping_state || "").blank? &&
           (self.shipping_zip_code || "").blank?
  end
  
  def enter_from_last_address
    last_one = self.user.last_order
    if last_one
      self.shipping_first_name = last_one.shipping_first_name
      self.shipping_last_name = last_one.shipping_last_name
      self.shipping_address = last_one.shipping_address
      self.shipping_optional_address = last_one.shipping_optional_address
      self.shipping_city = last_one.shipping_city
      self.shipping_state = last_one.shipping_state
      self.shipping_zip_code = last_one.shipping_zip_code
      return true
    else
      self.shipping_state = "CA"
      return false
    end
  end
  
  def calc_balance_amount
    amount = 0.0
    self.order_products.for_sell.each {|order_product| amount += order_product.price }
    self.order_products.for_buy.each {|order_product| amount -= order_product.price }
    self.balance_amount = amount
    return amount
  end
    
  def generate_token_key
    self.token_key = Digest::MD5.hexdigest "#{SecureRandom.hex(20)}-order-#{DateTime.now.to_s}"
    return self.token_key
  end
  
  def adjust_current_balance(new_balance_amount = nil)
    if new_balance_amount
      self.user.update_attribute :balance_amount, new_balance_amount
    else
      self.user.update_attribute :balance_amount, ((self.user.balance_amount || 0) + self.balance_amount)
    end
  end


  private
  
    def balance_amount_label
      if calc_balance_amount > 0 
        return "You get: $#{calc_balance_amount}" 
      else
        return "You pay: $#{-(calc_balance_amount)}"
      end
    end
  
    def create_test_stamp
      { :integrator_tx_id => self.id,
        :tracking_number => "9405511201080126838437",
        :rate => {:service_type => "US-PM",
                  :amount => 6.2,
                  :package_type => "Package",
                  :ship_date => "2013-01-06"},
        :stamps_tx_id => "382c3dfb-5248-4755-9313-63cedfb6aed6",
        :url => "#{File.expand_path(Rails.root)}/public/images/label_example.png"
      }
    end
end
