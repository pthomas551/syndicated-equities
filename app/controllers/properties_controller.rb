class PropertiesController < ApplicationController
  before_action :authenticate_user! unless Rails.env.development?

  # ----------------------------------------------
  # INDEX ----------------------------------------
  # ----------------------------------------------

  def index
    @properties = Property.all
    @property = Property.new
    
    if params[:search] && !params[:search].blank?
      @properties = Property.search(params[:search]).order("created_at DESC")
    end
    
    if params[:status] && !params[:status].blank?
      @properties = Property.filter(params[:status]).order("created_at DESC")
    end

    if @properties && current_user
      render 'index'
    else
      flash[:alert] = 'Not authorized'
      redirect_to main_app.root_path
    end
  end

  def show
    @property = Property.find(params[:id])
    if @property && current_user
      render 'show'
    else
      flash[:alert] = 'Not authorized'
      redirect_to main_app.root_path
    end
  end

  def create
    # create property
    property = Property.new(property_params)
    property.status = "active"
    property.save
    if property

      # create address
      address = Address.new(address_params)
      address.addressable_id = property.id
      address.addressable_type = "Property"
      address.save
    else
      flash[:alert] = 'Something went wrong. Please try and add the property again. (rememeber the image needs to be above 600 x 600)'
    end

    redirect_to properties_path
  end

  def update
    @property = Property.find(params[:id])

    @property.update(property_params)
    
    @property.address.update(address_params)

    render 'show'
  end

  private

  def property_params
    params.require(:property).permit(:name, :closing_date, :nickname, :status, :avatar)
  end

  def address_params
    params.require(:property).permit(:line1, :city, :state, :zip, :country)
  end
end