# ================================================
# RUBY->CONTROLLER->INVESTMENTSCONTROLLER ========
# ================================================
class InvestmentsController < ApplicationController
  before_action :authenticate_user! unless Rails.env.development?

  # ----------------------------------------------
  # SHOW -----------------------------------------
  # ----------------------------------------------
  def index 
    @investments = Investment.all
  end

  def show
    @investment = Investment.find_by(id: params[:id])
    @property_investments = Property.find(@investment&.deal&.property&.id).investments.where(user_id: current_user.id)
    if @investment && current_user && @investment.investor == current_user || current_user.admin?
      render 'show'
    else
      flash[:alert] = 'Not authorized'
      redirect_to main_app.root_path
    end
  rescue => e  
    flash[:alert] = 'Sorry, that investment is not available.'
    redirect_to main_app.root_path
  end

  def import_headers
    @investment_file = params[:file].path
    Investment.create_temp_csv(@investment_file)
    @property_id = params[:id]
    @investment = Investment.new
    @headers = CSV.read(@investment_file, headers: true).headers << ['No Mapping', nil]
    @investment_fields = ['investor_first_name', 'investor_last_name', 'investor_email', 'investing_entity', 'investor_entity', 'amount_invested', 'gross_distribution']
    
    render 'properties/import_headers'
  rescue => e  
    puts "ERROR:: #{e}"
    flash[:alert] = "Invalid file format, please modify or import a different file."
    redirect_to property_path(params[:id]) 
  end

  def import
    begin
      Investment.import(params[:property_id], params[:investment_file], params[:post])
      property_id = params[:property_id]
      file = "lib/imports/#{params[:investment_file].split("/")[-1]}"
      mapping = params[:post]
      CSV.foreach(file, headers: true) do |row|
        deal = Deal.find_or_create_by(title: row[mapping["investing_entity"]], property_id: property_id)
  
        investor_hash = {
          deal_id: deal.id,
          investor_last_name: row[mapping["investor_last_name"]]&.strip,
          investor_first_name: row[mapping["investor_first_name"]]&.strip,
          investor_email: row[mapping["investor_email"]]&.strip,
          investing_entity: row[mapping["investing_entity"]]&.strip,
          investor_entity: row[mapping["investor_entity"]]&.strip,
          gross_distribution: row[mapping["gross_distribution"]]&.strip,
          amount_invested: row[mapping["amount_invested"]]&.strip&.to_i,
          user_id: Investment.get_user_id(row, mapping)
        }
        Investment.create! investor_hash
      end
      byebug
      File.delete(file) if File.exist?(file)

      flash[:notice] = 'Investments have been successfully imported.'
      redirect_to property_path(params[:property_id])
    rescue => e  
      puts "ERROR:: #{e}"
      flash[:alert] = "Invalid file format."
      redirect_to property_path(params[:property_id])
    end
  end

end
