class ProductAttribute < ActiveRecord::Base
  
  attr_accessible :value
  
  belongs_to :product
  belongs_to :product_model_attribute
  
  
  def attribute_value
    if value && !value.blank?
      return CategoryAttribute.convert_value(self.product_model_attribute.category_attribute.attribyte_type, self.value)
    else
      return self.product_model_attribute.attribute_value
    end
  end
  
  after_save :expired_fragment_caches
  after_destroy :expired_fragment_caches
  
  private
    
    def expired_fragment_caches
      ActionController::Base.new.expire_fragment("homepage_product_thumb_#{product.id}")
      ActionController::Base.new.expire_fragment("homepage_container_category_#{category.id}")
    end
  
end
