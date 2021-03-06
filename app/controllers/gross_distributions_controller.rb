class GrossDistributionsController < ApplicationController
  before_action :authenticate_user! unless Rails.env.development?
  before_action :check_master_admin
  
  def show
    @investment = Investment.find(params[:id])
    @gross_distributions = @investment.gross_distributions
    @property = @investment.deal.property
    @investor = @investment.investor_name
    @gross_distribution = GrossDistribution.new()
  end

  def create
    gd = GrossDistribution.create(gross_distribution_params)
    if !gd.save
      flash[:alert] = 'Something went wrong. Please try again.'
    end
    
    UpdatePropertyJob.perform_now if !Rails.env.development?

    redirect_back(fallback_location: root_path)
  end

  def update
    gd = GrossDistribution.find(params['id'])
    gd.update(gross_distribution_params)
    
    UpdatePropertyJob.perform_now if !Rails.env.development?

    redirect_back(fallback_location: root_path)
  end

  def destroy
    GrossDistribution.find(params['id']).destroy
    
    UpdatePropertyJob.perform_now if !Rails.env.development?
    
    redirect_back(fallback_location: root_path)
  end

  def import_headers
    @import_file = params[:file].path
    GrossDistribution.create_temp_xlsx(@import_file)
    @property_id = params[:id]
    @gross_distribution = GrossDistribution.new
    @headers = GrossDistribution.pull_headers(@import_file)
    @import_fields = ['investor_email', 'investor_entity', 'amount', 'distribution_date']
    
    render 'properties/import_distribution_headers'
  rescue => e  
    puts "ERROR:: #{e}"
    flash[:alert] = "Invalid file format, please modify or import a different file."
    redirect_to property_path(params[:id]) 
  end

  def import
    mapping = {"investor_email" => params[:post][:investor_email], "investor_entity"=> params[:post][:investor_entity], "amount"=>params[:post][:amount], "distribution_date"=>params[:post][:distribution_date]}
    
    import_data = GrossDistribution.create_import_hash(params[:import_file], mapping)
    
    ImportDistributionsJob.perform_later(params[:property_id], import_data)
    UpdateInvestmentsJob.perform_now
    # ImportDistributionsJob.perform(params[:property_id], import_data)
    
    flash[:notice] = 'Distributions are being imported. An email will be sent once it is complete.'

    redirect_to property_path(params[:property_id])
  end

  def delete_latest_distribution_import
    GrossDistribution.delete_latest_import(params[:id])
    flash[:notice] = 'The latest Distribution import has been deleted.'
    redirect_to property_path(params[:id])
  rescue => e  
    puts "Latest distribution delete failed: #{e}"
    flash[:error] = 'Something went wrong, please try again shortly.'
    redirect_to property_path(params[:id])
  end

  private
  
  def gross_distribution_params
    params.require(:gross_distribution).permit(:investment_id, :amount, :distribution_date, :description)
  end
end