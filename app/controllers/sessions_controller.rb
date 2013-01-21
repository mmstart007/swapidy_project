class SessionsController < Devise::SessionsController
  
  def create
    if(params[:login_to_order].nil? || params[:login_to_order].blank?)
      Rails.logger.info "Test 1"
      self.resource = User.find_by_email params[:user][:email]
      if self.resource && self.resource.valid_password?(params[:user][:password])
        Rails.logger.info "Test 2"
        set_flash_message(:notice, :signed_in) if is_navigational_format?
        sign_in resource, :event => :authentication
        #respond_with resource, :location => after_sign_in_path_for(resource)
        check_to_display_guide 
      else
        self.resource = User.new(:email => params[:user][:email]) unless self.resource
        @return_content = render_to_string(:partial => "/devise/shared/signin_form", :locals => {:show_cancel_link => true})
      end
    else
      self.resource = User.find_by_email params[:user][:email]
      if self.resource && self.resource.valid_password?(params[:user][:password])
        set_flash_message(:notice, :signed_in) if is_navigational_format?
        sign_in(resource_name, resource)
      end

      if user_signed_in?
        check_to_display_guide
        redirect_to :controller => :orders, :action => :new, :method => :post, :product_id => params[:product_id], :using_condition => params[:using_condition], :order_type => params[:order_type]
      else
        @signin_failure = true
        @order = Order.new(:order_type => params[:order_type], :using_condition => params[:using_condition])
        @product = Product.find params[:product_id]
        render "/orders/email_info_form"
      end
    end
  end

end