Swapidy::Application.routes.draw do
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  devise_for :users, :controllers => {:sessions => "sessions", 
                                      :registrations => "registrations", 
                                      :omniauth_callbacks => "users/omniauth_callbacks"} do
    match "/users/sign_out" => "sessions#destroy"
  end

  #match 'auth/:provider/callback', to: 'users/omniauth_callbacks#create'

  match "/about" => "home#static_page", :method => :get, :content => "about"
  match "/faq_general" => "home#static_page", :method => :get, :content => "faq_general"
  match "/faq_buying" => "home#static_page", :method => :get, :content => "faq_buying"
  match "/faq_selling" => "home#static_page", :method => :get, :content => "faq_selling"
  match "/team" => "home#static_page", :method => :get, :content => "team"
  match "/how_it_works" => "home#static_page", :method => :get, :content => "how_it_works"
  match "/jobs" => "home#static_page", :method => :get, :content => "jobs"
  match "/team" => "home#static_page", :method => :get, :content => "team"

  resources :posts do
    root to: 'post#index'
  end
  
  resources :products
  
  match "/payments/confirm" => "payments#confirm", :method => :post
  resources :payments do 
    post :create, :on => :member
    post :show, :on => :member
  end
  
  match "/orders/email_info" => "orders#email_info", :method => :post
  match "/orders/payment_info" => "orders#payment_info", :method => :post
  match "/orders/shipping_info" => "orders#shipping_info", :method => :post
  match "/orders/confirm" => "orders#confirm", :method => :post
  match "/orders/create" => "orders#create", :method => :post
  match "/orders/complete" => "orders#complete", :method => :get
  match "/orders/buy/:product_id" => "orders#new", :method => :post, :order_type => Order::TYPES[:order]
  match "/orders/sell/:product_id" => "orders#new", :method => :post, :order_type => Order::TYPES[:trade_ins]
  resources :orders
  
  match "/transactions" => "home#transactions", :method => :get
  get "home/index"
  
  
  match "/notifications/refresh" => "notifications#refresh", :method => :put
  match "/notifications/:id/hide" => "notifications#hide", :method => :put
  resources :notifications

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => 'home#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
